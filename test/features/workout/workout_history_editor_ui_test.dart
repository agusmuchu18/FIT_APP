import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/features/workout/application/workout_history_mutation_service.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/presentation/workout_history_editor_screen.dart';
import 'package:fit_app/features/workout/presentation/workout_history_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/domain/sport_activity.dart';

import 'training_test_fixtures.dart';

class _Projection implements FitnessRepository {
  final entries = <String, WorkoutEntry>{};
  @override
  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    entries[entry.id] = entry;
  }

  @override
  Future<List<WorkoutEntry>> getWorkoutProjections() async =>
      entries.values.toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'historical edit rejects invalid raw input then persists correction and projection',
    (tester) async {
      final repository = WorkoutRepository(),
          projection = _Projection(),
          original = trainingFixtureSessions().first;
      await repository.persistLegacySession(original);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => WorkoutHistoryEditorScreen(
                      session: original,
                      repository: repository,
                      fitness: projection,
                      initialRevision: 0,
                    ),
                  ),
                ),
                child: const Text('Editar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Press banca'));
      await tester.tap(find.text('Press banca'));
      await tester.pumpAndSettle();
      final load = find
          .widgetWithText(TextFormField, 'Carga externa (kg)')
          .first;
      await tester.ensureVisible(load);
      await tester.enterText(load, 'NaN');
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Guardar corrección',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        (await repository.listAllSessions())
            .single
            .exercises
            .single
            .sets
            .first
            .externalLoadKg,
        original.exercises.single.sets.first.externalLoadKg,
      );
      await tester.enterText(load, '42');
      await tester.pump();
      await tester.tap(find.byTooltip('Guardar corrección'));
      await tester.pumpAndSettle();
      expect(find.text('Editar'), findsOneWidget);
      expect(
        (await repository.listAllSessions())
            .single
            .exercises
            .single
            .sets
            .first
            .externalLoadKg,
        42,
      );
      expect(projection.entries.keys, [original.id]);
      expect(
        (await repository.historyChanges()).values.single.projectionPending,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'sport correction keeps goals separate and updates actual duration and distance',
    (tester) async {
      final repository = WorkoutRepository(), projection = _Projection();
      final activity = footballActivities.firstWhere(
        (a) => a.mode == FootballMode.physical,
      );
      final original = WorkoutSession(
        id: 'sport-ui',
        type: WorkoutType.sport,
        date: DateTime(2026, 10, 1),
        exercises: [
          WorkoutExercise(
            id: activity.id,
            name: activity.name,
            measurement: 'time',
            sportPlan: SportActivityPlan(
              activityId: activity.id,
              mode: activity.mode,
              targets: SportMeasurements(
                values: {SportMetric.distanceMeters: 500},
              ),
            ),
            sportResult: SportMeasurements(
              values: {
                SportMetric.durationSeconds: 60,
                SportMetric.distanceMeters: 100,
                SportMetric.repetitions: 2,
              },
            ),
            sets: [SetEntry(id: 'block', done: true, durationSeconds: 60)],
          ),
        ],
      );
      await repository.persistLegacySession(original);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutHistoryEditorScreen(
            session: original,
            repository: repository,
            fitness: projection,
            initialRevision: 0,
          ),
        ),
      );
      await tester.ensureVisible(find.text(activity.name));
      await tester.tap(find.text(activity.name));
      await tester.pumpAndSettle();
      final distance = find.widgetWithText(TextFormField, 'Distancia (m)');
      await tester.ensureVisible(distance);
      await tester.enterText(distance, '200');
      final duration = find.widgetWithText(
        TextFormField,
        'Duración del bloque (s)',
      );
      await tester.ensureVisible(duration);
      await tester.enterText(duration, '120');
      await tester.pump();
      await tester.tap(find.byTooltip('Guardar corrección'));
      await tester.pumpAndSettle();
      final saved =
          (await repository.listAllSessions()).single.exercises.single;
      expect(saved.sportPlan!.targets.values[SportMetric.distanceMeters], 500);
      expect(saved.sportResult!.values[SportMetric.distanceMeters], 200);
      expect(saved.sets.single.durationSeconds, 120);
      expect(saved.sets.single.done, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'a deleted session cannot reappear through a passed detail snapshot',
    (tester) async {
      final repository = WorkoutRepository(),
          original = trainingFixtureSessions().first;
      await repository.persistLegacySession(original);
      await WorkoutHistoryMutationService(
        repository,
        _Projection(),
      ).delete(original.id, expectedRevision: 0);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutHistoryDetailScreen(
            session: original,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('no está disponible'), findsOneWidget);
      expect(find.text('Press banca'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
