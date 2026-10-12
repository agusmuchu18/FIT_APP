import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/workout_live_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown exercises are not attributed to Core', () {
    final distribution = WorkoutLiveMetrics.computeCurrentMuscleDistribution([
      ExerciseInSession(
        id: 'instance-1',
        exerciseId: 'custom_unknown_exercise',
        name: 'Ejercicio personalizado',
        sets: const [
          SetInSession(id: 'set-1', index: 1, kg: 20, reps: 10, done: true),
        ],
      ),
    ]);

    expect(distribution.values, everyElement(0));
  });

  test('planned exercises are not shown as completed muscle work', () {
    final distribution = WorkoutLiveMetrics.computeCurrentMuscleDistribution([
      ExerciseInSession(
        id: 'instance-1',
        exerciseId: 'bench_press',
        name: 'Press banca',
        sets: const [SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8)],
      ),
    ]);
    expect(distribution.values, everyElement(0));
  });
}
