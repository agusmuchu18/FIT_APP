import 'package:flutter/material.dart';

import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import 'routine_draft_controller.dart';
import 'routines_repository.dart';
import 'template_workout_type.dart';

class RoutineReviewScreen extends StatefulWidget {
  const RoutineReviewScreen({
    super.key,
    required this.draftController,
    required this.exercisesById,
    required this.repository,
  });

  final RoutineDraftController draftController;
  final Map<String, ExerciseDefinition> exercisesById;
  final RoutinesRepository repository;

  @override
  State<RoutineReviewScreen> createState() => _RoutineReviewScreenState();
}

class _RoutineReviewScreenState extends State<RoutineReviewScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Rutina ${typeLabel(widget.draftController.workoutType)}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.draftController,
      builder: (context, _) {
        final selected = widget.draftController.selectedExerciseIds;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nueva rutina'),
            actions: [
              TextButton(
                onPressed: selected.isEmpty ? null : _saveRoutine,
                child: const Text('Guardar'),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Nombre de la rutina'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Notas (opcional)'),
                ),
                const SizedBox(height: 10),
                Chip(label: Text(typeLabel(widget.draftController.workoutType))),
                const SizedBox(height: 12),
                Text('Ejercicios (${selected.length})', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: selected.length,
                    onReorder: widget.draftController.reorder,
                    itemBuilder: (context, index) {
                      final id = selected[index];
                      final exercise = widget.exercisesById[id];
                      return Card(
                        key: ValueKey(id),
                        child: ListTile(
                          title: Text(exercise?.name ?? id),
                          subtitle: Text(_subtitle(exercise)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => widget.draftController.removeExercise(id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(ExerciseDefinition? exercise) {
    if (exercise == null) return 'Sin detalles';
    final muscle = exercise.primaryMuscles.isEmpty ? 'Sin músculo' : exercise.primaryMuscles.first;
    return '$muscle · ${exercise.equipment}';
  }

  Future<void> _saveRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresá un nombre para la rutina')));
      return;
    }
    final exercises = widget.draftController.selectedExerciseIds
        .map((id) => widget.exercisesById[id])
        .whereType<ExerciseDefinition>()
        .map(
          (e) => WorkoutExercise(
            id: e.id,
            name: e.name,
            muscleGroup: e.primaryMuscles.isEmpty ? null : e.primaryMuscles.first,
            measurement: e.defaultMeasurement,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            sets: const [],
          ),
        )
        .toList();

    await widget.repository.saveRoutine(
      name: name,
      workoutType: toWorkoutType(widget.draftController.workoutType),
      exercises: exercises,
      activityName: typeLabel(widget.draftController.workoutType),
    );
    if (!mounted) return;
    widget.draftController.clear();
    Navigator.of(context).pop(true);
  }
}
