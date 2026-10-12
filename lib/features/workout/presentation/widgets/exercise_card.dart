import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import '../../../common/widgets/fit_glyph.dart';
import 'set_row.dart';
import 'workout_rest_selector.dart';

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
    this.onDurationChanged,
    this.onDeleteSet,
  });

  final ExerciseInSession exercise;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<String> onNotesChanged;
  final ValueChanged<bool> onRestToggle;
  final ValueChanged<int?> onRestSecondsChanged;
  final void Function(
    String setId, {
    double? kg,
    bool? clearKg,
    int? reps,
    bool? clearReps,
    bool? done,
  })
  onSetChanged;
  final VoidCallback onAddSet;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final void Function(String, int?)? onDurationChanged;
  final ValueChanged<String>? onDeleteSet;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          progress,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                      if (value == 'up') onMoveUp();
                      if (value == 'down') onMoveDown();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'up', child: Text('Mover arriba')),
                      PopupMenuItem(value: 'down', child: Text('Mover abajo')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar ejercicio'),
                      ),
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
                  WorkoutRestSelector(
                    enabled: exercise.restEnabled,
                    seconds: exercise.restSeconds ?? 90,
                    onToggle: onRestToggle,
                    onChanged: onRestSecondsChanged,
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 6),
                  for (final set in exercise.sets)
                    SetRow(
                      key: ValueKey(set.id),
                      set: set,
                      isTimed: exercise.isTimed,
                      isAssisted: exercise.isAssisted,
                      onDurationChanged: (seconds) =>
                          onDurationChanged?.call(set.id, seconds),
                      onDelete: onDeleteSet == null
                          ? null
                          : () => onDeleteSet!(set.id),
                      onChanged: ({kg, clearKg, reps, clearReps, done}) =>
                          onSetChanged(
                            set.id,
                            kg: kg,
                            clearKg: clearKg ?? false,
                            reps: reps,
                            clearReps: clearReps ?? false,
                            done: done,
                          ),
                    ),
                  TextButton.icon(
                    onPressed: onAddSet,
                    icon: const FitGlyph(kind: FitGlyphKind.add),
                    label: const Text('Agregar serie'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
