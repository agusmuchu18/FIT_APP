import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import 'sport_activity.dart';
import 'routine_display_names.dart';

class RoutineLabels {
  static const equipment = {
    'barbell': 'Barra',
    'dumbbell': 'Mancuerna',
    'cable': 'Polea',
    'machine': 'Máquina',
    'bodyweight': 'Peso corporal',
    'kettlebell': 'Pesa rusa',
    'band': 'Banda',
    'other': 'Otro',
    'bench': 'Banco',
    'smith': 'Máquina Smith',
  };
  static String equipmentName(String? value) =>
      equipment[value?.toLowerCase()] ?? value ?? 'Sin equipamiento';
  static String load(RoutineExerciseLoadType value) => switch (value) {
    RoutineExerciseLoadType.bodyweight => 'Peso corporal',
    RoutineExerciseLoadType.weightedKg => 'Carga externa',
    RoutineExerciseLoadType.addedWeightKg => 'Lastre',
    RoutineExerciseLoadType.assistedKg => 'Asistencia',
    RoutineExerciseLoadType.machineKg => 'Carga en máquina',
  };
  static String exerciseName(String name) => routineDisplayNames[name] ?? name;

  static String summary(WorkoutExercise e) {
    if (e.sportPlan != null) {
      return 'Fútbol · ${e.sportPlan!.mode.label} · ${e.restEnabled == false
          ? 'Sin descanso'
          : e.restSeconds == null
          ? 'Descanso heredado'
          : '${e.restSeconds}s recuperación'}';
    }
    final measure = e.isTimed
        ? '${e.targetDurationSeconds ?? '—'} s'
        : e.targetReps != null
        ? '${e.targetReps} repeticiones'
        : '${e.targetRepsMin}–${e.targetRepsMax} repeticiones';
    return '${e.targetSets} series · $measure${e.sportPurpose == null ? '' : ' · ${e.sportPurpose!.label}'} · ${load(e.targetLoadType)}${e.targetWeightKg == null ? '' : ' ${e.targetWeightKg} kg'} · ${e.restEnabled == false
        ? 'Sin descanso'
        : e.restSeconds == null
        ? 'Descanso heredado'
        : '${e.restSeconds! ~/ 60}:${(e.restSeconds! % 60).toString().padLeft(2, '0')} descanso'}${e.setTargets.isEmpty ? '' : ' · Por serie'}';
  }

  static WorkoutExercise defaults(ExerciseDefinition definition) =>
      WorkoutExercise(
        id: definition.id,
        name: definition.name,
        muscleGroup: definition.primaryMuscles.firstOrNull,
        equipment: definition.equipment,
        measurement: definition.defaultMeasurement,
        targetDurationSeconds: definition.isTimed ? 30 : null,
        targetLoadType: definition.equipment == 'bodyweight'
            ? RoutineExerciseLoadType.bodyweight
            : definition.loadType == LoadType.assistedBodyweight
            ? RoutineExerciseLoadType.assistedKg
            : definition.equipment == 'machine'
            ? RoutineExerciseLoadType.machineKg
            : definition.loadType == LoadType.external
            ? RoutineExerciseLoadType.weightedKg
            : RoutineExerciseLoadType.bodyweight,
      );
}
