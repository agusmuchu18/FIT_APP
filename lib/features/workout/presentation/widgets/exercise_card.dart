import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import 'set_row.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.isExpanded,
    required this.onTap,
    required this.onNotesChanged,
    required this.onRestToggle,
    required this.onRestSecondsChanged,
    required this.onSetChanged,
    required this.onAddSet,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ExerciseInSession exercise;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<String> onNotesChanged;
  final ValueChanged<bool> onRestToggle;
  final ValueChanged<int?> onRestSecondsChanged;
  final void Function(String setId, {double? kg, int? reps, bool? done}) onSetChanged;
  final VoidCallback onAddSet;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final progress = '${exercise.doneSets}/${exercise.sets.length} hechas';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(progress, style: Theme.of(context).textTheme.bodySmall),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                      if (value == 'up') onMoveUp();
                      if (value == 'down') onMoveDown();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'up', child: Text('Mover arriba')),
                      PopupMenuItem(value: 'down', child: Text('Mover abajo')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar ejercicio')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: exercise.notes ?? '',
                    onChanged: onNotesChanged,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Agregar notas...',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Descanso'),
                      const SizedBox(width: 8),
                      Switch(
                        value: exercise.restEnabled,
                        onChanged: onRestToggle,
                      ),
                      Text(exercise.restEnabled ? '${exercise.restSeconds ?? 90}s' : 'APAGADO'),
                      const SizedBox(width: 8),
                      if (exercise.restEnabled)
                        SizedBox(
                          width: 72,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true, hintText: 'seg'),
                            onChanged: (value) => onRestSecondsChanged(int.tryParse(value)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 36, child: Text('Serie')),
                        SizedBox(width: 72, child: Text('Anterior')),
                        Expanded(child: Text('Kg')),
                        SizedBox(width: 8),
                        Expanded(child: Text('Reps')),
                        SizedBox(width: 48, child: Text('Check')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final set in exercise.sets)
                    SetRow(
                      key: ValueKey(set.id),
                      set: set,
                      onChanged: ({kg, reps, done}) => onSetChanged(set.id, kg: kg, reps: reps, done: done),
                    ),
                  TextButton.icon(
                    onPressed: onAddSet,
                    icon: const Icon(Icons.add),
                    label: const Text('+ Agregar serie'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
