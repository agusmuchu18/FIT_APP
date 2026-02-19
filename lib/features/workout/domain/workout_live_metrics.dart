import 'session_models.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/data/exercise_library.dart';

class WorkoutLiveMetrics {
  const WorkoutLiveMetrics._();

  static const List<String> radarMuscles = <String>[
    'Espalda',
    'Pecho',
    'Piernas',
    'Brazos',
    'Hombros',
    'Core',
  ];

  static double computeTotalVolume(List<ExerciseInSession> exercises) {
    return exercises.fold<double>(0, (sum, exercise) {
      return sum +
          exercise.sets.where((set) => set.done).fold<double>(0, (setSum, set) {
            return setSum + ((set.kg ?? 0) * (set.reps ?? 0));
          });
    });
  }

  /// Distribución normalizada (0..1) de la carga por grupo muscular para radar.
  ///
  /// Usa volumen por serie completada; cuando el volumen de una serie es 0,
  /// utiliza 1 punto como fallback para no dejar ejercicios sin impacto
  /// (ej. peso corporal sin carga externa).
  static Map<String, double> computeCurrentMuscleDistribution(
    List<ExerciseInSession> exercises,
  ) {
    final buckets = <String, double>{for (final muscle in radarMuscles) muscle: 0};

    for (final exercise in exercises) {
      final radarKey = _radarMuscleForExercise(exercise.exerciseId);
      if (radarKey == null) continue;

      for (final set in exercise.sets.where((item) => item.done)) {
        final setVolume = (set.kg ?? 0) * (set.reps ?? 0);
        buckets[radarKey] = (buckets[radarKey] ?? 0) + (setVolume > 0 ? setVolume : 1);
      }
    }

    final total = buckets.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return _plannedMuscleDistribution(exercises);
    }

    return buckets.map((key, value) => MapEntry(key, value / total));
  }

  /// Distribución fallback (0..1) basada en ejercicios planificados por músculo.
  static Map<String, double> _plannedMuscleDistribution(
    List<ExerciseInSession> exercises,
  ) {
    final buckets = <String, double>{for (final muscle in radarMuscles) muscle: 0};

    for (final exercise in exercises) {
      final radarKey = _radarMuscleForExercise(exercise.exerciseId);
      if (radarKey == null) continue;
      buckets[radarKey] = (buckets[radarKey] ?? 0) + 1;
    }

    final total = buckets.values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return buckets;
    }

    return buckets.map((key, value) => MapEntry(key, value / total));
  }

  static String? _radarMuscleForExercise(String exerciseId) {
    ExerciseDefinition? definition;
    for (final item in exerciseLibrary) {
      if (item.id == exerciseId) {
        definition = item;
        break;
      }
    }
    final primaryMuscle =
        definition == null || definition.primaryMuscles.isEmpty ? '' : definition.primaryMuscles.first.toLowerCase();

    if (primaryMuscle.contains('espalda') || primaryMuscle.contains('dorsal')) {
      return 'Espalda';
    }
    if (primaryMuscle.contains('pecho')) {
      return 'Pecho';
    }
    if (primaryMuscle.contains('pierna') || primaryMuscle.contains('cuádr') || primaryMuscle.contains('glúte') || primaryMuscle.contains('femor')) {
      return 'Piernas';
    }
    if (primaryMuscle.contains('bíceps') || primaryMuscle.contains('tríceps') || primaryMuscle.contains('antebra')) {
      return 'Brazos';
    }
    if (primaryMuscle.contains('hombro') || primaryMuscle.contains('delto')) {
      return 'Hombros';
    }
    if (primaryMuscle.contains('core') || primaryMuscle.contains('ab') || primaryMuscle.contains('oblic') || primaryMuscle.contains('lumbar')) {
      return 'Core';
    }

    return 'Core';
  }
}
