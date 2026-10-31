import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';

/// Classification is based on catalogue metadata, never the amount entered.
abstract final class ExerciseLoadPolicy {
  static const bodyweightModes = [
    RoutineExerciseLoadType.bodyweight,
    RoutineExerciseLoadType.addedWeightKg,
    RoutineExerciseLoadType.assistedKg,
  ];
  static bool isBodyweight(
    ExerciseDefinition? definition, {
    String? equipment,
  }) =>
      definition?.loadType != null &&
          definition!.loadType != LoadType.external ||
      (definition?.equipment ?? equipment)?.toLowerCase() == 'bodyweight';

  static RoutineExerciseLoadType defaultFor(ExerciseDefinition? definition) {
    if (definition?.loadType == LoadType.assistedBodyweight) {
      return RoutineExerciseLoadType.assistedKg;
    }
    if (isBodyweight(definition)) return RoutineExerciseLoadType.bodyweight;
    return definition?.equipment == 'machine'
        ? RoutineExerciseLoadType.machineKg
        : RoutineExerciseLoadType.weightedKg;
  }
}
