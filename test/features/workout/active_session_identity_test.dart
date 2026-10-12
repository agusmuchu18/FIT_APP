import 'dart:convert';

import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/start_routine_flow.dart';
import 'package:fit_app/features/workout/training_home/training_home_controller.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const draftExercise = ExerciseInSession(
  id: 'instance-a',
  exerciseId: 'bench_press',
  name: 'Press banca',
  sets: [SetInSession(id: 'set-a', index: 1)],
);

void main() {
  test(
    'opening a draft retains its own routine and session identity',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = WorkoutRepository();
      await repository.persistDraftWithStartTime(
        [draftExercise],
        startTime: DateTime(2026, 9, 28),
        workoutId: 'session-a',
        routineId: 'routine-a',
        routineName: 'Rutina A',
      );

      final controller = WorkoutSessionController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize(templateId: 'routine-b');

      final identity = await repository.loadDraftIdentity();
      expect(identity?.sessionId, 'session-a');
      expect(identity?.routineId, 'routine-a');
      expect(identity?.routineName, 'Rutina A');
      expect(controller.exercises.single.id, 'instance-a');
      expect(controller.sessionStart, DateTime(2026, 9, 28));
    },
  );

  test('an empty active draft is not replaced by a selected routine', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = WorkoutRepository();
    await repository.persistDraftWithStartTime(
      [],
      startTime: DateTime(2026, 9, 28),
      workoutId: 'empty-session',
      routineId: 'routine-a',
      routineName: 'Rutina A',
    );

    final controller = WorkoutSessionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize(templateId: 'routine-b');

    expect(controller.exercises, isEmpty);
    final identity = await repository.loadDraftIdentity();
    expect(identity?.sessionId, 'empty-session');
    expect(identity?.routineId, 'routine-a');
  });

  for (final choice in ['Cancelar', 'Continuar', 'Reemplazar']) {
    testWidgets('$choice resolves a conflicting active session', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repository = WorkoutRepository();
      await repository.persistDraftWithStartTime(
        [draftExercise],
        startTime: DateTime(2026, 9, 28),
        workoutId: 'session-a',
        routineId: 'routine-a',
        routineName: 'Rutina A',
      );
      final controller = TrainingHomeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      final routineB = WorkoutTemplate(
        id: 'routine-b',
        name: 'Rutina B',
        type: WorkoutType.strength,
        origin: TemplateOrigin.user,
        exercises: const [],
      );
      Object? routeArguments;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    startRoutineFlow(context, controller, routineB),
                child: const Text('Iniciar B'),
              ),
            ),
          ),
          onGenerateRoute: (settings) {
            if (settings.name != '/workout/session') return null;
            routeArguments = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Sesión abierta')),
            );
          },
        ),
      );

      await tester.tap(find.text('Iniciar B'));
      await tester.tap(find.text('Iniciar B'));
      await tester.pumpAndSettle();
      expect(find.text('Ya hay un entrenamiento en curso'), findsOneWidget);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();

      if (choice == 'Cancelar') {
        expect(find.text('Sesión abierta'), findsNothing);
        expect((await repository.loadDraftIdentity())?.routineId, 'routine-a');
      } else if (choice == 'Continuar') {
        expect(find.text('Sesión abierta'), findsOneWidget);
        expect(routeArguments, isNull);
        expect((await repository.loadDraftIdentity())?.routineId, 'routine-a');
      } else {
        expect(find.text('Sesión abierta'), findsOneWidget);
        expect(routeArguments, {'templateId': 'routine-b'});
        expect(await repository.loadDraftExercises(), isNull);
      }
    });
  }

  for (final choice in ['Cancelar', 'Continuar', 'Reemplazar']) {
    testWidgets('$choice protects a legacy pro draft', (tester) async {
      final legacyRaw = jsonEncode({
        'sessionStart': DateTime(2026, 9, 28).toIso8601String(),
        'lastUpdated': DateTime(2026, 9, 28).toIso8601String(),
        'type': 'strength',
        'templateId': 'legacy-routine',
        'exercises': [
          {
            'id': 'bench_press',
            'name': 'Press banca',
            'sets': [
              {'id': 'set-legacy', 'reps': 8, 'externalLoadKg': 45},
            ],
          },
        ],
      });
      SharedPreferences.setMockInitialValues({
        WorkoutInProgressController.draftKey: legacyRaw,
      });
      final controller = TrainingHomeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      final routineB = WorkoutTemplate(
        id: 'routine-b',
        name: 'Rutina B',
        type: WorkoutType.strength,
        origin: TemplateOrigin.user,
        exercises: const [],
      );
      Object? routeArguments;
      bool? legacyAtNavigation;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    startRoutineFlow(context, controller, routineB),
                child: const Text('Iniciar B'),
              ),
            ),
          ),
          onGenerateRoute: (settings) {
            if (settings.name != '/workout/session') return null;
            routeArguments = settings.arguments;
            legacyAtNavigation =
                WorkoutInProgressController.instance.isLegacyDraftActive;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Sesión abierta')),
            );
          },
        ),
      );

      await tester.tap(find.text('Iniciar B'));
      await tester.pumpAndSettle();
      expect(find.text('Ya hay un entrenamiento en curso'), findsOneWidget);
      await tester.tap(find.text(choice));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      if (choice == 'Cancelar') {
        expect(find.text('Sesión abierta'), findsNothing);
        expect(
          prefs.getString(WorkoutInProgressController.draftKey),
          legacyRaw,
        );
      } else if (choice == 'Continuar') {
        expect(find.text('Sesión abierta'), findsOneWidget);
        expect(routeArguments, isNull);
        expect(legacyAtNavigation, isTrue);
        expect(
          prefs.getString(WorkoutInProgressController.draftKey),
          legacyRaw,
        );
        expect(await WorkoutRepository().loadDraftExercises(), isNull);
      } else {
        expect(find.text('Sesión abierta'), findsOneWidget);
        expect(routeArguments, {'templateId': 'routine-b'});
        expect(legacyAtNavigation, isFalse);
        expect(prefs.getString(WorkoutInProgressController.draftKey), isNull);
      }
    });
  }
}
