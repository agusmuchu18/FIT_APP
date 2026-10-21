import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import '../../../common/widgets/fit_glyph.dart';
import 'set_row.dart';
import 'workout_rest_selector.dart';
import '../../pro/models/workout_models.dart';
import '../../domain/workout_analytics.dart';
import 'exercise_thumbnail.dart';

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
    this.expandedSetId,
    this.onSetExpansion,
    this.onSetDetailsChanged,
    this.onDistanceChanged,
    this.onDuplicate,
    this.onReplace,
    this.onDetails,
    this.onLoadTypeChanged,
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
  final String? expandedSetId;
  final ValueChanged<String>? onSetExpansion;
  final ValueChanged<SetInSession>? onSetDetailsChanged;
  final void Function(String, double?)? onDistanceChanged;
  final VoidCallback? onDuplicate, onReplace, onDetails;
  final ValueChanged<RoutineExerciseLoadType>? onLoadTypeChanged;

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
                  ExerciseThumbnail(
                    exercise: WorkoutExercise(
                      id: exercise.exerciseId,
                      name: exercise.name,
                    ),
                    size: 48,
                  ),
                  const SizedBox(width: 12),
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
                      if (value == 'duplicate') onDuplicate?.call();
                      if (value == 'replace') onReplace?.call();
                      if (value == 'details') onDetails?.call();
                    },
                    itemBuilder: (context) => [
                      if (onDetails != null)
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Ficha, historial y notas permanentes'),
                        ),
                      if (onDuplicate != null)
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Duplicar ejercicio'),
                        ),
                      if (onReplace != null)
                        const PopupMenuItem(
                          value: 'replace',
                          child: Text('Reemplazar ejercicio'),
                        ),
                      const PopupMenuItem(
                        value: 'up',
                        child: Text('Mover arriba'),
                      ),
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Mover abajo'),
                      ),
                      const PopupMenuItem(
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
                  if (onLoadTypeChanged != null &&
                      !exercise.isTimed &&
                      !exercise.isDistance) ...[
                    DropdownButtonFormField<RoutineExerciseLoadType>(
                      initialValue: WorkoutAnalytics.fromLive([exercise])
                          .single
                          .targetLoadType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de carga',
                        helperText: 'Cambiarlo borra las cargas de las series sin completar.',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: RoutineExerciseLoadType.bodyweight,
                          child: Text('Peso corporal'),
                        ),
                        DropdownMenuItem(
                          value: RoutineExerciseLoadType.weightedKg,
                          child: Text('Carga externa'),
                        ),
                        DropdownMenuItem(
                          value: RoutineExerciseLoadType.addedWeightKg,
                          child: Text('Lastre añadido'),
                        ),
                        DropdownMenuItem(
                          value: RoutineExerciseLoadType.assistedKg,
                          child: Text('Asistencia'),
                        ),
                        DropdownMenuItem(
                          value: RoutineExerciseLoadType.machineKg,
                          child: Text('Máquina'),
                        ),
                      ],
                      onChanged: exercise.doneSets > 0
                          ? null
                          : (v) {
                              if (v != null) onLoadTypeChanged!(v);
                            },
                    ),
                    const SizedBox(height: 12),
                  ],
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
                      isDistance: exercise.isDistance,
                      isExpanded: expandedSetId == set.id,
                      onToggleExpanded: onSetExpansion == null
                          ? null
                          : () => onSetExpansion!(set.id),
                      onDetailsChanged: onSetDetailsChanged,
                      onDistanceChanged: (distance) =>
                          onDistanceChanged?.call(set.id, distance),
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
