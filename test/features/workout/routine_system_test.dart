import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/domain/sport_activity.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/template_workout_type.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccountStorageScope.current = '';
  });
  test('real catalogue has 297 unique IDs, pagination reaches all and Spanish equipment search works', () async {
    expect(exerciseLibrary, hasLength(297));
    expect(exerciseLibrary.map((e) => e.id).toSet(), hasLength(297));
    final c = ExercisePickerController(exercises: exerciseLibrary);
    addTearDown(c.dispose);
    while (c.canShowMore) {
      c.showMore();
    }
    expect(c.itemsVisible, hasLength(297));
    c.setQueryDebounced('mancuerna');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(c.totalCount, greaterThan(0));
    expect(c.itemsVisible.every((e) => e.equipment == 'dumbbell'), true);
    c.setEquipmentFilters({'bodyweight'});
    expect(c.totalCount, 0);
    final pull = RoutineLabels.defaults(
      exerciseLibrary.singleWhere((e) => e.id == 'pull_up'),
    );
    expect(pull.targetLoadType, RoutineExerciseLoadType.bodyweight);
    expect(pull.targetWeightKg, isNull);
  });
  test('one recoverable draft keeps configuration, headers, order and explicit duplicates', () async {
    final d = RoutineDraftController();
    addTearDown(d.dispose);
    d.toggleExercise('bench_press');
    d.updateHeader(name: 'Martes', notes: 'Objetivo de rutina');
    final e = d.items.single;
    d.update(
      e.instanceId!,
      e.copyWith(
        targetSets: 2,
        targetReps: 10,
        targetWeightKg: 35,
        restEnabled: false,
        restSeconds: 45,
        setTargets: [
          const RoutineSetTarget(reps: 12, weightKg: 30),
          const RoutineSetTarget(reps: 8, weightKg: 40),
        ],
      ),
    );
    expect(d.add(e), false);
    d.duplicate(0);
    d.reorder(1, 0);
    await d.flush();
    final recovered = RoutineDraftController();
    addTearDown(recovered.dispose);
    await recovered.restore();
    expect(recovered.name, 'Martes');
    expect(recovered.notes, 'Objetivo de rutina');
    expect(recovered.items, hasLength(2));
    expect(recovered.items.first.setTargets.last.weightKg, 40);
    expect(recovered.items.first.restEnabled, false);
    expect(recovered.items.map((e) => e.instanceId).toSet(), hasLength(2));
    recovered.removeExerciseAt(0);
    expect(recovered.items, hasLength(1));
    await recovered.flush();
  });
  test(
    'draft captures account owner and never crosses guest/accounts',
    () async {
      AccountStorageScope.current = AccountStorageScope.forUser('a');
      final a = RoutineDraftController();
      addTearDown(a.dispose);
      a.toggleExercise('plank');
      a.updateHeader(name: 'A');
      AccountStorageScope.current = AccountStorageScope.forUser('b');
      await a.flush();
      final b = RoutineDraftController();
      addTearDown(b.dispose);
      await b.restore();
      expect(b.items, isEmpty);
      AccountStorageScope.current = AccountStorageScope.forUser('a');
      final reopened = RoutineDraftController();
      addTearDown(reopened.dispose);
      await reopened.restore();
      expect(reopened.name, 'A');
    },
  );
  test('mode switching preserves compatible gym data and requires explicit incompatible decision', () async {
    final d = RoutineDraftController();
    addTearDown(d.dispose);
    d.toggleExercise('bench_press');
    d.updateHeader(name: 'Objetivo');
    d.setMode(TemplateWorkoutType.sport, FootballMode.gym);
    expect(d.items.single.id, 'bench_press');
    expect(
      () => d.setMode(TemplateWorkoutType.sport, FootballMode.technical),
      throwsStateError,
    );
    d.setMode(
      TemplateWorkoutType.sport,
      FootballMode.technical,
      discardIncompatible: true,
    );
    expect(d.items, isEmpty);
    expect(d.name, 'Objetivo');
    await d.flush();
  });
  test(
    'new fields roundtrip and stable routine ID makes save retry idempotent',
    () async {
      final repo = RoutinesRepository();
      final e = WorkoutExercise(
        id: 'pull_up',
        name: 'Dominadas pronas',
        targetLoadType: RoutineExerciseLoadType.addedWeightKg,
        targetWeightKg: 10,
        restEnabled: true,
        restSeconds: 90,
      );
      await repo.saveRoutine(
        name: 'Fútbol',
        routineId: 'same',
        notes: 'Notas',
        footballMode: FootballMode.gym,
        workoutType: WorkoutType.sport,
        exercises: [e],
      );
      await repo.saveRoutine(
        name: 'Fútbol editado',
        routineId: 'same',
        notes: 'Notas',
        footballMode: FootballMode.gym,
        workoutType: WorkoutType.sport,
        exercises: [e],
      );
      final saved = (await repo.getAllRoutines()).single;
      expect(saved.id, 'same');
      expect(saved.footballMode, FootballMode.gym);
      expect(saved.notes, 'Notas');
      expect(
        saved.exercises.single.targetLoadType,
        RoutineExerciseLoadType.addedWeightKg,
      );
      final old = WorkoutTemplate.fromJson({
        'id': 'legacy',
        'name': 'Anterior',
        'type': 'strength',
        'exercises': [
          {'id': 'bench_press', 'name': 'Press banca'},
        ],
      });
      expect(old.id, 'legacy');
      expect(old.footballMode, isNull);
      expect(old.exercises.single.targetSets, 3);
      expect(
        () => repo.saveRoutine(
          name: '',
          workoutType: WorkoutType.strength,
          exercises: [],
        ),
        throwsArgumentError,
      );
    },
  );
  test('per-set targets and disabled rest reach session and never mutate the saved routine', () async {
    final repo = RoutinesRepository();
    final routine = await repo.saveRoutine(
      name: 'Pirámide',
      workoutType: WorkoutType.strength,
      exercises: [
        WorkoutExercise(
          id: 'bench_press',
          name: 'Press banca',
          targetSets: 2,
          restEnabled: false,
          restSeconds: 90,
          targetLoadType: RoutineExerciseLoadType.weightedKg,
          setTargets: [
            const RoutineSetTarget(reps: 12, weightKg: 30),
            const RoutineSetTarget(reps: 8, weightKg: 40),
          ],
        ),
      ],
    );
    final before = jsonEncode(routine.toJson());
    final c = WorkoutSessionController(repository: WorkoutRepository());
    addTearDown(c.dispose);
    await c.initialize(templateId: routine.id);
    expect(c.exercises.single.sets.map((s) => s.kg), [30, 40]);
    expect(c.exercises.single.sets.map((s) => s.reps), [12, 8]);
    expect(c.exercises.single.restEnabled, false);
    expect(c.exercises.single.sets.every((s) => !s.done), true);
    final live = c.exercises.single;
    c.updateSet(live.id, live.sets.first.id, kg: 45, reps: 5, done: true);
    await c.finishWorkout();
    expect(jsonEncode((await repo.getAllRoutines()).single.toJson()), before);
    final history = (await WorkoutRepository().listAllSessions()).single;
    expect(history.templateId, routine.id);
    expect(WorkoutReport(history).externalVolume, 225);
  });
  for (final mode in FootballMode.values.where((m) => m != FootballMode.gym)) {
    test(
      'football ${mode.name}: plan → save → reopen → session → actual results → history',
      () async {
        final activity = footballActivities.firstWhere((a) => a.mode == mode);
        final targets = SportMeasurements(
          values: {SportMetric.durationSeconds: 120},
        );
        final plan = SportActivityPlan(
          activityId: activity.id,
          mode: mode,
          targets: targets,
          objective: 'Trabajo planificado',
        );
        final routine = await RoutinesRepository().saveRoutine(
          name: 'Fútbol ${mode.label}',
          workoutType: WorkoutType.sport,
          footballMode: mode,
          exercises: [
            WorkoutExercise(
              id: activity.id,
              name: activity.name,
              measurement: 'seconds',
              targetSets: 1,
              sportPlan: plan,
            ),
          ],
        );
        final reopened = (await RoutinesRepository().getAllRoutines()).single;
        expect(reopened.footballMode, mode);
        expect(
          reopened.exercises.single.sportPlan!.targets.values[SportMetric
              .durationSeconds],
          120,
        );
        final c = WorkoutSessionController(repository: WorkoutRepository());
        addTearDown(c.dispose);
        await c.initialize(templateId: routine.id);
        final live = c.exercises.single;
        expect(live.sportResult, isNull);
        expect(live.sets.single.durationSeconds, isNull);
        expect(live.sets.single.done, false);
        c.updateSet(live.id, live.sets.single.id, done: true);
        expect(c.exercises.single.sets.single.done, false);
        final actual = SportMeasurements(
          values: {
            SportMetric.durationSeconds: 90,
            SportMetric.effort: 6,
            if (mode == FootballMode.physical) ...{
              SportMetric.distanceMeters: 20,
              SportMetric.repetitions: 4,
            },
            if (mode == FootballMode.competition) ...{
              SportMetric.playedMinutes: 1,
              SportMetric.goals: 2,
              SportMetric.assists: 1,
            },
          },
          position: mode == FootballMode.competition ? 'Delantero' : '',
          notes: 'Realizado',
        );
        c.updateSportResult(live.id, actual);
        c.updateSet(live.id, live.sets.single.id, done: true);
        expect(c.exercises.single.sets.single.done, true);
        await c.finishWorkout();
        final history = (await WorkoutRepository().listAllSessions()).single;
        expect(history.type, WorkoutType.sport);
        expect(history.templateId, routine.id);
        expect(history.exercises.single.sportResult!.toJson(), actual.toJson());
        expect(WorkoutReport(history).externalVolume, 0);
        expect(
          (await RoutinesRepository().getAllRoutines())
              .single
              .exercises
              .single
              .sportResult,
          isNull,
        );
      },
    );
  }
  test('sport metric validation rejects wrong units, negatives and impossible participation', () {
    final p = SportActivityPlan(
      activityId: 'football_match',
      mode: FootballMode.competition,
    );
    expect(
      p.resultValid(
        SportMeasurements(
          values: {
            SportMetric.durationSeconds: 60,
            SportMetric.playedMinutes: 2,
          },
        ),
      ),
      false,
    );
    expect(
      p.resultValid(
        SportMeasurements(
          values: {
            SportMetric.durationSeconds: 60,
            SportMetric.distanceMeters: 20,
          },
        ),
      ),
      false,
    );
    expect(SportMeasurements(values: {SportMetric.goals: 1.5}).valid, false);
    expect(SportMeasurements(values: {SportMetric.effort: 11}).valid, false);
  });
}
