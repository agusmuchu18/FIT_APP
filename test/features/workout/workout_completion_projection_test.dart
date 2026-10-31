import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/features/home/domain/home_activity_utils.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/application/workout_completion_recovery.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingFitnessRepository implements FitnessRepository {
  final entries = <String, WorkoutEntry>{};
  bool failNextSave = false;

  @override
  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('storage unavailable');
    }
    entries[entry.id] = entry;
  }

  @override
  Future<List<WorkoutEntry>> getWorkouts() async => entries.values.toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    'restart repairs a failed projection and clears only the completed draft',
    () async {
      final rich = WorkoutRepository();
      final central = RecordingFitnessRepository()..failNextSave = true;
      final controller = WorkoutSessionController(
        repository: rich,
        fitnessRepository: central,
      );
      await controller.initialize(initialExercises: const [completedExercise]);
      await expectLater(controller.finishWorkout(), throwsStateError);
      controller.dispose();
      await recoverCompletedWorkouts(rich, central);
      await recoverCompletedWorkouts(rich, central);
      expect(await central.getWorkouts(), hasLength(1));
      expect(await rich.loadDraftExercises(), isNull);
      await rich.persistDraftWithStartTime(
        [],
        startTime: DateTime(2026),
        workoutId: 'unfinished',
      );
      await recoverCompletedWorkouts(rich, central);
      expect((await rich.loadDraftIdentity())!.sessionId, 'unfinished');
    },
  );

  test('finishing projects one stable session into Home activity', () async {
    final rich = WorkoutRepository();
    final central = RecordingFitnessRepository();
    final controller = WorkoutSessionController(
      repository: rich,
      fitnessRepository: central,
    );
    addTearDown(controller.dispose);
    await controller.initialize(initialExercises: const [completedExercise]);
    final sessionId = (await rich.loadDraftIdentity())!.sessionId;

    expect(await controller.finishWorkout(), isTrue);
    expect(await controller.finishWorkout(), isFalse);
    final sessions = await rich.listSessions();
    final workouts = await central.getWorkouts();
    expect(sessions, hasLength(1));
    expect(workouts, hasLength(1));
    expect(sessions.single.id, sessionId);
    expect(workouts.single.id, sessionId);
    expect(await rich.loadDraftExercises(), isNull);
    expect(
      buildActiveDaysSet(
        workouts: workouts,
        meals: const [],
        sleepEntries: const [],
      ),
      contains(normalizeDay(DateTime.now())),
    );
  });

  test('an unrecorded session cannot be saved as completed', () async {
    final rich = WorkoutRepository();
    final central = RecordingFitnessRepository();
    final controller = WorkoutSessionController(
      repository: rich,
      fitnessRepository: central,
    );
    addTearDown(controller.dispose);
    await controller.initialize(
      initialExercises: const [
        ExerciseInSession(
          id: 'exercise-1',
          exerciseId: 'bench_press',
          name: 'Press banca',
          sets: [SetInSession(id: 'set-1', index: 1)],
        ),
      ],
    );

    await expectLater(
      controller.finishWorkout(),
      throwsA(isA<IncompleteWorkoutException>()),
    );
    expect(await rich.listSessions(), isEmpty);
    expect(await rich.loadDraftExercises(), isNotNull);
    expect(await central.getWorkouts(), isEmpty);
  });

  test(
    'failed Home save keeps draft and retry does not duplicate history',
    () async {
      final rich = WorkoutRepository();
      final central = RecordingFitnessRepository()..failNextSave = true;
      final controller = WorkoutSessionController(
        repository: rich,
        fitnessRepository: central,
      );
      addTearDown(controller.dispose);
      await controller.initialize(initialExercises: const [completedExercise]);

      await expectLater(controller.finishWorkout(), throwsStateError);
      expect(await rich.loadDraftExercises(), isNotNull);
      expect(await rich.listSessions(), hasLength(1));

      expect(await controller.finishWorkout(), isTrue);
      expect(await rich.listSessions(), hasLength(1));
      expect(await central.getWorkouts(), hasLength(1));
      expect(await rich.loadDraftExercises(), isNull);
    },
  );

  test(
    'session history keeps more than 100 entries and retries by ID',
    () async {
      final rich = WorkoutRepository();
      for (var i = 0; i < 101; i++) {
        await rich.persistCompletedWorkout(const [
          completedExercise,
        ], sessionId: 'session-$i');
      }
      await rich.persistCompletedWorkout(const [
        completedExercise,
      ], sessionId: 'session-100');

      final sessions = await rich.listSessions();
      expect(sessions, hasLength(101));
      expect(sessions.map((session) => session.id).toSet(), hasLength(101));
    },
  );
}
