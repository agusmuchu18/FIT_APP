import 'dart:collection';

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
  final List<_RoutineExerciseItem> _items = <_RoutineExerciseItem>[];
  int _itemSeed = 0;
  String? _expandedExerciseItemId;

  bool get _canSave => _nameController.text.trim().isNotEmpty && _items.isNotEmpty;

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
        _syncItems(widget.draftController.selectedExerciseIds);
        if (_expandedExerciseItemId != null && !_items.any((item) => item.instanceId == _expandedExerciseItemId)) {
          _expandedExerciseItemId = null;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nueva rutina'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: _canSave ? _saveRoutine : null,
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoutineHeaderFields(
                  nameController: _nameController,
                  notesController: _notesController,
                ),
                const SizedBox(height: 14),
                ExercisesSectionHeader(
                  count: _items.length,
                  onAddTap: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: _items.length,
                    proxyDecorator: (child, _, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (context, __) => Material(
                        color: Colors.transparent,
                        child: Transform.scale(
                          scale: Tween<double>(begin: 1, end: 1.01).evaluate(animation),
                          child: child,
                        ),
                      ),
                    ),
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        widget.draftController.reorder(oldIndex, newIndex);
                      });
                    },
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final exercise = widget.exercisesById[item.exerciseId];
                      final configured = _configFor(item.instanceId, item.exerciseId, exercise);
                      final expanded = _expandedExerciseItemId == item.instanceId;
                      return Padding(
                        key: ValueKey(item.instanceId),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ExerciseCard(
                          title: exercise?.name ?? item.exerciseId,
                          config: configured,
                          expanded: expanded,
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.drag_handle_rounded),
                            ),
                          ),
                          onTap: () => setState(() {
                            _expandedExerciseItemId = expanded ? null : item.instanceId;
                          }),
                          onChanged: (updated) => _updateExerciseConfig(item.instanceId, updated),
                          onDuplicate: () => _duplicateExercise(index),
                          onDelete: () => _deleteExercise(index),
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

  void _syncItems(List<String> selectedIds) {
    final queues = <String, Queue<_RoutineExerciseItem>>{};
    for (final item in _items) {
      (queues[item.exerciseId] ??= Queue<_RoutineExerciseItem>()).add(item);
    }

    final next = <_RoutineExerciseItem>[];
    for (final exerciseId in selectedIds) {
      final bucket = queues[exerciseId];
      if (bucket != null && bucket.isNotEmpty) {
        next.add(bucket.removeFirst());
      } else {
        next.add(_RoutineExerciseItem(instanceId: '${exerciseId}_inst_${_itemSeed++}', exerciseId: exerciseId));
      }
    }

    final validIds = next.map((e) => e.instanceId).toSet();
    _exerciseConfigs.removeWhere((key, _) => !validIds.contains(key));

    _items
      ..clear()
      ..addAll(next);
  }

  void _updateExerciseConfig(String itemId, WorkoutExercise newConfig) {
    setState(() {
      _exerciseConfigs[itemId] = newConfig;
    });
  }

  WorkoutExercise _configFor(String itemId, String exerciseId, def.ExerciseDefinition? exercise) {
    return _exerciseConfigs.putIfAbsent(
      itemId,
      () => WorkoutExercise(
        id: exerciseId,
        name: exercise?.name ?? exerciseId,
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

  void _duplicateExercise(int index) {
    final source = _items[index];
    final sourceConfig = _configFor(source.instanceId, source.exerciseId, widget.exercisesById[source.exerciseId]);
    widget.draftController.insertExerciseAt(index + 1, source.exerciseId);
    _syncItems(widget.draftController.selectedExerciseIds);
    final duplicated = _items[index + 1];
    setState(() {
      _exerciseConfigs[duplicated.instanceId] = sourceConfig.copyWith();
      _expandedExerciseItemId = duplicated.instanceId;
    });
  }

  void _deleteExercise(int index) {
    final removed = _items[index];
    widget.draftController.removeExerciseAt(index);
    setState(() {
      _exerciseConfigs.remove(removed.instanceId);
      if (_expandedExerciseItemId == removed.instanceId) {
        _expandedExerciseItemId = null;
      }
    });
  }

  Future<void> _saveRoutine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _items.isEmpty) return;
    final notes = _notesController.text.trim();
    final exercises = _items
        .map((item) => _configFor(item.instanceId, item.exerciseId, widget.exercisesById[item.exerciseId]))
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

class RoutineHeaderFields extends StatelessWidget {
  const RoutineHeaderFields({
    super.key,
    required this.nameController,
    required this.notesController,
  });

  final TextEditingController nameController;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: 'Nombre de la rutina',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Notas (opcional)',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

class ExercisesSectionHeader extends StatelessWidget {
  const ExercisesSectionHeader({super.key, required this.count, required this.onAddTap});

  final int count;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('Ejercicios ($count)', style: Theme.of(context).textTheme.titleMedium),
        ),
        FilledButton.icon(onPressed: onAddTap, icon: const Icon(Icons.add), label: const Text('Agregar')),
      ],
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.title,
    required this.config,
    required this.expanded,
    required this.dragHandle,
    required this.onTap,
    required this.onChanged,
    required this.onDuplicate,
    required this.onDelete,
  });

  final String title;
  final WorkoutExercise config;
  final bool expanded;
  final Widget dragHandle;
  final VoidCallback onTap;
  final ValueChanged<WorkoutExercise> onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.45), width: 0.7),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 16.5),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _badge(context, '${config.targetSets} sets'),
                            _badge(context, _repsSummary(config)),
                            _badge(context, _loadSummary(config)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  dragHandle,
                  PopupMenuButton<String>(
                    tooltip: 'Acciones',
                    onSelected: (value) {
                      if (value == 'duplicate') onDuplicate();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicar ejercicio')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: ExerciseConfigInline(config: config, onChanged: onChanged),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 12.2),
      ),
    );
  }

  String _repsSummary(WorkoutExercise exercise) {
    if (exercise.targetReps != null) return 'Reps: ${exercise.targetReps}';
    return 'Reps: ${exercise.targetRepsMin ?? 8}-${exercise.targetRepsMax ?? 12}';
  }

  String _loadSummary(WorkoutExercise exercise) {
    switch (exercise.targetLoadType) {
      case RoutineExerciseLoadType.bodyweight:
        return 'BW';
      case RoutineExerciseLoadType.weightedKg:
        return 'Weighted';
      case RoutineExerciseLoadType.assistedKg:
        return 'Assisted';
      case RoutineExerciseLoadType.machineKg:
        return 'Machine';
    }
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
    final weightApplies = widget.config.targetLoadType == RoutineExerciseLoadType.weightedKg ||
        widget.config.targetLoadType == RoutineExerciseLoadType.assistedKg;
    return Column(
      key: ValueKey(widget.config.id + widget.config.targetLoadType.name + widget.config.targetSets.toString()),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Series', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: widget.config.targetSets > 1 ? () => _setSets(widget.config.targetSets - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 10),
            Text('${widget.config.targetSets}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: widget.config.targetSets < 20 ? () => _setSets(widget.config.targetSets + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('Reps', style: Theme.of(context).textTheme.labelMedium),
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
        const SizedBox(height: 10),
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
                  decoration: const InputDecoration(labelText: 'Mín'),
                  onChanged: (_) => _emit(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Máx'),
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
        const SizedBox(height: 14),
        Text('Carga', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => _showLoadTypeBottomSheet(context),
          child: Text(_label(widget.config.targetLoadType)),
        ),
        if (weightApplies) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.config.targetLoadType == RoutineExerciseLoadType.assistedKg
                  ? 'Asistencia (kg)'
                  : 'Peso objetivo (kg)',
            ),
            onChanged: (_) => _emit(),
          ),
        ],
      ],
    );
  }

  Future<void> _showLoadTypeBottomSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<RoutineExerciseLoadType>(
      context: context,
      showDragHandle: true,
      builder: (context) => LoadTypeBottomSheet(selected: widget.config.targetLoadType),
    );
    if (selected == null) return;
    _setLoadType(selected);
  }

  void _setSets(int sets) => widget.onChanged(widget.config.copyWith(targetSets: sets));

  void _setLoadType(RoutineExerciseLoadType type) {
    final canWeight = type == RoutineExerciseLoadType.weightedKg || type == RoutineExerciseLoadType.assistedKg;
    if (!canWeight) _weightController.text = '';
    widget.onChanged(widget.config.copyWith(targetLoadType: type, targetWeightKg: canWeight ? widget.config.targetWeightKg : null));
  }

  void _emit() {
    final fixed = ((int.tryParse(_repsController.text) ?? widget.config.targetReps ?? 10).clamp(0, 99)) as int;
    final minRaw = ((int.tryParse(_minController.text) ?? widget.config.targetRepsMin ?? 8).clamp(0, 99)) as int;
    final maxRaw = ((int.tryParse(_maxController.text) ?? widget.config.targetRepsMax ?? 12).clamp(0, 99)) as int;
    final min = minRaw <= maxRaw ? minRaw : maxRaw;
    final max = maxRaw >= minRaw ? maxRaw : minRaw;
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final canWeight = widget.config.targetLoadType == RoutineExerciseLoadType.weightedKg ||
        widget.config.targetLoadType == RoutineExerciseLoadType.assistedKg;
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

class LoadTypeBottomSheet extends StatelessWidget {
  const LoadTypeBottomSheet({super.key, required this.selected});

  final RoutineExerciseLoadType selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: RoutineExerciseLoadType.values
              .map(
                (type) => ListTile(
                  leading: Icon(_icon(type)),
                  title: Text(_label(type)),
                  trailing: selected == type ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(type),
                ),
              )
              .toList(),
        ),
      ),
    );
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

  IconData _icon(RoutineExerciseLoadType type) {
    switch (type) {
      case RoutineExerciseLoadType.bodyweight:
        return Icons.accessibility_new_rounded;
      case RoutineExerciseLoadType.weightedKg:
        return Icons.fitness_center_rounded;
      case RoutineExerciseLoadType.assistedKg:
        return Icons.support_rounded;
      case RoutineExerciseLoadType.machineKg:
        return Icons.precision_manufacturing_rounded;
    }
  }
}

class _RoutineExerciseItem {
  const _RoutineExerciseItem({required this.instanceId, required this.exerciseId});

  final String instanceId;
  final String exerciseId;
}
