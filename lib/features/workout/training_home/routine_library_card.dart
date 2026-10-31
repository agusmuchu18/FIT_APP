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
  Widget build(BuildContext context) {
    final large = _large(context);
    final names = routine.exercises
        .map((e) => RoutineLabels.exerciseName(e.name))
        .join(' · ');
    final summary = [
      '${routine.exercises.length} ${routine.footballMode != null && routine.footballMode != FootballMode.gym ? 'actividades' : 'ejercicios'}',
      '${routine.exercises.fold(0, (n, e) => n + e.targetSets)} series',
      lastUsed,
    ].join(' · ');
    return Theme(
      data: AppTheme.workoutFor(Theme.of(context)),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (routine.exercises.isNotEmpty)
                      ExerciseThumbnail(exercise: routine.exercises.first),
                    const SizedBox(width: 12),
                    if (!large) Expanded(child: _heading(context)),
                    if (large) const Spacer(),
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
                if (large) _heading(context),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (names.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          names,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onStart,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            large ? 'Iniciar' : 'Iniciar entrenamiento',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _large(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(16) > 24;
  Widget _heading(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(routine.name, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 2),
      Text(
        [type(routine), if (focus(routine).isNotEmpty) focus(routine)]
            .join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
