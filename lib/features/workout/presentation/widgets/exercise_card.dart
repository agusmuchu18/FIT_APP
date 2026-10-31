import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import '../../../common/widgets/fit_glyph.dart';
import 'set_row.dart';
import 'bodyweight_mode_selector.dart';
import 'workout_rest_selector.dart';
import '../../pro/models/workout_models.dart';
import '../../domain/workout_analytics.dart';
import 'exercise_thumbnail.dart';

String _restLabel(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.isExpanded,
    required this.onTap,
    required this.onNotesChanged,
    required this.onRestChanged,
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
    this.onCompleteSet,
    this.isRecord,
    this.supersetLabel,
    this.onLinkNext,
    this.onUnlinkSuperset,
    this.onSetKindChanged,
    this.onSetLoadTypeChanged,
    this.onApplyPrevious,
  });

  final ExerciseInSession exercise;
  final void Function(String, RoutineExerciseLoadType)? onSetLoadTypeChanged;
  final ValueChanged<String>? onApplyPrevious;
  final bool isExpanded;
  final VoidCallback onTap;
  final ValueChanged<String> onNotesChanged;

  /// Rest is edited as a pair so a sheet never mixes a stale value.
  final void Function(bool enabled, int seconds) onRestChanged;
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

  /// Checks a set, filling empty fields from the previous session or plan.
  final ValueChanged<String>? onCompleteSet;
  final bool Function(String setId)? isRecord;

  /// "A", "B"… when the exercise is part of a superset.
  final String? supersetLabel;
  final VoidCallback? onLinkNext, onUnlinkSuperset;
  final void Function(String setId, SetKind kind)? onSetKindChanged;

  bool get _canChangeLoadType =>
      onLoadTypeChanged != null &&
      !exercise.isBodyweight &&
      !exercise.isTimed &&
      !exercise.isDistance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final rest = exercise.restSeconds ?? 90;
    final progress = [
      '${exercise.doneSets}/${exercise.sets.length} hechas',
      if (exercise.restEnabled) 'descanso ${_restLabel(rest)}',
    ].join(' · ');
    final notes = (exercise.notes ?? '').trim();
    final inSuperset = supersetLabel != null;
    final hasLoadColumn =
        !exercise.isDistance &&
        (!exercise.isTimed || exercise.isBodyweight) &&
        exercise.sets.any(
          (s) => exercise.modeFor(s) != RoutineExerciseLoadType.bodyweight,
        );
    final modes = exercise.sets.map(exercise.modeFor).toSet();
    final loadTitle = modes.length > 1
        ? 'CARGA'
        : modes.firstOrNull == RoutineExerciseLoadType.addedWeightKg
        ? 'LASTRE'
        : modes.firstOrNull == RoutineExerciseLoadType.assistedKg
        ? 'ASIST.'
        : null;
    return Card(
      margin: EdgeInsets.only(bottom: inSuperset ? 6 : 12),
      shape: inSuperset
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.tertiary, width: 1.5),
            )
          : null,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
              child: Row(
                children: [
                  ExerciseThumbnail(
                    exercise: WorkoutExercise(
                      id: exercise.exerciseId,
                      name: exercise.name,
                    ),
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, style: theme.textTheme.titleMedium),
                        if (inSuperset)
                          Text(
                            'Superserie $supersetLabel',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        Text(progress, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de ${exercise.name}',
                    onSelected: (value) {
                      switch (value) {
                        case 'details':
                          onDetails?.call();
                        case 'notes':
                          _openNotes(context);
                        case 'rest':
                          _openRest(context);
                        case 'load':
                          _openLoadType(context);
                        case 'link':
                          onLinkNext?.call();
                        case 'unlink':
                          onUnlinkSuperset?.call();
                        case 'duplicate':
                          onDuplicate?.call();
                        case 'replace':
                          onReplace?.call();
                        case 'up':
                          onMoveUp();
                        case 'down':
                          onMoveDown();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onDetails != null)
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Ficha, historial y notas permanentes'),
                        ),
                      PopupMenuItem(
                        value: 'notes',
                        child: Text(
                          notes.isEmpty
                              ? 'Agregar nota de la sesión'
                              : 'Editar nota de la sesión',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rest',
                        child: Text('Descanso entre series'),
                      ),
                      if (_canChangeLoadType)
                        PopupMenuItem(
                          value: 'load',
                          enabled: exercise.doneSets == 0,
                          child: const Text('Tipo de carga'),
                        ),
                      if (onLinkNext != null)
                        const PopupMenuItem(
                          value: 'link',
                          child: Text('Superserie con el siguiente'),
                        ),
                      if (onUnlinkSuperset != null)
                        const PopupMenuItem(
                          value: 'unlink',
                          child: Text('Quitar de la superserie'),
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
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notes.isNotEmpty)
                    InkWell(
                      onTap: () => _openNotes(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notes,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!enlarged && exercise.sets.isNotEmpty)
                    SetRowHeader(
                      showLoad: hasLoadColumn,
                      loadTitle: loadTitle,
                      isTimed: exercise.isTimed,
                      isAssisted: exercise.isAssisted,
                      isDistance: exercise.isDistance,
                    ),
                  for (final set in exercise.sets)
                    _dismissible(
                      context,
                      set,
                      SetRow(
                        key: ValueKey(set.id),
                        set: set,
                        loadType: exercise.modeFor(set),
                        isBodyweight: exercise.isBodyweight,
                        reserveLoadColumn: hasLoadColumn,
                        onLoadTypeChanged: onSetLoadTypeChanged == null
                            ? null
                            : (mode) => onSetLoadTypeChanged!(set.id, mode),
                        onApplyPrevious: onApplyPrevious == null
                            ? null
                            : () => onApplyPrevious!(set.id),
                        isTimed: exercise.isTimed,
                        isAssisted:
                            exercise.modeFor(set) ==
                            RoutineExerciseLoadType.assistedKg,
                        isDistance: exercise.isDistance,
                        isExpanded: expandedSetId == set.id,
                        isRecord: set.done && (isRecord?.call(set.id) ?? false),
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
                        onCompleteRequested: onCompleteSet == null
                            ? null
                            : () => onCompleteSet!(set.id),
                        onKindChanged: onSetKindChanged == null
                            ? null
                            : (kind) => onSetKindChanged!(set.id, kind),
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
                    ),
                  if (exercise.isBodyweight && onLoadTypeChanged != null)
                    BodyweightModeSelector(
                      value: exercise.defaultMode,
                      disclosure: true,
                      onChanged: (mode) {
                        FocusScope.of(context).unfocus();
                        onLoadTypeChanged!(mode);
                      },
                    ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: onAddSet,
                        icon: const FitGlyph(kind: FitGlyphKind.add),
                        label: const Text('Agregar serie'),
                      ),
                      TextButton.icon(
                        onPressed: () => _openRest(context),
                        icon: const Icon(Icons.timer_outlined, size: 18),
                        label: Text(
                          exercise.restEnabled
                              ? 'Descanso ${_restLabel(rest)}'
                              : 'Sin descanso',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dismissible(BuildContext context, SetInSession set, Widget child) {
    if (onDeleteSet == null) return child;
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDeleteSet!(set.id),
      child: child,
    );
  }

  Future<void> _openNotes(BuildContext context) {
    final theme = Theme.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Theme(
        data: theme,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nota de la sesión · ${exercise.name}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: exercise.notes ?? '',
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                onChanged: onNotesChanged,
                decoration: const InputDecoration(
                  hintText: 'Ej.: agarre cerrado, molestia en el hombro…',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(sheet).pop(),
                child: const Text('Listo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRest(BuildContext context) {
    final theme = Theme.of(context);
    var enabled = exercise.restEnabled;
    var seconds = exercise.restSeconds ?? 90;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Theme(
        data: theme,
        child: StatefulBuilder(
          builder: (context, update) {
            void apply(bool nextEnabled, int nextSeconds) {
              update(() {
                enabled = nextEnabled;
                seconds = nextSeconds;
              });
              onRestChanged(nextEnabled, nextSeconds);
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descanso · ${exercise.name}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Empieza solo al marcar una serie de este ejercicio.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  WorkoutRestSelector(
                    enabled: enabled,
                    seconds: seconds,
                    onToggle: (value) => apply(value, seconds),
                    onChanged: (value) => apply(enabled, value),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in const [45, 60, 90, 120, 180])
                        ChoiceChip(
                          label: Text(_restLabel(preset)),
                          selected: enabled && seconds == preset,
                          onSelected: (_) => apply(true, preset),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheet).pop(),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openLoadType(BuildContext context) async {
    final theme = Theme.of(context);
    final current = WorkoutAnalytics.fromLive([exercise]).single.targetLoadType;
    final selected = await showModalBottomSheet<RoutineExerciseLoadType>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheet) => Theme(
        data: theme,
        child: SafeArea(
          child: RadioGroup<RoutineExerciseLoadType>(
            groupValue: current,
            onChanged: (value) => Navigator.of(sheet).pop(value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Tipo de carga',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Cambiarlo borra las cargas de las series sin completar.',
                  ),
                ),
                for (final (value, label) in const [
                  (RoutineExerciseLoadType.bodyweight, 'Peso corporal'),
                  (RoutineExerciseLoadType.weightedKg, 'Carga externa'),
                  (RoutineExerciseLoadType.addedWeightKg, 'Lastre añadido'),
                  (RoutineExerciseLoadType.assistedKg, 'Asistencia'),
                  (RoutineExerciseLoadType.machineKg, 'Máquina'),
                ])
                  RadioListTile<RoutineExerciseLoadType>(
                    value: value,
                    title: Text(label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null && selected != current) {
      onLoadTypeChanged?.call(selected);
    }
  }
}
