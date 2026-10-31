import 'package:fit_app/features/workout/application/routine_update_from_session.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/relative_day_label.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/presentation/widgets/set_row.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExerciseInSession _exercise(
  String id, {
  List<SetInSession>? sets,
  bool restEnabled = false,
  WorkoutExercise? plan,
}) => ExerciseInSession(
  id: id,
  exerciseId: 'bench_press',
  name: 'Press banca $id',
  restEnabled: restEnabled,
  restSeconds: restEnabled ? 60 : null,
  plan: plan,
  sets: sets ?? const [SetInSession(id: 's1', index: 1, kg: 50, reps: 8)],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('live session', () {
    test('starting a routine opens its first exercise', () async {
      final routine = await RoutinesRepository().saveRoutine(
        name: 'Empuje',
        workoutType: WorkoutType.strength,
        exercises: [
          WorkoutExercise(id: 'bench_press', name: 'Press banca', targetReps: 8),
          WorkoutExercise(
            id: 'military_press',
            name: 'Press militar',
            targetReps: 8,
          ),
        ],
      );
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(templateId: routine.id);
      expect(controller.routineName, 'Empuje');
      expect(controller.expandedExerciseId, controller.exercises.first.id);
    });

    test('a resumed draft opens the first exercise with pending sets', () async {
      await WorkoutRepository().persistDraftWithStartTime(
        [
          _exercise(
            'a',
            sets: const [SetInSession(id: 'a1', index: 1, reps: 8, done: true)],
          ),
          _exercise('b', sets: const [SetInSession(id: 'b1', index: 1, reps: 8)]),
        ],
        startTime: DateTime.now(),
        workoutId: 'resume',
      );
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.expandedExerciseId, 'b');
    });

    test('finishing the last set opens the next exercise once', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [
          _exercise('a'),
          _exercise('b', sets: const [SetInSession(id: 'b1', index: 1)]),
        ],
      );
      expect(controller.expandedExerciseId, 'a');
      controller.updateSet('a', 's1', done: true);
      expect(controller.expandedExerciseId, 'b');
      expect(controller.consumeAutoAdvance(), 'b');
      expect(controller.consumeAutoAdvance(), isNull);
      await controller.saveDraft();
    });

    test('check fills empty values from the previous session', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [
          _exercise(
            'a',
            sets: const [
              SetInSession(
                id: 's1',
                index: 1,
                previous: PreviousSet(kg: 60, reps: 6),
              ),
            ],
          ),
        ],
      );
      expect(controller.completeSet('a', 's1'), isTrue);
      final set = controller.exercises.single.sets.single;
      expect(set.done, isTrue);
      expect(set.kg, 60);
      expect(set.reps, 6);
      await controller.saveDraft();
    });

    test('check without any value to use does not complete', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [
          _exercise('a', sets: const [SetInSession(id: 's1', index: 1)]),
        ],
      );
      expect(controller.completeSet('a', 's1'), isFalse);
      expect(controller.exercises.single.sets.single.done, isFalse);
      await controller.saveDraft();
    });

    test('removed exercises and sets can be restored in place', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [
          _exercise('a'),
          _exercise(
            'b',
            sets: const [
              SetInSession(id: 'b1', index: 1, reps: 5, done: true),
              SetInSession(id: 'b2', index: 2, reps: 6),
            ],
          ),
          _exercise('c'),
        ],
      );
      final exercise = controller.removeExercise('b')!;
      expect(controller.exercises.map((e) => e.id), ['a', 'c']);
      controller.restoreExercise(exercise);
      expect(controller.exercises.map((e) => e.id), ['a', 'b', 'c']);
      expect(controller.exercises[1].sets.first.done, isTrue);

      final set = controller.removeSet('b', 'b1')!;
      expect(controller.exercises[1].sets.single.index, 1);
      controller.restoreSet(set);
      expect(controller.exercises[1].sets.map((s) => s.id), ['b1', 'b2']);
      expect(controller.exercises[1].sets.map((s) => s.index), [1, 2]);
      await controller.saveDraft();
    });

    test('rest can be shortened, extended and ends when shortened past zero', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [_exercise('a', restEnabled: true)],
      );
      controller.updateSet('a', 's1', done: true);
      expect(controller.restDurationSeconds, 60);
      controller.adjustRest(15);
      expect(controller.restDurationSeconds, 75);
      controller.adjustRest(-15);
      expect(controller.restDurationSeconds, 60);
      controller.adjustRest(-120);
      expect(controller.hasActiveRest, isFalse);
      await controller.saveDraft();
    });

    test('pending sets can be kept, discarded or completed at the end', () async {
      List<ExerciseInSession> exercises() => [
        _exercise(
          'a',
          sets: const [
            SetInSession(id: 'a1', index: 1, reps: 8, done: true),
            SetInSession(id: 'a2', index: 2, reps: 8),
            SetInSession(id: 'a3', index: 3),
          ],
        ),
        _exercise('b', sets: const [SetInSession(id: 'b1', index: 1)]),
      ];
      for (final resolution in PendingSetsResolution.values) {
        // Each round starts without the previous round's saved draft.
        await WorkoutRepository().clearDraft();
        final controller = WorkoutSessionController();
        await controller.initialize(initialExercises: exercises());
        expect(controller.pendingSets, 3);
        expect(controller.fillablePendingSets, 1);
        controller.resolvePendingSets(resolution);
        final ids = controller.exercises.map((e) => e.id).toList();
        final aSets = controller.exercises.first.sets;
        switch (resolution) {
          case PendingSetsResolution.keepPending:
            expect(ids, ['a', 'b']);
            expect(aSets, hasLength(3));
          case PendingSetsResolution.discardPending:
            expect(ids, ['a']);
            expect(aSets.map((s) => s.id), ['a1']);
          case PendingSetsResolution.completeFilled:
            expect(ids, ['a']);
            expect(aSets.map((s) => s.id), ['a1', 'a2']);
            expect(aSets.every((s) => s.done), isTrue);
        }
        await controller.saveDraft();
        controller.dispose();
      }
    });
  });

  group('set kinds and supersets', () {
    test('warm-up sets are recorded but excluded from volume', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [
          _exercise(
            'a',
            sets: const [
              SetInSession(id: 'w', index: 1, kg: 20, reps: 10, done: true),
              SetInSession(id: 'n', index: 2, kg: 50, reps: 5, done: true),
            ],
          ),
        ],
      );
      expect(controller.totalVolume, 450);
      controller.updateSetKind('a', 'w', SetKind.warmup);
      expect(controller.exercises.single.sets.first.kind, SetKind.warmup);
      expect(controller.totalVolume, 250);
      final json = controller.exercises.single.toJson();
      final restored = ExerciseInSession.fromJson(json);
      expect(restored.sets.first.kind, SetKind.warmup);
      expect(restored.sets.last.kind, SetKind.normal);
      await controller.saveDraft();
    });

    test('superset: no rest between members, rest after the last one', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [
          _exercise(
            'a',
            restEnabled: true,
            sets: const [
              SetInSession(id: 'a1', index: 1, reps: 8),
              SetInSession(id: 'a2', index: 2, reps: 8),
            ],
          ),
          _exercise(
            'b',
            restEnabled: true,
            sets: const [
              SetInSession(id: 'b1', index: 1, reps: 8),
              SetInSession(id: 'b2', index: 2, reps: 8),
            ],
          ),
          _exercise('c', sets: const [SetInSession(id: 'c1', index: 1)]),
        ],
      );
      expect(controller.canLinkWithNext('a'), isTrue);
      controller.linkWithNext('a');
      expect(controller.supersetLabel('a'), 'A');
      expect(controller.supersetLabel('b'), 'A');
      expect(controller.supersetLabel('c'), isNull);

      controller.updateSet('a', 'a1', done: true);
      expect(controller.hasActiveRest, isFalse);
      expect(controller.expandedExerciseId, 'b');

      controller.updateSet('b', 'b1', done: true);
      expect(controller.hasActiveRest, isTrue);
      expect(controller.expandedExerciseId, 'a');

      controller.updateSet('a', 'a2', done: true);
      controller.updateSet('b', 'b2', done: true);
      expect(controller.expandedExerciseId, 'c');
      await controller.saveDraft();
    });

    test('a superset left with one member dissolves', () async {
      final controller = WorkoutSessionController();
      addTearDown(controller.dispose);
      await controller.initialize(
        initialExercises: [_exercise('a'), _exercise('b'), _exercise('c')],
      );
      controller.linkWithNext('a');
      controller.linkWithNext('b');
      expect(controller.supersetRange('a'), (start: 0, end: 2));
      controller.unlinkSuperset('b');
      expect(controller.supersetLabel('a'), isNull);
      expect(controller.supersetLabel('c'), isNull);

      controller.linkWithNext('a');
      controller.removeExercise('b');
      expect(controller.exercises.every((e) => e.supersetId == null), isTrue);
      await controller.saveDraft();
    });

    test('routine update ignores warm-ups and keeps the superset', () {
      final plan = WorkoutExercise(
        id: 'bench_press',
        name: 'Press banca',
        instanceId: 'i1',
        targetSets: 1,
        targetReps: 5,
        targetLoadType: RoutineExerciseLoadType.weightedKg,
        targetWeightKg: 50,
      );
      final result = RoutineUpdateFromSession.build(
        WorkoutTemplate(
          id: 'r',
          name: 'R',
          type: WorkoutType.strength,
          exercises: [plan],
        ),
        [
          _exercise(
            'a',
            plan: plan,
            sets: const [
              SetInSession(
                id: 'w',
                index: 1,
                kg: 20,
                reps: 10,
                done: true,
                kind: SetKind.warmup,
              ),
              SetInSession(id: 'n', index: 2, kg: 55, reps: 5, done: true),
            ],
          ).copyWith(supersetId: 's1'),
        ],
      )!;
      expect(result.single.targetSets, 1);
      expect(result.single.setTargets.single.weightKg, 55);
      expect(result.single.supersetId, 's1');
    });
  });

  group('routine update proposal', () {
    WorkoutTemplate routine(List<WorkoutExercise> exercises) => WorkoutTemplate(
      id: 'r',
      name: 'Rutina',
      type: WorkoutType.strength,
      origin: TemplateOrigin.user,
      exercises: exercises,
    );

    test('equal values propose nothing', () {
      final plan = WorkoutExercise(
        id: 'bench_press',
        name: 'Press banca',
        instanceId: 'i1',
        targetSets: 1,
        targetReps: 8,
        targetLoadType: RoutineExerciseLoadType.weightedKg,
        targetWeightKg: 50,
      );
      final result = RoutineUpdateFromSession.build(routine([plan]), [
        _exercise(
          'a',
          plan: plan,
          sets: const [SetInSession(id: 's', index: 1, kg: 50, reps: 8, done: true)],
        ),
      ]);
      expect(result, isNull);
    });

    test('heavier sets become the new targets; skipped exercises stay', () {
      final bench = WorkoutExercise(
        id: 'bench_press',
        name: 'Press banca',
        instanceId: 'i1',
        targetSets: 2,
        targetReps: 8,
        targetLoadType: RoutineExerciseLoadType.weightedKg,
        targetWeightKg: 50,
      );
      final row = WorkoutExercise(
        id: 'barbell_row',
        name: 'Remo',
        instanceId: 'i2',
        targetSets: 3,
        targetReps: 10,
      );
      final result = RoutineUpdateFromSession.build(routine([bench, row]), [
        _exercise(
          'a',
          plan: bench,
          sets: const [
            SetInSession(id: 's1', index: 1, kg: 55, reps: 8, done: true),
            SetInSession(id: 's2', index: 2, kg: 55, reps: 7, done: true),
          ],
        ),
      ])!;
      expect(result, hasLength(2));
      expect(result.first.targetSets, 2);
      expect(result.first.setTargets.map((t) => t.weightKg), [55, 55]);
      expect(result.first.setTargets.map((t) => t.reps), [8, 7]);
      expect(result.last.instanceId, 'i2');
      expect(result.last.targetSets, 3);
    });

    test('rep ranges are kept while loads update', () {
      final plan = WorkoutExercise(
        id: 'bench_press',
        name: 'Press banca',
        instanceId: 'i1',
        targetSets: 1,
        targetRepsMin: 8,
        targetRepsMax: 12,
        targetLoadType: RoutineExerciseLoadType.weightedKg,
        targetWeightKg: 40,
      );
      final result = RoutineUpdateFromSession.build(routine([plan]), [
        _exercise(
          'a',
          plan: plan,
          sets: const [SetInSession(id: 's', index: 1, kg: 45, reps: 11, done: true)],
        ),
      ])!;
      final target = result.single.setTargets.single;
      expect(target.weightKg, 45);
      expect(target.reps, isNull);
      expect(target.repsMin, 8);
      expect(target.repsMax, 12);
    });
  });

  group('inputs and labels', () {
    test('durations accept seconds and minutes:seconds', () {
      expect(parseDurationInput('90'), 90);
      expect(parseDurationInput('1:30'), 90);
      expect(parseDurationInput('0:45'), 45);
      expect(parseDurationInput('1:75'), isNull);
      expect(parseDurationInput('0'), isNull);
      expect(parseDurationInput('abc'), isNull);
      expect(formatDurationInput(45), '45');
      expect(formatDurationInput(90), '1:30');
    });

    test('relative days count calendar days, not 24-hour blocks', () {
      final now = DateTime(2026, 10, 23, 8);
      expect(relativeDayLabel(DateTime(2026, 10, 22, 23), now: now), 'ayer');
      expect(relativeDayLabel(DateTime(2026, 10, 23, 0, 30), now: now), 'hoy');
      expect(relativeDayLabel(DateTime(2026, 10, 20, 12), now: now), 'hace 3 días');
      expect(relativeDayLabel(null, now: now), 'Nunca');
    });

    testWidgets('kg shows without a trailing .0 and previous is tappable', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SetRow(
              set: const SetInSession(id: 's', index: 1, kg: 60, reps: 8),
              onChanged: ({kg, clearKg, reps, clearReps, done}) {},
            ),
          ),
        ),
      );
      final load = tester.widget<TextField>(
        find.byKey(const ValueKey('set-load-s')),
      );
      expect(load.controller!.text, '60');

      double? copiedKg;
      int? copiedReps;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SetRow(
              set: const SetInSession(
                id: 'p',
                index: 1,
                previous: PreviousSet(kg: 62.5, reps: 8),
              ),
              onChanged: ({kg, clearKg, reps, clearReps, done}) {
                copiedKg = kg ?? copiedKg;
                copiedReps = reps ?? copiedReps;
              },
            ),
          ),
        ),
      );
      expect(find.text('62,5 × 8'), findsOneWidget);
      await tester.tap(find.text('62,5 × 8'));
      await tester.pump();
      expect(copiedKg, 62.5);
      expect(copiedReps, 8);
    });
  });
}
