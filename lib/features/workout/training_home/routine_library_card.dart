import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/routine_labels.dart';
import '../domain/sport_activity.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
import '../presentation/widgets/exercise_thumbnail.dart';

class RoutineLibraryCard extends StatelessWidget {
  const RoutineLibraryCard({
    super.key,
    required this.routine,
    required this.lastUsed,
    required this.onOpen,
    required this.onStart,
    required this.onMenu,
    this.pinned = false,
  });
  final WorkoutTemplate routine;
  final bool pinned;
  final String lastUsed;
  final VoidCallback onOpen, onStart;
  final ValueChanged<String> onMenu;
  static String type(WorkoutTemplate routine) => routine.footballMode != null
      ? 'Fútbol · ${routine.footballMode!.label}'
      : switch (routine.type) {
          WorkoutType.strength => 'Gimnasio',
          WorkoutType.sport => 'Deporte',
          WorkoutType.cardio => 'Cardio',
          WorkoutType.functional => 'Funcional',
          WorkoutType.custom => routine.activityName ?? 'Personalizada',
        };
  static String focus(WorkoutTemplate routine) => routine.footballMode != null
      ? routine.footballMode!.label
      : routine.exercises
            .expand(
              (e) =>
                  WorkoutAnalytics.definition(e)?.primaryMuscles ??
                  [if (e.muscleGroup != null) e.muscleGroup!],
            )
            .toSet()
            .take(3)
            .join(' · ');
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workout,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (routine.exercises.isNotEmpty)
                  ExerciseThumbnail(exercise: routine.exercises.first),
                const SizedBox(width: 12),
                if (!_large(context)) Expanded(child: _heading(context)),
                if (_large(context)) const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de ${routine.name}',
                  onSelected: onMenu,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: "pin",
                      child: Text(pinned ? "Desfijar" : "Fijar"),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Text('Duplicar'),
                    ),
                    const PopupMenuItem(
                      value: 'move',
                      child: Text('Mover a carpeta'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_large(context)) _heading(context),
            Text(
              '${routine.exercises.length} ${routine.footballMode != null && routine.footballMode != FootballMode.gym ? 'actividades' : 'ejercicios'} · ${routine.exercises.fold(0, (n, e) => n + e.targetSets)} series',
            ),
            Text(lastUsed),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: routine.exercises
                  .take(3)
                  .map((e) => Text(RoutineLabels.exerciseName(e.name)))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _large(context) ? 'Iniciar' : 'Iniciar entrenamiento',
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onOpen,
                child: const Text('Ver rutina'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  bool _large(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) > 24;
  Widget _heading(BuildContext context) => InkWell(
    onTap: onOpen,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(routine.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(type(routine)),
        if (focus(routine).isNotEmpty) Text(focus(routine)),
      ],
    ),
  );
}
