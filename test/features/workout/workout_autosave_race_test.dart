import 'dart:async';

import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedDraftRepository extends WorkoutRepository {
  Completer<void>? holdNextWrite;
  final writeStarted = Completer<void>();
  bool failNextWrite = false;

  @override
  Future<void> persistDraftWithStartTime(
    List<ExerciseInSession> exercises, {
    required DateTime startTime,
    String? workoutId,
    String? routineId,
    String? routineName,
    String? sourceSessionId,
    WorkoutType workoutType = WorkoutType.strength,
    int? restStartedAtElapsedSeconds,
    int? restDurationSeconds,
    String? restSourceSetId,
    bool clearRest = false,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('disk unavailable');
    }
    final hold = holdNextWrite;
    if (hold != null) {
      holdNextWrite = null;
      if (!writeStarted.isCompleted) writeStarted.complete();
      await hold.future;
    }
    await super.persistDraftWithStartTime(
      exercises,
      startTime: startTime,
      workoutId: workoutId,
      routineId: routineId,
      routineName: routineName,
      sourceSessionId: sourceSessionId,
      workoutType: workoutType,
      restStartedAtElapsedSeconds: restStartedAtElapsedSeconds,
      restDurationSeconds: restDurationSeconds,
      restSourceSetId: restSourceSetId,
      clearRest: clearRest,
    );
  }
}

class DelayedHistoryRepository extends WorkoutRepository {
  final history = Completer<List<PreviousSet>>();
  int reads = 0;
  @override
  Future<List<PreviousSet>> getPreviousSetsForExercise(String exerciseId) {
    reads++;
    return history.future;
  }
}

const completedExercise = ExerciseInSession(
  id: 'exercise-1',
  exerciseId: 'bench_press',
  name: 'Press banca',
  sets: [SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8, done: true)],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'failed autosave exposes an error and retry preserves the latest edit',
    () async {
      final repository = DelayedDraftRepository();
      final controller = WorkoutSessionController(repository: repository);
      await controller.initialize(initialExercises: const [completedExercise]);
      repository.failNextWrite = true;
      controller.updateSet('exercise-1', 'set-1', reps: 13);
      await expectLater(controller.saveDraft(), throwsStateError);
      expect(controller.saveError, isNotNull);
      await controller.saveDraft();
      expect(controller.saveError, isNull);
      expect(
        (await repository.loadDraftExercises())!.single.sets.single.reps,
        13,
      );
      controller.dispose();
    },
  );

  test('late history preserves edits and simultaneous additions', () async {
    final repository = DelayedHistoryRepository();
    final controller = WorkoutSessionController(repository: repository);
    await controller.initialize(initialExercises: const [completedExercise]);
    final expansion = controller.toggleExerciseExpansion('exercise-1');
    controller.updateSet('exercise-1', 'set-1', reps: 12);
    final additions = [
      controller.addSet('exercise-1'),
      controller.addSet('exercise-1'),
    ];
    repository.history.complete(const [PreviousSet(kg: 40, reps: 8)]);
    await expansion;
    await Future.wait(additions);
    expect(controller.exercises.single.sets, hasLength(3));
    expect(controller.exercises.single.sets.first.reps, 12);
    expect(repository.reads, 1);
    await controller.saveDraft();
    controller.dispose();
  });

  test('history arriving after removal and disposal is harmless', () async {
    final repository = DelayedHistoryRepository();
    final controller = WorkoutSessionController(repository: repository);
    await controller.initialize(initialExercises: const [completedExercise]);
    final expansion = controller.toggleExerciseExpansion('exercise-1');
    controller.removeExercise('exercise-1');
    controller.dispose();
    repository.history.complete([]);
    await expansion;
    expect(controller.exercises, isEmpty);
  });

  test('disposing flushes the last keystroke without debounce delay', () async {
    final repository = WorkoutRepository();
    final controller = WorkoutSessionController(repository: repository);
    await controller.initialize(initialExercises: const [completedExercise]);
    controller.updateSet('exercise-1', 'set-1', reps: 11);
    controller.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(
      (await repository.loadDraftExercises())!.single.sets.single.reps,
      11,
    );
  });

  test(
    'finishing waits for an in-flight autosave before clearing draft',
    () async {
      final repository = DelayedDraftRepository();
      final controller = WorkoutSessionController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize(initialExercises: const [completedExercise]);

      final hold = Completer<void>();
      repository.holdNextWrite = hold;
      controller.updateSet('exercise-1', 'set-1', reps: 9);
      await repository.writeStarted.future.timeout(const Duration(seconds: 2));

      final finish = controller.finishWorkout();
      hold.complete();
      expect(await finish, isTrue);
      expect(await repository.loadDraftExercises(), isNull);
      expect(await repository.listSessions(), hasLength(1));
    },
  );

  test(
    'discard waits for an in-flight autosave before clearing draft',
    () async {
      final repository = DelayedDraftRepository();
      final controller = WorkoutSessionController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize(initialExercises: const [completedExercise]);

      final hold = Completer<void>();
      repository.holdNextWrite = hold;
      controller.updateSet('exercise-1', 'set-1', reps: 9);
      await repository.writeStarted.future.timeout(const Duration(seconds: 2));

      final discard = controller.discardWorkout();
      hold.complete();
      await discard;
      expect(await repository.loadDraftExercises(), isNull);
    },
  );
}
