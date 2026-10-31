import '../pro/models/workout_models.dart';
import 'sport_activity.dart';

/// Validation applies to newly saved plans; reading older JSON never rewrites it.
class RoutinePlanValidation {
  static String? error(WorkoutExercise e) {
    if (e.targetSets < 1 || e.targetSets > 30) {
      return '${e.name}: usá entre 1 y 30 series.';
    }
    if (e.restSeconds != null && e.restSeconds! < 1) {
      return '${e.name}: el descanso debe ser positivo.';
    }
    if (e.sportPlan case final plan?) {
      final definition = footballActivities
          .where((a) => a.id == plan.activityId)
          .firstOrNull;
      if (definition == null ||
          definition.mode != plan.mode ||
          !plan.targets.valid ||
          plan.targets.values.keys.any(
            (m) => !definition.metrics.contains(m),
          )) {
        return '${e.name}: revisá los objetivos de la actividad.';
      }
      if (plan.targets.values[SportMetric.durationSeconds]
          case final seconds?) {
        if (seconds < 1) {
          return '${e.name}: el tiempo objetivo debe ser positivo.';
        }
      }
      if (plan.mode == FootballMode.physical &&
          [SportMetric.distanceMeters, SportMetric.repetitions].any(
            (m) =>
                plan.targets.values[m] != null && plan.targets.values[m]! <= 0,
          )) {
        return '${e.name}: distancia y repeticiones objetivo deben ser positivas.';
      }
      final played = plan.targets.values[SportMetric.playedMinutes];
      final duration = plan.targets.values[SportMetric.durationSeconds];
      if (played != null && duration != null && played * 60 > duration) {
        return '${e.name}: los minutos jugados no pueden superar la duración del partido.';
      }
      return null;
    }
    bool weight(double? n) => n == null || (n.isFinite && n >= 0);
    bool reps(int? n, int? min, int? max) =>
        n != null ? n > 0 : min != null && max != null && min > 0 && max >= min;
    if (!weight(e.targetWeightKg) || !weight(e.targetAssistanceKg)) {
      return '${e.name}: la carga es inválida.';
    }
    if (e.isTimed
        ? (e.targetDurationSeconds ?? 0) < 1
        : !reps(e.targetReps, e.targetRepsMin, e.targetRepsMax)) {
      return '${e.name}: revisá el tiempo o las repeticiones objetivo.';
    }
    if (e.setTargets.isNotEmpty && e.setTargets.length != e.targetSets) {
      return '${e.name}: la cantidad de objetivos debe coincidir con las series.';
    }
    for (final target in e.setTargets) {
      if (!weight(target.weightKg) ||
          !weight(target.assistanceKg) ||
          (e.isTimed
              ? (target.durationSeconds ?? 0) < 1
              : !reps(target.reps, target.repsMin, target.repsMax))) {
        return '${e.name}: revisá los objetivos individuales de cada serie.';
      }
    }
    return null;
  }
}
