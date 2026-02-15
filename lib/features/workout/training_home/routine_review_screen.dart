import 'package:flutter/material.dart';

import '../pro/data/exercise_definition.dart' as def;
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
  final Map<String, def.ExerciseDefinition> exercisesById;
  final RoutinesRepository repository;

  @override
  State<RoutineReviewScreen> createState() => _RoutineReviewScreenState();
}

class _RoutineReviewScreenState extends State<RoutineReviewScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _notesController = TextEditingController();
  final Map<String, WorkoutExercise> _exerciseConfigs = <String, WorkoutExercise>{};

  bool get _canSave => _nameController.text.trim().isNotEmpty && widget.draftController.selectedExerciseIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(() => setState(() {}));
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
                onPressed: _canSave ? _saveRoutine : null,
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
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la rutina',
                    hintText: 'Nombre de la rutina',
                    errorText: _nameController.text.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Notas (opcional)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ejercicios (${selected.length})',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    itemCount: selected.length,
                    onReorder: widget.draftController.reorder,
                    itemBuilder: (context, index) {
                      final id = selected[index];
                      final exercise = widget.exercisesById[id];
                      final configured = _configFor(id, exercise);
                      return Card(
                        key: ValueKey(id),
                        child: ListTile(
                          onTap: () => _openConfigSheet(id, exercise),
                          title: Text(
                            exercise?.name ?? id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _subtitle(exercise),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _summaryChip('Sets ${configured.targetSets}'),
                                  _summaryChip(_repsSummary(configured)),
                                  _summaryChip(_loadSummary(configured)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_handle),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _exerciseConfigs.remove(id);
                                  });
                                  widget.draftController.removeExercise(id);
                                },
                              ),
                            ],
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

  Widget _summaryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }

  String _subtitle(def.ExerciseDefinition? exercise) {
    if (exercise == null) return 'Sin detalles';
    final muscle = exercise.primaryMuscles.isEmpty ? 'Sin músculo' : exercise.primaryMuscles.first;
    return '$muscle · ${exercise.equipment}';
  }

  WorkoutExercise _configFor(String id, def.ExerciseDefinition? exercise) {
    return _exerciseConfigs.putIfAbsent(
      id,
      () => WorkoutExercise(
        id: id,
        name: exercise?.name ?? id,
        muscleGroup: exercise?.primaryMuscles.isEmpty ?? true ? null : exercise!.primaryMuscles.first,
        equipment: exercise?.equipment,
        measurement: exercise?.defaultMeasurement,
        targetLoadType: _inferLoadType(exercise),
      ),
    );
  }

  RoutineExerciseLoadType _inferLoadType(def.ExerciseDefinition? exercise) {
    if (exercise == null) return RoutineExerciseLoadType.bodyweight;
    switch (exercise.loadType) {
      case def.LoadType.assisted_bodyweight:
        return RoutineExerciseLoadType.assistedKg;
      case def.LoadType.external:
      case def.LoadType.bodyweight_plus_external:
        return exercise.equipment.toLowerCase().contains('machine') ||
                exercise.equipment.toLowerCase().contains('máquina')
            ? RoutineExerciseLoadType.machineKg
            : RoutineExerciseLoadType.weightedKg;
      case def.LoadType.bodyweight_effective:
        return RoutineExerciseLoadType.bodyweight;
    }
  }

  String _repsSummary(WorkoutExercise exercise) {
    if (exercise.targetReps != null) {
      return 'Reps ${exercise.targetReps}';
    }
    return 'Reps ${exercise.targetRepsMin ?? 8}-${exercise.targetRepsMax ?? 12}';
  }

  String _loadSummary(WorkoutExercise exercise) {
    final weightText = exercise.targetWeightKg == null ? null : '${exercise.targetWeightKg!.toStringAsFixed(1)} kg';
    switch (exercise.targetLoadType) {
      case RoutineExerciseLoadType.bodyweight:
        return weightText == null ? 'BW' : 'BW + $weightText';
      case RoutineExerciseLoadType.weightedKg:
        return weightText == null ? 'Peso —' : weightText;
      case RoutineExerciseLoadType.assistedKg:
        return weightText == null ? 'Asistido —' : 'Asistido -$weightText';
      case RoutineExerciseLoadType.machineKg:
        return weightText == null ? 'Máquina —' : 'Máquina $weightText';
    }
  }

  Future<void> _openConfigSheet(String id, def.ExerciseDefinition? exercise) async {
    final current = _configFor(id, exercise);
    final updated = await showModalBottomSheet<WorkoutExercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ExerciseConfigSheet(initial: current),
    );
    if (updated == null) return;
    setState(() {
      _exerciseConfigs[id] = updated;
    });
  }

  Future<void> _saveRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresá un nombre para la rutina')));
      return;
    }
    final notes = _notesController.text.trim();
    final exercises = widget.draftController.selectedExerciseIds
        .map((id) => _configFor(id, widget.exercisesById[id]))
        .map((e) => e.copyWith(notes: notes.isEmpty ? null : notes))
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

class _ExerciseConfigSheet extends StatefulWidget {
  const _ExerciseConfigSheet({required this.initial});

  final WorkoutExercise initial;

  @override
  State<_ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<_ExerciseConfigSheet> {
  late int _sets;
  late bool _fixedReps;
  late int _reps;
  late int _repsMin;
  late int _repsMax;
  late RoutineExerciseLoadType _loadType;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _sets = widget.initial.targetSets;
    _fixedReps = widget.initial.targetReps != null;
    _reps = widget.initial.targetReps ?? 10;
    _repsMin = widget.initial.targetRepsMin ?? 8;
    _repsMax = widget.initial.targetRepsMax ?? 12;
    _loadType = widget.initial.targetLoadType;
    _weightController = TextEditingController(
      text: widget.initial.targetWeightKg == null ? '' : widget.initial.targetWeightKg!.toStringAsFixed(1),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Configurar ejercicio', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Sets', style: Theme.of(context).textTheme.titleSmall),
              Row(
                children: [
                  IconButton(
                    onPressed: _sets > 1 ? () => setState(() => _sets--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text('$_sets', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    onPressed: _sets < 20 ? () => setState(() => _sets++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Reps', style: Theme.of(context).textTheme.titleSmall),
              RadioListTile<bool>(
                value: true,
                groupValue: _fixedReps,
                onChanged: (value) => setState(() => _fixedReps = value ?? true),
                title: const Text('Fijas'),
              ),
              if (_fixedReps)
                TextFormField(
                  initialValue: '$_reps',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (value) => _reps = int.tryParse(value) ?? _reps,
                ),
              RadioListTile<bool>(
                value: false,
                groupValue: _fixedReps,
                onChanged: (value) => setState(() => _fixedReps = value ?? false),
                title: const Text('Rango'),
              ),
              if (!_fixedReps)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_repsMin',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Mínimo'),
                        onChanged: (value) => _repsMin = int.tryParse(value) ?? _repsMin,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_repsMax',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Máximo'),
                        onChanged: (value) => _repsMax = int.tryParse(value) ?? _repsMax,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              Text('Tipo de carga', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: RoutineExerciseLoadType.values
                    .map(
                      (type) => ChoiceChip(
                        selected: type == _loadType,
                        label: Text(_loadTypeLabel(type)),
                        onSelected: (_) => setState(() => _loadType = type),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _loadType == RoutineExerciseLoadType.bodyweight
                      ? 'Peso adicional opcional (kg)'
                      : 'Peso objetivo (kg)',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _loadTypeLabel(RoutineExerciseLoadType type) {
    switch (type) {
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

  void _save() {
    final min = _repsMin <= _repsMax ? _repsMin : _repsMax;
    final max = _repsMax >= _repsMin ? _repsMax : _repsMin;
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    Navigator.of(context).pop(
      WorkoutExercise(
        id: widget.initial.id,
        name: widget.initial.name,
        muscleGroup: widget.initial.muscleGroup,
        equipment: widget.initial.equipment,
        measurement: widget.initial.measurement,
        notes: widget.initial.notes,
        targetSets: _sets,
        targetReps: _fixedReps ? _reps : null,
        targetRepsMin: _fixedReps ? null : min,
        targetRepsMax: _fixedReps ? null : max,
        targetLoadType: _loadType,
        targetWeightKg: weight,
        restSeconds: widget.initial.restSeconds,
        rir: widget.initial.rir,
        sets: widget.initial.sets,
      ),
    );
  }
}
