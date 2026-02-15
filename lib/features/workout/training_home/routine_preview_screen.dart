import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../pro/models/workout_models.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';

class RoutinePreviewScreen extends StatelessWidget {
  const RoutinePreviewScreen({
    super.key,
    required this.routine,
    required this.controller,
    required this.typeLabel,
    required this.lastUsedLabel,
  });

  final WorkoutTemplate routine;
  final TrainingHomeController controller;
  final String typeLabel;
  final String lastUsedLabel;

  @override
  Widget build(BuildContext context) {
    final estimatedMinutes = controller.estimatedDuration(routine);

    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text(
            routine.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(typeLabel)),
              if (routine.activityName != null && routine.activityName!.trim().isNotEmpty)
                Chip(label: Text(routine.activityName!)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${routine.exercises.length} ejercicios${estimatedMinutes != null ? ' · ~$estimatedMinutes min' : ''} · Última vez: $lastUsedLabel',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          Text('Ejercicios', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (routine.exercises.isEmpty)
            Text('Esta rutina no tiene ejercicios todavía.', style: Theme.of(context).textTheme.bodyMedium)
          else
            ...routine.exercises.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(exercise.name),
                    subtitle: Text(_exerciseDetails(exercise)),
                  ),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: () => startRoutineFlow(context, controller, routine),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          child: const Text('Iniciar rutina'),
        ),
      ),
    );
  }

  String _exerciseDetails(WorkoutExercise exercise) {
    if (exercise.sets.isEmpty) return 'Sin series configuradas';
    final withReps = exercise.sets.where((set) => set.reps != null).toList(growable: false);
    if (withReps.isNotEmpty) {
      final avgReps = withReps.map((set) => set.reps!).reduce((a, b) => a + b) ~/ withReps.length;
      return '${exercise.sets.length} series x ~${avgReps} reps';
    }
    return '${exercise.sets.length} series';
  }
}
