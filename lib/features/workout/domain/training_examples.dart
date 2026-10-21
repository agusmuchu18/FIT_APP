import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';
import 'routine_labels.dart';
import 'training_program.dart';
import 'routine_plan_validation.dart';

import 'package:uuid/uuid.dart';

class RoutineExample {
  const RoutineExample(
    this.id,
    this.name,
    this.description,
    this.exerciseIds,
    this.imageAsset,
  );
  final String id, name, description, imageAsset;
  final List<String> exerciseIds;
  List<WorkoutExercise> get plan => [
    for (final id in exerciseIds)
      RoutineLabels.defaults(exerciseLibrary.firstWhere((d) => d.id == id)),
  ];
  Set<String> get equipment =>
      plan.map((e) => RoutineLabels.equipmentName(e.equipment)).toSet();
}

/// Editable structures, not prescribed loads or fabricated training outcomes.
abstract final class TrainingExamples {
  static const routines = [
    RoutineExample(
      'full_body',
      'Ejemplo · Cuerpo completo',
      'Tres movimientos de empuje, tracción y piernas. Revisá cada objetivo antes de guardar.',
      ['back_squat', 'bench_press', 'seated_row'],
      'assets/images/workout/routine_builder.webp',
    ),
    RoutineExample(
      'strength_core',
      'Ejemplo · Fuerza y zona media',
      'Estructura con bisagra, tracción y una serie por tiempo. Sin cargas asignadas.',
      ['romanian_deadlift', 'lat_pulldown', 'plank'],
      'assets/images/workout/equipment_detail.webp',
    ),
  ];
  static TrainingProgram programStructure(
    WorkoutTemplate routine, {
    required int daysPerWeek,
  }) {
    if (routine.exercises.isEmpty ||
        routine.exercises.any((e) => RoutinePlanValidation.error(e) != null)) {
      throw ArgumentError('Revisá primero los objetivos de la rutina elegida.');
    }
    final trainingDays = switch (daysPerWeek) {
      3 => const {1, 3, 5},
      4 => const {1, 2, 4, 5},
      _ => throw ArgumentError('Estructura no disponible'),
    };
    return TrainingProgram(
      id: const Uuid().v4(),
      name: 'Ejemplo · $daysPerWeek días por semana',
      description: 'Estructura editable de organización. No prescribe resultados ni progresión de cargas.',
      goal: 'Organizar entrenamientos y descansos',
      level: 'Personalizable',
      weeks: 4,
      equipment: routine.exercises
          .map((e) => e.equipment)
          .whereType<String>()
          .map(RoutineLabels.equipmentName)
          .toSet()
          .toList(),
      days: [
        for (var week = 0; week < 4; week++)
          for (var day = 1; day <= 7; day++)
            ProgramDay(
              id: const Uuid().v4(),
              week: week,
              weekday: day,
              routineId: trainingDays.contains(day) ? routine.id : null,
              rest: !trainingDays.contains(day),
            ),
      ],
    );
  }
}
