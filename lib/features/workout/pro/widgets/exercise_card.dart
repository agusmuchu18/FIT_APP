import 'package:flutter/material.dart';

import '../models/workout_models.dart';

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onDuplicate,
    required this.onDelete,
    required this.onAddSet,
    required this.onCopySet,
    required this.onUpdateSet,
    required this.onDeleteSet,
    required this.onUpdateNotes,
  });

  final WorkoutExercise exercise;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onAddSet;
  final VoidCallback onCopySet;
  final void Function(SetEntry set) onUpdateSet;
  final void Function(String setId) onDeleteSet;
  final void Function(String? notes) onUpdateNotes;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool expanded = false;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.exercise.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant ExerciseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exercise.notes != _notesController.text) {
      _notesController.text = widget.exercise.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summary = '${widget.exercise.sets.length} series · '
        '${widget.exercise.sets.fold<int>(0, (s, e) => s + (e.reps ?? 0))} reps';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        maintainState: true,
        initiallyExpanded: expanded,
        onExpansionChanged: (value) => setState(() => expanded = value),
        title: Text(widget.exercise.name),
        subtitle: Text(widget.exercise.muscleGroup ?? 'Sin grupo'),
        trailing: Text(summary),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onAddSet,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar serie'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: widget.onCopySet,
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Copiar anterior'),
                    ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'duplicate') {
                          widget.onDuplicate();
                        } else if (value == 'delete') {
                          widget.onDelete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Duplicar ejercicio'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.exercise.sets.length,
                  itemBuilder: (context, index) {
                    final set = widget.exercise.sets[index];
                    final isNewSet = (set.reps ?? set.weight ?? set.durationSeconds ?? set.rir ?? set.restSeconds) == null;
                    return _SetRow(
                      key: ValueKey(set.id),
                      set: set,
                      index: index,
                      autofocus: isNewSet && index == widget.exercise.sets.length - 1,
                      onChanged: (updated) => widget.onUpdateSet(updated),
                      onDelete: () => widget.onDeleteSet(set.id),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas del ejercicio',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  onChanged: widget.onUpdateNotes,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.index,
    required this.autofocus,
    required this.onChanged,
    required this.onDelete,
  });

  final SetEntry set;
  final int index;
  final bool autofocus;
  final ValueChanged<SetEntry> onChanged;
  final VoidCallback onDelete;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late final TextEditingController _durationController;
  late final TextEditingController _restController;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(text: widget.set.reps?.toString() ?? '');
    _weightController = TextEditingController(text: widget.set.weight?.toString() ?? '');
    _durationController = TextEditingController(text: widget.set.durationSeconds?.toString() ?? '');
    _restController = TextEditingController(text: widget.set.restSeconds?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repsText = widget.set.reps?.toString() ?? '';
    if (_repsController.text != repsText) {
      _repsController.text = repsText;
    }
    final weightText = widget.set.weight?.toString() ?? '';
    if (_weightController.text != weightText) {
      _weightController.text = weightText;
    }
    final durationText = widget.set.durationSeconds?.toString() ?? '';
    if (_durationController.text != durationText) {
      _durationController.text = durationText;
    }
    final restText = widget.set.restSeconds?.toString() ?? '';
    if (_restController.text != restText) {
      _restController.text = restText;
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    _restController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('S${widget.index + 1}', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                _numberField(
                  controller: _repsController,
                  label: 'Reps',
                  autofocus: widget.autofocus,
                  onChanged: (value) => widget.onChanged(
                    widget.set.copyWith(reps: int.tryParse(value)),
                  ),
                ),
                const SizedBox(width: 8),
                _numberField(
                  controller: _weightController,
                  label: 'Peso',
                  suffix: 'kg',
                  onChanged: (value) => widget.onChanged(
                    widget.set.copyWith(weight: double.tryParse(value)),
                  ),
                ),
                const SizedBox(width: 8),
                _numberField(
                  controller: _durationController,
                  label: 'Tiempo',
                  suffix: 's',
                  onChanged: (value) => widget.onChanged(
                    widget.set.copyWith(durationSeconds: int.tryParse(value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<int>(
                  value: widget.set.rir ?? 0,
                  onChanged: (value) => widget.onChanged(widget.set.copyWith(rir: value)),
                  items: List.generate(
                    6,
                    (index) => DropdownMenuItem(
                      value: index,
                      child: Text('RIR $index'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _numberField(
                  controller: _restController,
                  label: 'Desc',
                  suffix: 's',
                  onChanged: (value) => widget.onChanged(
                    widget.set.copyWith(restSeconds: int.tryParse(value)),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool autofocus = false,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 90,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
        ),
        autofocus: autofocus,
        onChanged: onChanged,
      ),
    );
  }
}
