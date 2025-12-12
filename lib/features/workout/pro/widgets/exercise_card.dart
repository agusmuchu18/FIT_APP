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

  @override
  Widget build(BuildContext context) {
    final summary = '${widget.exercise.sets.length} series · '
        '${widget.exercise.sets.fold<int>(0, (s, e) => s + (e.reps ?? 0))} reps';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
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
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.exercise.sets.length,
                  itemBuilder: (context, index) {
                    final set = widget.exercise.sets[index];
                    return _SetRow(
                      set: set,
                      index: index,
                      onChanged: (updated) => widget.onUpdateSet(updated),
                      onDelete: () => widget.onDeleteSet(set.id),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Notas del ejercicio',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  controller: TextEditingController(text: widget.exercise.notes)
                    ..selection = TextSelection.fromPosition(
                      TextPosition(offset: widget.exercise.notes?.length ?? 0),
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

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

  final SetEntry set;
  final int index;
  final ValueChanged<SetEntry> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('S${index + 1}', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 12),
          _numberField(
            context,
            initial: set.reps?.toString() ?? '',
            label: 'Reps',
            onChanged: (value) => onChanged(
              set.copyWith(reps: int.tryParse(value)),
            ),
          ),
          const SizedBox(width: 8),
          _numberField(
            context,
            initial: set.weight?.toString() ?? '',
            label: 'Peso',
            suffix: 'kg',
            onChanged: (value) => onChanged(
              set.copyWith(weight: double.tryParse(value)),
            ),
          ),
          const SizedBox(width: 8),
          _numberField(
            context,
            initial: set.durationSeconds?.toString() ?? '',
            label: 'Tiempo',
            suffix: 's',
            onChanged: (value) => onChanged(
              set.copyWith(durationSeconds: int.tryParse(value)),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: set.rir ?? 0,
            onChanged: (value) => onChanged(set.copyWith(rir: value)),
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
            context,
            initial: set.restSeconds?.toString() ?? '',
            label: 'Desc',
            suffix: 's',
            onChanged: (value) => onChanged(
              set.copyWith(restSeconds: int.tryParse(value)),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Widget _numberField(
    BuildContext context, {
    required String initial,
    required String label,
    String? suffix,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 80,
      child: TextField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
        ),
        controller: TextEditingController(text: initial)
          ..selection = TextSelection.fromPosition(
            TextPosition(offset: initial.length),
          ),
        onChanged: onChanged,
      ),
    );
  }
}
