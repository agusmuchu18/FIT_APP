import 'dart:async';

import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/training_program.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedSuggestionRepository extends WorkoutRepository {
  final suggestions = Completer<List<SetEntry>>();
  @override
  Future<List<SetEntry>> getCompatibleSuggestions(ExerciseInSession exercise) =>
      suggestions.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('adding a set inherits valid values with fresh identity and no completion, RIR, notes or timestamps', () async {
    final controller = WorkoutSessionController(
      repository: WorkoutRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize(
      initialExercises: [
        ExerciseInSession(
          id: 'e',
          exerciseId: 'bench_press',
          name: 'Press banca',
          sets: [
            SetInSession(
              id: 'original',
              index: 1,
              kg: 25,
              reps: 8,
              done: true,
              rir: 2,
              note: 'Solo esta serie',
              performedAt: DateTime(2026, 10, 17),
              loadConvention: LoadConvention.perImplement,
              implementCount: 2,
            ),
          ],
        ),
      ],
    );
    await controller.addSet('e');
    final set = controller.exercises.single.sets.last;
    expect(set.id, isNot('original'));
    expect(set.kg, 25);
    expect(set.reps, 8);
    expect(set.loadConvention, LoadConvention.perImplement);
    expect(set.implementCount, 2);
    expect(set.done, isFalse);
    expect(set.rir, isNull);
    expect(set.note, isNull);
    expect(set.performedAt, isNull);
    controller.updateSet('e', set.id, done: true);
    expect(controller.exercises.single.sets.last.performedAt, isNotNull);
    controller.updateSet('e', set.id, done: false);
    expect(controller.exercises.single.sets.last.kg, 25);
  });
  test('late suggestions preserve cleared fields and plan values; never complete a set', () async {
    final repository = DelayedSuggestionRepository();
    final session = WorkoutSessionController(repository: repository);
    addTearDown(session.dispose);
    await session.initialize(
      initialExercises: const [
        ExerciseInSession(
          id: 'e',
          exerciseId: 'bench_press',
          name: 'Press banca',
          sets: [
            SetInSession(id: 'one', index: 1, reps: 10),
            SetInSession(id: 'two', index: 2),
          ],
        ),
      ],
    );
    await session.toggleExerciseExpansion('e');
    final opening = session.toggleExerciseExpansion('e');
    await Future<void>.delayed(Duration.zero);
    session.updateSet('e', 'two', clearKg: true, clearReps: true);
    repository.suggestions.complete([
      SetEntry(id: 'history', externalLoadKg: 60, reps: 8, done: true),
    ]);
    await opening;
    expect(session.exercises.single.sets.first.reps, 10);
    expect(session.exercises.single.sets.first.kg, 60);
    expect(session.exercises.single.sets.last.kg, isNull);
    expect(session.exercises.single.sets.last.reps, isNull);
    expect(session.exercises.single.doneSets, 0);
  });
  test('program occurrence survives draft reload and completion without relabeling a resumed session', () async {
    final repository = WorkoutRepository();
    final execution = ProgramExecutionRef(
      programId: 'p',
      programName: 'Mi programa',
      dayId: 'd',
      date: DateTime(2026, 10, 19),
    );
    await repository.persistDraftWithStartTime(
      const [
        ExerciseInSession(
          id: 'e',
          exerciseId: 'bench_press',
          name: 'Press banca',
          sets: [SetInSession(id: 's', index: 1, kg: 60, reps: 8, done: true)],
        ),
      ],
      startTime: DateTime.now(),
      workoutId: 'program-session',
      routineId: 'r',
      programExecution: execution,
    );
    final controller = WorkoutSessionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize(
      programExecution: ProgramExecutionRef(
        programId: 'other',
        programName: 'Otra',
        dayId: 'x',
        date: DateTime(2026, 11, 1),
      ),
    );
    await controller.saveDraft();
    expect(
      (await repository.loadDraftIdentity())!.programExecution!.occurrenceKey,
      execution.occurrenceKey,
    );
    await controller.finishWorkout();
    final saved = (await repository.listAllSessions()).single;
    expect(saved.programExecution!.occurrenceKey, execution.occurrenceKey);
    expect(
      WorkoutSession.fromJson(saved.toJson()).programExecution!.programName,
      'Mi programa',
    );
  });
}
