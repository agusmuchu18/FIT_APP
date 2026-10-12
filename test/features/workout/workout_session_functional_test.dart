import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/presentation/workout_in_progress_screen.dart';
import 'package:fit_app/features/workout/presentation/widgets/set_row.dart';
import 'package:fit_app/features/workout/presentation/widgets/workout_in_progress_header.dart';
import 'package:fit_app/features/workout/presentation/widgets/radar_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'back saves edits and reopening can finish with a visible summary',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = WorkoutRepository();
      await repository.persistDraftWithStartTime(
        const [
          ExerciseInSession(
            id: 'ex',
            exerciseId: 'bench_press',
            name: 'Press de banca',
            sets: [SetInSession(id: 'one', index: 1, reps: 8)],
          ),
        ],
        startTime: DateTime.now(),
        workoutId: 'flow',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WorkoutInProgressScreen(),
                  ),
                ),
                child: const Text('Abrir sesión'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Press de banca'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextField, 'Reps'));
      await tester.enterText(find.widgetWithText(TextField, 'Reps'), '9');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Abrir sesión'), findsOneWidget);
      expect(
        (await repository.loadDraftExercises())!.single.sets.single.reps,
        9,
      );
      await tester.tap(find.text('Abrir sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Press de banca'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Terminar'), findsNothing);
      await tester.tap(find.text('Finalizar entrenamiento'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar entrenamiento'), findsOneWidget);
      expect(await repository.listSessions(), isEmpty);
      await tester.tap(find.text('Guardar entrenamiento'));
      await tester.pumpAndSettle();
      expect(find.text('Entrenamiento completado'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Volver al inicio'), 400);
      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Abrir sesión'), findsOneWidget);
      expect(await repository.loadDraftExercises(), isNull);
      expect(await repository.listSessions(), hasLength(1));
    },
  );

  testWidgets('real settings apply to exercises added after returning', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const WorkoutInProgressScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más opciones'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Próximamente'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar ejercicio'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar ejercicio'),
      'plank',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Plancha'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));
    final exercise = (await WorkoutRepository().loadDraftExercises())!.single;
    expect(exercise.isTimed, isTrue);
    expect(exercise.restEnabled, isTrue);
    expect(exercise.restSeconds, 90);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'timed routine targets and workout type survive reopening and completion',
    () async {
      final routine = await RoutinesRepository().saveRoutine(
        name: 'Core',
        workoutType: WorkoutType.functional,
        exercises: [
          WorkoutExercise(
            id: 'plank',
            name: 'Plancha',
            measurement: 'time',
            targetDurationSeconds: 60,
            targetSets: 2,
          ),
        ],
      );
      final controller = WorkoutSessionController();
      await controller.initialize(templateId: routine.id);
      final exercise = controller.exercises.single;
      expect(exercise.sets.first.durationSeconds, 60);
      expect(exercise.sets.first.reps, isNull);
      controller.updateSet(exercise.id, exercise.sets.first.id, done: true);
      await controller.saveDraft();
      controller.dispose();
      final reopened = WorkoutSessionController();
      await reopened.initialize();
      await reopened.finishWorkout();
      reopened.dispose();
      expect(
        (await WorkoutRepository().listSessions()).single.type,
        WorkoutType.functional,
      );
    },
  );
  test(
    'timed exercises complete, reopen and retain duration in history',
    () async {
      final repository = WorkoutRepository();
      final controller = WorkoutSessionController(repository: repository);
      await controller.initialize();
      await controller.addExercise(exerciseId: 'plank', name: 'Plancha');
      final exercise = controller.exercises.single;
      expect(exercise.isTimed, isTrue);
      controller.updateSet(exercise.id, exercise.sets.single.id, done: true);
      expect(controller.exercises.single.sets.single.done, isFalse);
      controller.updateSet(
        exercise.id,
        exercise.sets.single.id,
        durationSeconds: 45,
      );
      controller.updateSet(exercise.id, exercise.sets.single.id, done: true);
      await controller.saveDraft();
      controller.dispose();
      final restored = WorkoutSessionController(repository: repository);
      await restored.initialize();
      expect(restored.exercises.single.sets.single.durationSeconds, 45);
      expect(await restored.finishWorkout(), isTrue);
      final saved = (await repository.listSessions()).single.exercises.single;
      expect(saved.isTimed, isTrue);
      expect(saved.sets.single.durationSeconds, 45);
      restored.dispose();
    },
  );

  test(
    'invalid completed values are rejected at the controller boundary',
    () async {
      final controller = WorkoutSessionController();
      await controller.initialize();
      await controller.addExercise(exerciseId: 'bench_press', name: 'Press');
      final exercise = controller.exercises.single;
      expect(
        () => controller.updateSet(
          exercise.id,
          exercise.sets.single.id,
          reps: 8,
          kg: -10,
          done: true,
        ),
        throwsArgumentError,
      );
      expect(controller.exercises.single.sets.single.done, isFalse);
      await controller.saveDraft();
      controller.dispose();
    },
  );

  test('assistance is retained without inflating external volume', () async {
    final controller = WorkoutSessionController();
    await controller.initialize();
    await controller.addExercise(
      exerciseId: 'assisted_pull_up',
      name: 'Dominadas asistidas',
    );
    final exercise = controller.exercises.single;
    controller.updateSet(
      exercise.id,
      exercise.sets.single.id,
      reps: 8,
      kg: 30,
      done: true,
    );
    expect(controller.exercises.single.sets.single.kg, isNull);
    expect(controller.exercises.single.sets.single.assistanceKg, 30);
    expect(controller.totalVolume, 0);
    await controller.finishWorkout();
    final saved = (await WorkoutRepository().listSessions())
        .single
        .exercises
        .single
        .sets
        .single;
    expect(saved.assistanceKg, 30);
    expect(saved.externalLoadKg, isNull);
    controller.dispose();
  });

  testWidgets('clock ticks do not rebuild the radar chart', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutInProgressHeader(
            startTime: DateTime.now(),
            totalVolume: 400,
            currentDistribution: const {'Pecho': 1},
            completedSets: 1,
            totalSets: 3,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is RadarChartPainter,
    );
    final painter = tester.widget<CustomPaint>(chart).painter;
    await tester.pump(const Duration(seconds: 3));
    expect(
      identical(tester.widget<CustomPaint>(chart).painter, painter),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'deleting a set renumbers remaining sets and cancels its rest',
    () async {
      final controller = WorkoutSessionController();
      await controller.initialize(
        initialExercises: const [
          ExerciseInSession(
            id: 'ex',
            exerciseId: 'bench_press',
            name: 'Press',
            restEnabled: true,
            restSeconds: 90,
            sets: [
              SetInSession(id: 'one', index: 1, reps: 8),
              SetInSession(id: 'two', index: 2, reps: 8),
            ],
          ),
        ],
      );
      controller.updateSet('ex', 'one', done: true);
      expect(controller.hasActiveRest, isTrue);
      controller.removeSet('ex', 'one');
      expect(controller.hasActiveRest, isFalse);
      expect(controller.exercises.single.sets.single.index, 1);
      expect(controller.exercises.single.sets.single.id, 'two');
      await controller.saveDraft();
      controller.dispose();
    },
  );

  test(
    'unreadable draft is retained and cannot be overwritten by initialization',
    () async {
      SharedPreferences.setMockInitialValues({
        WorkoutRepository.draftKey: '{broken',
      });
      final controller = WorkoutSessionController();
      await controller.initialize();
      expect(controller.isReady, isFalse);
      expect(controller.initializationError, isNotNull);
      controller.dispose();
      expect(
        (await SharedPreferences.getInstance()).getString(
          WorkoutRepository.draftKey,
        ),
        '{broken',
      );
    },
  );

  testWidgets('timed row uses seconds and fits enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? seconds;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SetRow(
            set: const SetInSession(id: 'one', index: 1),
            isTimed: true,
            onDurationChanged: (value) => seconds = value,
            onChanged: ({kg, clearKg, reps, clearReps, done}) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '60');
    expect(seconds, 60);
    expect(find.text('Kg'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'active session fits 320px and 200 percent text without bottom overlap',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await WorkoutRepository().persistDraftWithStartTime(const [
        ExerciseInSession(
          id: 'ex',
          exerciseId: 'bench_press',
          name: 'Press de banca',
          restEnabled: true,
          restSeconds: 90,
          sets: [SetInSession(id: 'one', index: 1, reps: 8)],
        ),
      ], startTime: DateTime.now());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const WorkoutInProgressScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pausar sesión'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
