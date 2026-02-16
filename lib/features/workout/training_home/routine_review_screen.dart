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
  String? _expandedExerciseId;

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
        if (_expandedExerciseId != null && !selected.contains(_expandedExerciseId)) {
          _expandedExerciseId = null;
        }
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
                      final expanded = _expandedExerciseId == id;
                      return Card(
                        key: ValueKey(id),
                        child: Column(
                          children: [
                            ListTile(
                              onTap: () => setState(() => _expandedExerciseId = expanded ? null : id),
                              title: Text(exercise?.name ?? id, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _summaryChip('Sets ${configured.targetSets}'),
                                  _summaryChip(_repsSummary(configured)),
                                  _summaryChip(_loadSummary(configured)),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _exerciseConfigs.remove(id);
                                        if (_expandedExerciseId == id) _expandedExerciseId = null;
                                      });
                                      widget.draftController.removeExercise(id);
                                    },
                                  ),
                                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                                ],
                              ),
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeInOut,
                              child: expanded
                                  ? Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                      child: ExerciseConfigInline(
                                        config: configured,
                                        onChanged: (updated) => _updateExerciseConfig(id, updated),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
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

  void _updateExerciseConfig(String exerciseId, WorkoutExercise newConfig) {
    setState(() {
      _exerciseConfigs[exerciseId] = newConfig;
    });
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
        return exercise.equipment.toLowerCase().contains('machine') || exercise.equipment.toLowerCase().contains('máquina')
            ? RoutineExerciseLoadType.machineKg
            : RoutineExerciseLoadType.weightedKg;
      case def.LoadType.bodyweight_effective:
        return RoutineExerciseLoadType.bodyweight;
    }
  }

  String _repsSummary(WorkoutExercise exercise) {
    if (exercise.targetReps != null) return 'Reps ${exercise.targetReps}';
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

  Future<void> _saveRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
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

class ExerciseConfigInline extends StatefulWidget {
  const ExerciseConfigInline({super.key, required this.config, required this.onChanged});

  final WorkoutExercise config;
  final ValueChanged<WorkoutExercise> onChanged;

  @override
  State<ExerciseConfigInline> createState() => _ExerciseConfigInlineState();
}

class _ExerciseConfigInlineState extends State<ExerciseConfigInline> {
  late bool _fixedReps;
  late TextEditingController _repsController;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _fixedReps = widget.config.targetReps != null;
    _repsController = TextEditingController(text: '${widget.config.targetReps ?? 10}');
    _minController = TextEditingController(text: '${widget.config.targetRepsMin ?? 8}');
    _maxController = TextEditingController(text: '${widget.config.targetRepsMax ?? 12}');
    _weightController = TextEditingController(text: widget.config.targetWeightKg?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    _repsController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canWeight = widget.config.targetLoadType == RoutineExerciseLoadType.weightedKg ||
        widget.config.targetLoadType == RoutineExerciseLoadType.machineKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sets', style: Theme.of(context).textTheme.titleSmall),
        Row(
          children: [
            IconButton(
              onPressed: widget.config.targetSets > 1 ? () => _setSets(widget.config.targetSets - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${widget.config.targetSets}', style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              onPressed: widget.config.targetSets < 20 ? () => _setSets(widget.config.targetSets + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Fijas')),
            ButtonSegment(value: false, label: Text('Rango')),
          ],
          selected: {_fixedReps},
          onSelectionChanged: (v) {
            setState(() => _fixedReps = v.first);
            _emit();
          },
        ),
        const SizedBox(height: 8),
        if (_fixedReps)
          TextField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
            onChanged: (_) => _emit(),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mínimo'),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Máximo'),
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: RoutineExerciseLoadType.values
              .map((type) => ChoiceChip(
                    selected: type == widget.config.targetLoadType,
                    label: Text(_label(type)),
                    onSelected: (_) => _setLoadType(type),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _weightController,
          enabled: canWeight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Peso objetivo (kg)'),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }

  void _setSets(int sets) => widget.onChanged(widget.config.copyWith(targetSets: sets));

  void _setLoadType(RoutineExerciseLoadType type) {
    final clearWeight = type == RoutineExerciseLoadType.assistedKg || type == RoutineExerciseLoadType.bodyweight;
    if (clearWeight) _weightController.text = '';
    widget.onChanged(widget.config.copyWith(targetLoadType: type, targetWeightKg: clearWeight ? null : widget.config.targetWeightKg));
  }

  void _emit() {
    final fixed = int.tryParse(_repsController.text) ?? widget.config.targetReps ?? 10;
    final minRaw = int.tryParse(_minController.text) ?? widget.config.targetRepsMin ?? 8;
    final maxRaw = int.tryParse(_maxController.text) ?? widget.config.targetRepsMax ?? 12;
    final min = minRaw <= maxRaw ? minRaw : maxRaw;
    final max = maxRaw >= minRaw ? maxRaw : minRaw;
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final canWeight = widget.config.targetLoadType == RoutineExerciseLoadType.weightedKg ||
        widget.config.targetLoadType == RoutineExerciseLoadType.machineKg;
    widget.onChanged(widget.config.copyWith(
      targetReps: _fixedReps ? fixed : null,
      targetRepsMin: _fixedReps ? null : min,
      targetRepsMax: _fixedReps ? null : max,
      targetWeightKg: canWeight ? weight : null,
    ));
  }

  String _label(RoutineExerciseLoadType type) {
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
}
