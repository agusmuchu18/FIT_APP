import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../pro/models/workout_models.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';

class RoutinePreviewScreen extends StatefulWidget {
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
  State<RoutinePreviewScreen> createState() => _RoutinePreviewScreenState();
}

class _RoutinePreviewScreenState extends State<RoutinePreviewScreen> {
  String? _expandedId;

  @override
  Widget build(BuildContext context) {
    final estimatedMinutes = widget.controller.estimatedDuration(widget.routine);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routine.name),
        actions: [
          TextButton(
            onPressed: _editRoutineName,
            child: const Text('Editar rutina'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text(widget.routine.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(widget.typeLabel)),
              if (widget.routine.activityName != null && widget.routine.activityName!.trim().isNotEmpty) Chip(label: Text(widget.routine.activityName!)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${widget.routine.exercises.length} ejercicios${estimatedMinutes != null ? ' · ~$estimatedMinutes min' : ''} · Última vez: ${widget.lastUsedLabel}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 18),
          Text('Ejercicios', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          if (widget.routine.exercises.isEmpty)
            Text('Esta rutina no tiene ejercicios todavía.', style: Theme.of(context).textTheme.bodyMedium)
          else
            ...widget.routine.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              final expanded = _expandedId == exercise.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    ListTile(
                      onTap: () => setState(() => _expandedId = expanded ? null : exercise.id),
                      leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
                      title: Text(exercise.name),
                      subtitle: Text(_exerciseSummary(exercise)),
                      trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      child: expanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Sets: ${exercise.targetSets}'),
                                  Text('Reps: ${exercise.targetReps != null ? exercise.targetReps : '${exercise.targetRepsMin ?? 8}-${exercise.targetRepsMax ?? 12}'}'),
                                  Text('Carga: ${_loadLabel(exercise)}'),
                                  if (exercise.targetWeightKg != null) Text('Peso objetivo: ${exercise.targetWeightKg!.toStringAsFixed(1)} kg'),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    )
                  ],
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: () => startRoutineFlow(context, widget.controller, widget.routine),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('Iniciar rutina'),
        ),
      ),
    );
  }

  Future<void> _editRoutineName() async {
    final c = TextEditingController(text: widget.routine.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar rutina'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await widget.controller.renameRoutine(widget.routine, name);
      if (mounted) Navigator.pop(context);
    }
  }

  String _exerciseSummary(WorkoutExercise exercise) {
    return '${exercise.targetSets} series · ${exercise.targetReps != null ? '${exercise.targetReps} reps' : '${exercise.targetRepsMin ?? 8}-${exercise.targetRepsMax ?? 12} reps'}';
  }

  String _loadLabel(WorkoutExercise exercise) {
    switch (exercise.targetLoadType) {
      case RoutineExerciseLoadType.bodyweight:
        return 'Bodyweight';
      case RoutineExerciseLoadType.weightedKg:
        return 'Weighted';
      case RoutineExerciseLoadType.assistedKg:
        return 'Assisted';
      case RoutineExerciseLoadType.machineKg:
        return 'Machine';
    }
  }
}
