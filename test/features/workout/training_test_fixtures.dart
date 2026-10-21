import 'package:fit_app/features/workout/data/training_library_repository.dart';
import 'package:fit_app/features/workout/domain/training_program.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';

class TrainingFixtureRepository extends WorkoutRepository {
  TrainingFixtureRepository(this.sessions);
  final List<WorkoutSession> sessions;
  @override
  Future<TrainingPerformanceIndex> performanceIndex({
    bool refresh = false,
  }) async => TrainingPerformanceIndex(sessions, asOf: DateTime(2026, 10, 17));
  @override
  Future<List<WorkoutSession>> listAllSessions() async => sessions;
}

class TrainingFixtureLibrary extends TrainingLibraryRepository {
  @override
  Future<List<TrainingProgram>> programs() async => [];
  String note = 'Ajustar el banco antes de empezar';
  bool fail = false;
  @override
  Future<String> exerciseNote(String exerciseId) async => note;
  @override
  Future<void> saveExerciseNote(String exerciseId, String text) async {
    if (fail) throw StateError('Fixture persistence failure');
    note = text;
  }
}

WorkoutExercise trainingFixtureExercise() => WorkoutExercise(
  id: 'bench_press',
  name: 'Press banca',
  targetLoadType: RoutineExerciseLoadType.weightedKg,
);
List<WorkoutSession> trainingFixtureSessions() => [
  for (var i = 0; i < 4; i++)
    WorkoutSession(
      id: 'session-$i',
      type: WorkoutType.strength,
      date: DateTime(2026, 10, 1 + i * 3),
      durationSeconds: 1200,
      durationIsActive: true,
      exercises: [
        WorkoutExercise(
          id: 'bench_press',
          name: 'Press banca',
          targetLoadType: RoutineExerciseLoadType.weightedKg,
          sets: [
            SetEntry(
              id: 'set-$i',
              reps: 8,
              externalLoadKg: 50 + i * 2.5,
              done: true,
            ),
          ],
        ),
      ],
    ),
];
