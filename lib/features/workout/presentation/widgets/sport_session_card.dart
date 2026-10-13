import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import '../../domain/sport_activity.dart';
import 'sport_measurements_fields.dart';
import 'exercise_thumbnail.dart';
import '../../pro/models/workout_models.dart';
import 'workout_rest_selector.dart';

class SportSessionCard extends StatelessWidget {
  const SportSessionCard({
    super.key,
    required this.exercise,
    required this.onChanged,
    required this.onDone,
    required this.onRest,
    required this.onRemove,
  });
  final ExerciseInSession exercise;
  final ValueChanged<SportMeasurements?> onChanged;
  final ValueChanged<bool> onDone;
  final void Function(bool enabled, int seconds) onRest;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final plan = exercise.sportPlan!;
    final activity = footballActivities
        .where((e) => e.id == plan.activityId)
        .firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExerciseThumbnail(
                  exercise:
                      exercise.plan ??
                      WorkoutExercise(
                        id: exercise.exerciseId,
                        name: exercise.name,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Eliminar actividad',
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text('Fútbol · ${plan.mode.label}'),
            if (plan.objective.isNotEmpty) Text('Objetivo: ${plan.objective}'),
            for (final e in plan.targets.values.entries)
              Text('Objetivo · ${e.key.label}: ${e.value}'),
            const SizedBox(height: 16),
            Text(
              'Resultados realizados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (activity != null)
              SportMeasurementsFields(
                activity: activity,
                initial: exercise.sportResult ?? SportMeasurements(),
                onChanged: onChanged,
              ),
            const SizedBox(height: 16),
            WorkoutRestSelector(
              enabled: exercise.restEnabled,
              seconds: exercise.restSeconds ?? 90,
              onToggle: (v) => onRest(v, exercise.restSeconds ?? 90),
              onChanged: (v) => onRest(exercise.restEnabled, v),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actividad completada'),
              subtitle: Text(
                plan.resultValid(exercise.sportResult)
                    ? 'Resultados listos para registrar'
                    : 'Registrá tiempo positivo y los parámetros de la actividad.',
              ),
              value: exercise.sets.every((s) => s.done),
              onChanged:
                  plan.resultValid(exercise.sportResult) ||
                      exercise.sets.any((s) => s.done)
                  ? (v) => onDone(v ?? false)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
