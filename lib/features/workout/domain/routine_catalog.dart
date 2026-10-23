import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';
import 'routine_labels.dart';

enum RoutineLevel {
  basic(
    'Básico',
    'Para empezar o retomar con movimientos sencillos y menos series.',
  ),
  intermediate(
    'Intermedio',
    'Para quienes ya controlan los movimientos y entrenan con regularidad.',
  ),
  advanced(
    'Avanzado',
    'Para personas con experiencia en los ejercicios y en la gestión de cargas y descansos.',
  );

  const RoutineLevel(this.label, this.description);
  final String label, description;
}

/// Editorial starting points, independent of saved routines and training results.
/// Targets are editable; personal loads and completed sets are never seeded.
class CatalogRoutine {
  const CatalogRoutine(
    this.id,
    this.name,
    this.level,
    this.goal,
    this.description,
    this.exerciseIds,
    this.imageAsset, {
    this.sets = 3,
    this.minReps = 8,
    this.maxReps = 12,
    this.restSeconds = 90,
    this.timedSeconds = 30,
  });
  final String id, name, goal, description, imageAsset;
  final RoutineLevel level;
  final List<String> exerciseIds;
  final int sets, minReps, maxReps, restSeconds, timedSeconds;

  List<WorkoutExercise> get plan => [
    for (final id in exerciseIds)
      RoutineLabels.defaults(exerciseLibrary.firstWhere((e) => e.id == id))
          .copyWith(
            targetSets: sets,
            targetRepsMin: minReps,
            targetRepsMax: maxReps,
            restSeconds: restSeconds,
            restEnabled: true,
            targetDurationSeconds:
                exerciseLibrary.firstWhere((e) => e.id == id).isTimed
                ? timedSeconds
                : null,
          ),
  ];
  List<String> get equipment => plan
      .map((e) => RoutineLabels.equipmentName(e.equipment))
      .toSet()
      .toList();
  int get totalSets => sets * exerciseIds.length;
  WorkoutTemplate template() => WorkoutTemplate(
    id: 'catalog-$id',
    name: name,
    type: WorkoutType.strength,
    origin: TemplateOrigin.standard,
    exercises: plan,
    notes:
        '$description\nNivel ${level.label.toLowerCase()} · $goal. Objetivos orientativos y editables. Elegí una carga que puedas controlar; no se asignan pesos. En ejercicios unilaterales, completá ambos lados por serie.',
  );
}

abstract final class RoutineCatalog {
  static const routines = <CatalogRoutine>[
    CatalogRoutine(
      'gym_start',
      'Primeros pasos en el gym',
      RoutineLevel.basic,
      'Cuerpo completo',
      'Una sesión con máquinas, polea y zona media para familiarizarte con el gimnasio.',
      [
        'leg_press',
        'chest_press_machine',
        'seated_row',
        'seated_leg_curl',
        'plank',
      ],
      'assets/images/workout/catalog_basic.webp',
      sets: 2,
      minReps: 10,
      maxReps: 12,
      timedSeconds: 20,
    ),
    CatalogRoutine(
      'dumbbell_start',
      'Cuerpo completo con mancuernas',
      RoutineLevel.basic,
      'Fuerza general',
      'Una base de piernas, empuje y tracción con mancuernas y banco. Practicá el recorrido antes de subir la carga.',
      [
        'dumbbell_box_squat',
        'dumbbell_press',
        'single_arm_db_row',
        'glute_bridge',
        'dead_bug',
      ],
      'assets/images/workout/catalog_dumbbells.webp',
      sets: 2,
      timedSeconds: 20,
    ),
    CatalogRoutine(
      'home_start',
      'Empezá en casa',
      RoutineLevel.basic,
      'Peso corporal',
      'Movimientos de peso corporal con un apoyo firme para las flexiones inclinadas y una colchoneta.',
      ['incline_push_up', 'glute_bridge', 'bird_dog', 'dead_bug', 'plank'],
      'assets/images/workout/catalog_home.webp',
      sets: 2,
      minReps: 8,
      maxReps: 10,
      restSeconds: 60,
      timedSeconds: 20,
    ),
    CatalogRoutine(
      'core_start',
      'Zona media esencial',
      RoutineLevel.basic,
      'Control y estabilidad',
      'Una sesión breve centrada en el control del tronco. Reducí el tiempo si perdés la posición.',
      ['dead_bug', 'bird_dog', 'plank', 'glute_bridge'],
      'assets/images/workout/catalog_core.webp',
      sets: 2,
      minReps: 8,
      maxReps: 10,
      restSeconds: 60,
      timedSeconds: 20,
    ),
    CatalogRoutine(
      'upper',
      'Torso equilibrado',
      RoutineLevel.intermediate,
      'Fuerza de torso',
      'Empujes y tracciones para pecho, espalda y hombros. Separá esta sesión de otras de torso según tu recuperación.',
      [
        'bench_press',
        'lat_pulldown',
        'seated_row',
        'military_press',
        'lateral_raise',
      ],
      'assets/images/workout/catalog_intermediate.webp',
      restSeconds: 120,
    ),
    CatalogRoutine(
      'lower',
      'Piernas y zona media',
      RoutineLevel.intermediate,
      'Tren inferior',
      'Sentadilla, bisagra de cadera y accesorios de piernas con trabajo de estabilidad al final.',
      [
        'back_squat',
        'romanian_deadlift',
        'seated_leg_curl',
        'standing_calf_raise',
        'pallof_press',
      ],
      'assets/images/workout/catalog_legs.webp',
      restSeconds: 120,
    ),
    CatalogRoutine(
      'push',
      'Empuje: pecho, hombros y tríceps',
      RoutineLevel.intermediate,
      'Desarrollo muscular',
      'Un día de empuje para combinar con sesiones de tracción y piernas, sin repetir todo el reparto cada día.',
      [
        'dumbbell_press',
        'incline_bench_press',
        'military_press',
        'lateral_raise',
        'triceps_pushdown',
      ],
      'assets/images/workout/catalog_push.webp',
      restSeconds: 120,
    ),
    CatalogRoutine(
      'pull',
      'Tracción: espalda y bíceps',
      RoutineLevel.intermediate,
      'Desarrollo muscular',
      'Tracciones verticales y horizontales con accesorios de hombro posterior y brazos.',
      [
        'lat_pulldown',
        'barbell_row',
        'chest_supported_row',
        'face_pull',
        'hammer_curl',
      ],
      'assets/images/workout/catalog_pull.webp',
      restSeconds: 120,
    ),
    CatalogRoutine(
      'upper_advanced',
      'Torso: volumen y control',
      RoutineLevel.advanced,
      'Desarrollo muscular',
      'Más series y movimientos libres para un reparto de torso con experiencia previa. Ajustá el volumen a tu semana.',
      [
        'bench_press',
        'pull_up',
        'military_press',
        'barbell_row',
        'cable_fly',
        'dumbbell_curl',
      ],
      'assets/images/workout/routine_builder.webp',
      sets: 4,
      minReps: 6,
      maxReps: 10,
      restSeconds: 150,
    ),
    CatalogRoutine(
      'lower_advanced',
      'Piernas: fuerza y unilateral',
      RoutineLevel.advanced,
      'Fuerza de piernas',
      'Sentadilla frontal, bisagra y trabajo unilateral. Requiere dominio de cada movimiento; completá ambos lados.',
      [
        'front_squat',
        'romanian_deadlift',
        'bulgarian_split_squat',
        'lying_leg_curl',
        'seated_calf_raise',
      ],
      'assets/images/workout/session_strength.webp',
      sets: 4,
      minReps: 6,
      maxReps: 10,
      restSeconds: 150,
    ),
    CatalogRoutine(
      'strength_advanced',
      'Fuerza con básicos',
      RoutineLevel.advanced,
      'Fuerza general',
      'Cuatro movimientos compuestos con menos repeticiones y descansos largos. Elegí cargas controlables sin buscar máximos.',
      ['back_squat', 'bench_press', 'deadlift', 'pull_up'],
      'assets/images/workout/catalog_advanced.webp',
      sets: 3,
      minReps: 4,
      maxReps: 6,
      restSeconds: 180,
    ),
    CatalogRoutine(
      'posterior_advanced',
      'Cadena posterior y espalda',
      RoutineLevel.advanced,
      'Fuerza posterior',
      'Trabajo de cadera, espalda y hombro posterior. Ubicá la sesión con descanso suficiente de otros días de piernas.',
      [
        'deadlift',
        'hip_thrust',
        'chest_supported_row',
        'lying_leg_curl',
        'rear_delt_fly',
        'plank',
      ],
      'assets/images/workout/equipment_detail.webp',
      minReps: 6,
      maxReps: 10,
      restSeconds: 150,
    ),
  ];

  static List<CatalogRoutine> search(String query, {RoutineLevel? level}) {
    final terms = foldRoutineSearch(query).trim().split(RegExp(r'\s+'));
    return routines
        .where((r) {
          if (level != null && r.level != level) return false;
          final text = foldRoutineSearch(
            '${r.name} ${r.goal} ${r.description} ${r.level.label} ${r.equipment.join(' ')} ${r.plan.map((e) => '${RoutineLabels.exerciseName(e.name)} ${e.muscleGroup ?? ''}').join(' ')}',
          );
          return terms.every(text.contains);
        })
        .toList(growable: false);
  }
}

String foldRoutineSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n');
