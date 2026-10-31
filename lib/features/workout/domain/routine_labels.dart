import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import 'sport_activity.dart';
import 'routine_display_names.dart';
import 'training_units.dart';
import 'exercise_load_policy.dart';

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
    'medicine_ball': 'Balón medicinal',
    'rope': 'Cuerda',
    'sled': 'Trineo de entrenamiento',
    'carry': 'Transporte con carga',
  };
  static const categories = {
    'cardio',
    'estabilidad',
    'movilidad',
    'cuerpo completo',
    'full_body',
    'full body',
  };
  static const muscleNames = {
    'core': 'Zona media',
    'pantorrilla': 'Pantorrillas',
    'antebrazo': 'Antebrazos',
    'hombro anterior': 'Deltoides anteriores',
    'full_body': 'Cuerpo completo',
    'full body': 'Cuerpo completo',
  };
  static String muscleName(String value) {
    final text = muscleNames[value.toLowerCase()] ?? value.replaceAll('_', ' ');
    return text.isEmpty
        ? 'Sin datos'
        : '${text[0].toUpperCase()}${text.substring(1)}';
  }

  static String muscles(List<String> values) =>
      values.isEmpty ? 'Sin datos' : values.map(muscleName).join(', ');
  static String pattern(String value) =>
      const {
        'push': 'Empuje',
        'pull': 'Tracción',
        'hinge': 'Bisagra de cadera',
        'squat': 'Sentadilla',
        'core': 'Zona media',
        'carry': 'Transporte con carga',
        'isolation': 'Aislamiento',
        'general': 'General',
      }[value] ??
      muscleName(value);
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

  static String summary(
    WorkoutExercise e, {
    TrainingUnits units = const TrainingUnits(),
  }) {
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
    return '${e.targetSets} series · $measure${e.sportPurpose == null ? '' : ' · ${e.sportPurpose!.label}'} · ${load(e.targetLoadType)}${e.targetLoadType == RoutineExerciseLoadType.bodyweight || e.plannedLoad == null ? '' : ' ${units.valueWithUnit('kg', e.plannedLoad!)}'} · ${e.restEnabled == false
        ? 'Sin descanso'
        : e.restSeconds == null
        ? 'Descanso heredado'
        : '${e.restSeconds! ~/ 60}:${(e.restSeconds! % 60).toString().padLeft(2, '0')} descanso'}${e.setTargets.isEmpty ? '' : ' · Por serie'}';
  }

  static String setTargetSummary(
    WorkoutExercise e,
    RoutineSetTarget target,
    TrainingUnits units,
  ) {
    final mode = target.loadType ?? e.targetLoadType;
    final amount = target.loadFor(e.targetLoadType);
    return '${load(mode)}${mode == RoutineExerciseLoadType.bodyweight || amount == null ? '' : ' ${units.valueWithUnit('kg', amount)}'}';
  }

  static WorkoutExercise defaults(ExerciseDefinition definition) =>
      WorkoutExercise(
        id: definition.id,
        name: definition.name,
        muscleGroup: definition.primaryMuscles.firstOrNull,
        equipment: definition.equipment,
        measurement: definition.defaultMeasurement,
        targetDurationSeconds: definition.isTimed ? 30 : null,
        loadSchemaVersion: 1,
        targetLoadType: ExerciseLoadPolicy.defaultFor(definition),
      );
}
