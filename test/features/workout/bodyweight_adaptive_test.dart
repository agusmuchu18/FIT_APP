import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/application/legacy_draft_migration.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/application/routine_update_from_session.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'training_test_fixtures.dart';

const body = RoutineExerciseLoadType.bodyweight;
const added = RoutineExerciseLoadType.addedWeightKg;
const assisted = RoutineExerciseLoadType.assistedKg;

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  Future<WorkoutSessionController> fresh(
    String id, {
    WorkoutRepository? repository,
  }) async {
    final c = WorkoutSessionController(
      repository: repository ?? WorkoutRepository(),
    );
    addTearDown(c.dispose);
    await c.initialize();
    await c.addExercise(
      exerciseId: id,
      name: exerciseLibrary.firstWhere((d) => d.id == id).name,
    );
    return c;
  }

  for (final id in ['pull_up', 'push_up', 'dips', 'bodyweight_squat']) {
    test(
      '$id starts as repetitions only, with no external or body-mass field',
      () async {
        final c = await fresh(id);
        final e = c.exercises.single, s = c.exercises.single.sets.single;
        expect(e.isBodyweight, true);
        expect(e.defaultMode, body);
        expect(s.loadType, body);
        expect(s.kg, isNull);
        expect(s.assistanceKg, isNull);
        c.updateSet(e.id, s.id, reps: 12);
        expect(c.completeSet(e.id, s.id), true);
        expect(c.totalVolume, 0);
      },
    );
  }
  test(
    'plank defaults to duration, one-tap completion retains its time',
    () async {
      final c = await fresh('plank');
      final e = c.exercises.single, s = c.exercises.single.sets.single;
      expect(e.isTimed, true);
      expect(e.defaultMode, body);
      c.updateSet(e.id, s.id, durationSeconds: 45);
      expect(c.completeSet(e.id, s.id), true);
      expect(c.exercises.single.sets.single.durationSeconds, 45);
      expect(c.totalVolume, 0);
    },
  );
  test('added load requires its optional value, counts only added kg and triggers rest', () async {
    final c = await fresh('pull_up');
    final e = c.exercises.single, s = e.sets.single;
    c.updateExerciseRest(e.id, enabled: true, seconds: 90);
    c.updateSetLoadType(e.id, s.id, added);
    c.updateSet(e.id, s.id, reps: 8);
    expect(c.completeSet(e.id, s.id), false);
    c.updateSet(e.id, s.id, kg: 10);
    expect(c.completeSet(e.id, s.id), true);
    expect(c.totalVolume, 80);
    expect(c.hasActiveRest, true);
    expect(c.restDurationSeconds, 90);
    c.updateSetLoadType(e.id, s.id, assisted);
    expect(c.exercises.single.sets.single.done, false);
    expect(c.hasActiveRest, false);
    expect(c.exercises.single.sets.single.kg, 10);
  });
  test('assistance is separate and contributes no lifted volume', () async {
    final c = await fresh('pull_up');
    final e = c.exercises.single, s = e.sets.single;
    c.updateSetLoadType(e.id, s.id, assisted);
    c.updateSet(e.id, s.id, kg: 25, reps: 10);
    expect(c.completeSet(e.id, s.id), true);
    final done = c.exercises.single.sets.single;
    expect(done.assistanceKg, 25);
    expect(done.kg, isNull);
    expect(c.totalVolume, 0);
  });
  test(
    'mixed modes persist in draft and saved history, retaining every set ID',
    () async {
      final repository = WorkoutRepository();
      final c = await fresh('pull_up', repository: repository);
      final id = c.exercises.single.id;
      c.updateSet(id, c.exercises.single.sets.first.id, reps: 10);
      c.completeSet(id, c.exercises.single.sets.first.id);
      await c.addSet(id);
      final second = c.exercises.single.sets.last.id;
      c.updateSetLoadType(id, second, added);
      c.updateSet(id, second, kg: 12, reps: 8);
      c.completeSet(id, second);
      await c.addSet(id);
      final third = c.exercises.single.sets.last.id;
      c.updateSetLoadType(id, third, assisted);
      c.updateSet(id, third, kg: 20, reps: 15);
      c.completeSet(id, third);
      final ids = c.exercises.single.sets.map((s) => s.id).toList();
      await c.saveDraft();
      final restored = (await repository.loadDraftExercises())!.single;
      expect(restored.sets.map((s) => s.loadType), [body, added, assisted]);
      expect(restored.sets.map((s) => s.id), ids);
      expect(c.totalVolume, 96);
      expect(await c.finishWorkout(), true);
      final history =
          (await repository.listAllSessions()).single.exercises.single;
      expect(history.sets.map((s) => s.id), ids);
      expect(history.sets.map((s) => s.loadType), [body, added, assisted]);
      expect(
        WorkoutReport((await repository.listAllSessions()).single)
            .externalVolume,
        96,
      );
    },
  );
  test('changing exercise default preserves completed and individually configured sets', () async {
    final c = await fresh('pull_up');
    final id = c.exercises.single.id, first = c.exercises.single.sets.first.id;
    c.updateSet(id, first, reps: 10);
    c.completeSet(id, first);
    final before = c.exercises.single.sets.first.toJson();
    await c.addSet(id);
    final override = c.exercises.single.sets.last.id;
    c.updateSetLoadType(id, override, assisted);
    c.updateSet(id, override, kg: 20);
    await c.addSet(id);
    c.updateLoadType(id, added);
    expect(c.exercises.single.sets.first.toJson(), before);
    expect(c.exercises.single.sets[1].loadType, assisted);
    expect(c.exercises.single.sets[1].assistanceKg, 20);
    expect(c.exercises.single.sets.last.loadType, added);
  });
  test(
    'mode toggles retain separate inactive values without counting them',
    () async {
      final c = await fresh('pull_up');
      final id = c.exercises.single.id,
          setId = c.exercises.single.sets.first.id;
      c.updateSetLoadType(id, setId, added);
      c.updateSet(id, setId, kg: 10, reps: 8);
      c.updateSetLoadType(id, setId, assisted);
      c.updateSet(id, setId, kg: 30);
      c.updateSetLoadType(id, setId, body);
      c.completeSet(id, setId);
      final s = c.exercises.single.sets.first;
      expect(s.kg, 10);
      expect(s.assistanceKg, 30);
      expect(c.totalVolume, 0);
      expect(
        WorkoutReport(
          WorkoutSession(
            id: 's',
            type: WorkoutType.strength,
            date: DateTime(2026, 10, 12),
            exercises: WorkoutAnalytics.fromLive(c.exercises),
          ),
        ).ambiguousLoad,
        false,
      );
      c.updateSetLoadType(id, setId, added);
      expect(c.totalVolume, 80);
      expect(c.exercises.single.sets.first.kg, 10);
      c.updateSetLoadType(id, setId, assisted);
      expect(c.totalVolume, 0);
      expect(c.exercises.single.sets.first.assistanceKg, 30);
    },
  );
  test(
    'adding a set inherits only loads compatible with the chosen default',
    () async {
      final c = await fresh('dips');
      final id = c.exercises.single.id, s = c.exercises.single.sets.first.id;
      c.updateSetLoadType(id, s, added);
      c.updateSet(id, s, kg: 15, reps: 6);
      await c.addSet(id);
      expect(c.exercises.single.sets.last.loadType, body);
      expect(c.exercises.single.sets.last.reps, 6);
      expect(c.exercises.single.sets.last.kg, isNull);
      c.updateLoadType(id, added);
      final last = c.exercises.single.sets.last.id;
      c.updateSet(id, last, kg: 12, reps: 8);
      await c.addSet(id);
      expect(c.exercises.single.sets.last.kg, 12);
      expect(c.exercises.single.sets.last.reps, 8);
      expect(c.exercises.single.sets.last.done, false);
    },
  );
  WorkoutSession weightedHistory() => WorkoutSession(
    id: 'past',
    date: DateTime(2026, 10, 12),
    type: WorkoutType.strength,
    exercises: [
      WorkoutExercise(
        id: 'pull_up',
        name: 'Dominadas',
        targetLoadType: added,
        sets: [
          SetEntry(
            id: 'old-set',
            loadType: added,
            externalLoadKg: 10,
            bodyweightKg: 80,
            reps: 6,
            done: true,
          ),
        ],
      ),
    ],
  );
  test(
    'past added load never activates itself in a new free bodyweight session',
    () async {
      final c = await fresh(
        'pull_up',
        repository: TrainingFixtureRepository([weightedHistory()]),
      );
      final e = c.exercises.single, s = e.sets.single;
      expect(s.previous!.label, contains('Lastre'));
      expect(e.defaultMode, body);
      expect(s.kg, isNull);
      expect(c.completeSet(e.id, s.id), true);
      expect(c.exercises.single.sets.single.reps, 6);
      expect(c.exercises.single.sets.single.loadType, body);
      expect(c.totalVolume, 0);
    },
  );
  test(
    'voluntary previous action applies only that set and its known mode',
    () async {
      final c = await fresh(
        'pull_up',
        repository: TrainingFixtureRepository([weightedHistory()]),
      );
      final e = c.exercises.single, s = e.sets.single;
      c.applyPreviousSet(e.id, s.id);
      expect(c.exercises.single.sets.single.loadType, added);
      expect(c.exercises.single.sets.single.kg, 10);
      expect(c.exercises.single.defaultMode, body);
      expect(c.completeSet(e.id, s.id), true);
      expect(c.totalVolume, 60);
    },
  );
  test(
    'mixed routine targets take precedence and survive serialization',
    () async {
      final exercise =
          RoutineLabels.defaults(
            exerciseLibrary.firstWhere((d) => d.id == 'pull_up'),
          ).copyWith(
            targetSets: 3,
            targetReps: 10,
            setTargets: const [
              RoutineSetTarget(loadType: body, reps: 12),
              RoutineSetTarget(loadType: added, weightKg: 10, reps: 6),
              RoutineSetTarget(loadType: assisted, assistanceKg: 20, reps: 15),
            ],
          );
      final routine = await RoutinesRepository().saveRoutine(
        name: 'Mi plan',
        workoutType: WorkoutType.strength,
        exercises: [exercise],
      );
      final c = WorkoutSessionController();
      addTearDown(c.dispose);
      await c.initialize(templateId: routine.id);
      final e = c.exercises.single;
      expect(e.sets.map((s) => s.loadType), [body, added, assisted]);
      expect(e.sets.map((s) => s.reps), [12, 6, 15]);
      expect(e.sets[1].kg, 10);
      expect(e.sets[2].assistanceKg, 20);
      for (final s in e.sets) {
        expect(c.completeSet(e.id, s.id), true);
      }
      expect(c.totalVolume, 60);
      final proposal = RoutineUpdateFromSession.build(routine, c.exercises);
      expect(proposal, isNull); // Same effective targets, no needless rewrite.
    },
  );
  test('legacy assisted plan values remain assistance; inactive added load is never assistance', () async {
    final old = WorkoutExercise.fromJson({
      'id': 'pull_up',
      'name': 'Dominadas',
      'targetSets': 1,
      'targetReps': 8,
      'targetLoadType': 'assistedKg',
      'targetWeightKg': 25,
    });
    expect(old.plannedLoad, 25);
    final modern = old.copyWith(
      loadSchemaVersion: 1,
      targetWeightKg: 15,
      clearTargetAssistanceKg: true,
    );
    expect(modern.plannedLoad, isNull);
    final routine = await RoutinesRepository().saveRoutine(
      name: 'Antigua',
      workoutType: WorkoutType.strength,
      exercises: [old],
    );
    final c = WorkoutSessionController();
    addTearDown(c.dispose);
    await c.initialize(templateId: routine.id);
    expect(c.exercises.single.sets.single.assistanceKg, 25);
    c.updateLoadType(c.exercises.single.id, body);
    c.updateLoadType(c.exercises.single.id, added);
    final s = c.exercises.single.sets.single;
    expect(s.kg, isNull);
    expect(s.assistanceKg, 25);
    expect(c.completeSet(c.exercises.single.id, s.id), false);
  });
  test('ambiguous old bodyweight kg stays visible, unmodified and excluded from load PRs', () async {
    final old = SetEntry.fromJson({
      'id': 'legacy',
      'weight': 70,
      'reps': 8,
      'done': true,
    });
    final e = WorkoutExercise(
      id: 'pull_up',
      name: 'Dominadas',
      targetLoadType: RoutineExerciseLoadType.weightedKg,
      sets: [old],
    );
    final session = WorkoutSession(
      id: 'old-session',
      date: DateTime(2026, 10, 12),
      type: WorkoutType.strength,
      exercises: [e],
    );
    final repository = WorkoutRepository();
    await repository.persistLegacySession(session);
    final prefs = await ScopedPreferences.getInstance();
    final before = prefs.get(WorkoutRepository.legacySessionsKey);
    final index = await repository.performanceIndex();
    expect(index.records, isEmpty);
    expect(
      index.exerciseHistory('pull_up').single.label,
      contains('sin clasificar'),
    );
    expect(WorkoutReport(session).externalVolume, 0);
    expect(
      (await repository.getPreviousSetsForExercise('pull_up')).single.label,
      contains('sin clasificar'),
    );
    expect(prefs.get(WorkoutRepository.legacySessionsKey), before);
    expect(old.externalLoadKg, 70);
    expect(old.id, 'legacy');
  });
  test('PRs, plots and volumes separate bodyweight, added and each assistance level', () {
    final e = WorkoutExercise(
      id: 'pull_up',
      name: 'Dominadas',
      targetLoadType: body,
      sets: [
        SetEntry(
          id: 'b',
          loadType: body,
          reps: 10,
          done: true,
          bodyweightKg: 80,
        ),
        SetEntry(
          id: 'w',
          loadType: added,
          externalLoadKg: 12,
          reps: 8,
          done: true,
          bodyweightKg: 80,
        ),
        SetEntry(
          id: 'a',
          loadType: assisted,
          externalLoadKg: 12,
          assistanceKg: 20,
          reps: 15,
          done: true,
        ),
        SetEntry(
          id: 'a2',
          loadType: assisted,
          assistanceKg: 30,
          reps: 20,
          done: true,
        ),
        SetEntry(
          id: 'warm',
          loadType: added,
          externalLoadKg: 20,
          reps: 10,
          done: true,
          kind: SetKind.warmup,
        ),
      ],
    );
    final session = WorkoutSession(
      id: 'mixed',
      date: DateTime(2026, 10, 12),
      type: WorkoutType.strength,
      exercises: [e],
    );
    final index = TrainingPerformanceIndex([
      session,
    ], asOf: DateTime(2026, 10, 24));
    expect(WorkoutReport(session).externalVolume, 96);
    expect(
      index.records.where((r) => r.kind == RecordKind.load).single.value,
      12,
    );
    expect(
      index.records.where((r) => r.kind == RecordKind.estimatedMax),
      isEmpty,
    );
    expect(
      index.exerciseHistory('pull_up').map((o) => o.loadKey).toSet().length,
      4,
    );
    expect(
      index
          .exerciseHistory('pull_up')
          .where((o) => o.sets.first.loadType == body)
          .single
          .volume,
      0,
    );
    expect(
      index
          .exerciseHistory('pull_up')
          .where((o) => o.sets.first.loadType == assisted)
          .every((o) => o.volume == 0),
      true,
    );
  });
  test('legacy draft conversion retains body mass, ambiguous kg and an exact original backup', () async {
    final prefs = await ScopedPreferences.getInstance();
    final raw = jsonEncode({
      'type': 'strength',
      'workoutId': 'keep-session',
      'exercises': [
        {
          'id': 'pull_up',
          'name': 'Dominadas',
          'targetLoadType': 'bodyweight',
          'sets': [
            {
              'id': 'keep-set',
              'weight': 70,
              'bodyweightKg': 80,
              'bodyweightFactor': 1.0,
              'reps': 8,
              'done': true,
            },
          ],
        },
      ],
    });
    await prefs.setString(LegacyDraftMigration.legacyDraftKey, raw);
    expect(await LegacyDraftMigration.run(prefs), true);
    final s =
        (await WorkoutRepository().loadDraftExercises())!.single.sets.single;
    expect(s.id, 'keep-set');
    expect(s.kg, 70);
    expect(s.bodyweightKg, 80);
    expect(s.loadIsAmbiguous, true);
    expect(
      prefs.getStringList('workout_legacy_draft_sources_v1'),
      contains(raw),
    );
  });
  test(
    'history suggestions keep repetitions separate at each assistance amount',
    () async {
      final repository = TrainingFixtureRepository([
        WorkoutSession(
          id: 'assistance-history',
          date: DateTime(2026, 10, 12),
          type: WorkoutType.strength,
          exercises: [
            WorkoutExercise(
              id: 'pull_up',
              name: 'Dominadas',
              sets: [
                SetEntry(
                  id: 'a20',
                  loadType: assisted,
                  assistanceKg: 20,
                  reps: 6,
                  done: true,
                ),
                SetEntry(
                  id: 'a30',
                  loadType: assisted,
                  assistanceKg: 30,
                  reps: 12,
                  done: true,
                ),
              ],
            ),
          ],
        ),
      ]);
      final c = WorkoutSessionController(repository: repository);
      addTearDown(c.dispose);
      await c.initialize(
        initialExercises: [
          const ExerciseInSession(
            id: 'live',
            exerciseId: 'pull_up',
            name: 'Dominadas',
            sets: [
              SetInSession(
                id: 's20',
                index: 1,
                loadType: assisted,
                assistanceKg: 20,
              ),
              SetInSession(
                id: 's30',
                index: 2,
                loadType: assisted,
                assistanceKg: 30,
              ),
            ],
          ),
        ],
      );
      await c.addSet('live');
      expect(c.exercises.single.sets.take(2).map((s) => s.reps), [6, 12]);
      expect(c.exercises.single.sets.take(2).map((s) => s.assistanceKg), [
        20,
        30,
      ]);
      expect(
        await repository.getCompatibleSuggestions(
          const ExerciseInSession(
            id: 'empty',
            exerciseId: 'pull_up',
            name: 'Dominadas',
            sets: [],
          ),
        ),
        isEmpty,
      );
    },
  );
}
