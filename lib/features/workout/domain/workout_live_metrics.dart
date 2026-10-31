import 'session_models.dart';
import 'workout_analytics.dart';

/// The same presentation formulas are used live, after save and in history.
class WorkoutLiveMetrics {
  const WorkoutLiveMetrics._();
  static const radarMuscles = WorkoutAnalytics.muscles;
  static double computeTotalVolume(List<ExerciseInSession> exercises) =>
      WorkoutAnalytics.totalExternalVolume(
        WorkoutAnalytics.fromLive(exercises),
      );
  static Map<String, double> computeCurrentMuscleDistribution(
    List<ExerciseInSession> exercises,
  ) =>
      WorkoutAnalytics.muscleDistribution(WorkoutAnalytics.fromLive(exercises));
}
