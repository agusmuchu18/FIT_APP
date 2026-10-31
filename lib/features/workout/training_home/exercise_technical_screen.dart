import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

import '../data/workout_repository.dart';
import '../data/training_library_repository.dart';
import 'exercise_progress_panel.dart';
import '../domain/exercise_technique.dart';
import '../domain/routine_labels.dart';
import '../domain/workout_analytics.dart';
import '../domain/sport_activity.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';

class _TechniqueTab extends StatelessWidget {
  const _TechniqueTab({required this.exercise, this.definition});
  final WorkoutExercise exercise;
  final ExerciseDefinition? definition;

  @override
  Widget build(BuildContext context) {
    final d = definition;
    final technique = exerciseTechniques[exercise.id];
    final activity = footballActivities
        .where((a) => a.id == exercise.sportPlan?.activityId)
        .firstOrNull;
    Widget section(String title, List<String> lines) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final text in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(text),
            ),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: ExerciseThumbnail(exercise: exercise, size: 240)),
        if (!ExerciseArtRegistry.specific.contains(exercise.id))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ilustración genérica de categoría'),
          ),
        const SizedBox(height: 20),
        Text(
          RoutineLabels.exerciseName(exercise.name),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        section('Descripción', [
          activity?.description ??
              technique?.summary ??
              'Ejercicio del catálogo de ${RoutineLabels.equipmentName(exercise.equipment).toLowerCase()}. No hay una descripción técnica ampliada revisada disponible.',
        ]),
        if (d != null) ...[
          section('Músculos', [
            'Principales: ${RoutineLabels.muscles(d.primaryMuscles)}',
            'Secundarios: ${RoutineLabels.muscles(d.secondaryMuscles)}',
          ]),
          section('Información del catálogo', [
            '${d.equipment == 'carry' ? 'Clasificación heredada' : 'Equipamiento'}: ${RoutineLabels.equipmentName(d.equipment)}',
            'Patrón de movimiento: ${RoutineLabels.pattern(d.movementPattern)}',
            'Registro: ${d.isTimed ? 'Tiempo' : 'Repeticiones'}',
            if (d.isUnilateral) 'Movimiento unilateral',
            if (d.aliases.isNotEmpty)
              'También conocido como: ${d.aliases.join(', ')}',
          ]),
        ],
        if (WorkoutAnalytics.isBodyweight(exercise))
          section('Cómo registrar', [
            'Solo peso corporal: ${d?.isTimed == true || exercise.isTimed ? 'tiempo' : 'repeticiones'}, sin kilos obligatorios.',
            'Lastre y asistencia se eligen de forma opcional, incluso para una sola serie.',
            'El volumen externo cuenta solo el lastre registrado y sus repeticiones; no suma el peso corporal ni la asistencia.',
          ]),
        section(
          'Instrucciones de ejecución',
          technique?.steps ??
              ['Sin instrucciones técnicas revisadas en el catálogo.'],
        ),
        section(
          'Errores frecuentes',
          technique?.errors ?? ['Sin datos revisados disponibles.'],
        ),
        section(
          'Consejos técnicos',
          technique?.tips ?? ['Sin consejos técnicos revisados disponibles.'],
        ),
        section('Variantes', const [
          'El catálogo no incluye relaciones de variantes verificadas para este ejercicio.',
        ]),
        if (technique != null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Notas orientativas del catálogo; la ficha técnica ampliada sigue pendiente de revisión profesional.',
            ),
          ),
      ],
    );
  }
}

class ExerciseTechnicalScreen extends StatelessWidget {
  const ExerciseTechnicalScreen({
    super.key,
    required this.exercise,
    this.definition,
    this.repository,
    this.library,
  });
  final WorkoutExercise exercise;
  final ExerciseDefinition? definition;
  final WorkoutRepository? repository;
  final TrainingLibraryRepository? library;
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ficha del ejercicio'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Historial'),
              Tab(text: 'Técnica'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ExerciseProgressPanel(
              exercise: exercise,
              historyOnly: false,
              repository: repository,
              library: library,
            ),
            ExerciseProgressPanel(
              exercise: exercise,
              historyOnly: true,
              repository: repository,
              library: library,
            ),
            _TechniqueTab(exercise: exercise, definition: definition),
          ],
        ),
      ),
    ),
  );
}
