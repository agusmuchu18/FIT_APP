import 'package:flutter/material.dart';

import '../../pro/data/exercise_definition.dart';
import '../../pro/models/workout_models.dart';
import 'exercise_thumbnail.dart';

/// Picks exercises for the live session. A tap on a row adds that exercise
/// right away; the round control on the right starts a multiple selection.
Future<List<ExerciseDefinition>?> showAddExerciseSheet(
  BuildContext context, {
  required ExerciseLibraryIndex library,
  List<String> recentIds = const [],
  Set<String> inSessionIds = const {},
  bool allowMultiple = true,
  String title = 'Agregar ejercicio',
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<List<ExerciseDefinition>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Theme(
      data: theme,
      child: _AddExerciseSheet(
        library: library,
        recentIds: recentIds,
        inSessionIds: inSessionIds,
        allowMultiple: allowMultiple,
        title: title,
      ),
    ),
  );
}

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet({
    required this.library,
    required this.recentIds,
    required this.inSessionIds,
    required this.allowMultiple,
    required this.title,
  });
  final ExerciseLibraryIndex library;
  final List<String> recentIds;
  final Set<String> inSessionIds;
  final bool allowMultiple;
  final String title;

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  String _query = '';
  String? _muscle;
  final List<ExerciseDefinition> _selected = [];
  late final List<String> _muscles = _topMuscles();
  late final Map<String, ExerciseDefinition> _byId = {
    for (final e in widget.library.exercises) e.id: e,
  };

  List<String> _topMuscles() {
    final counts = <String, int>{};
    for (final exercise in widget.library.exercises) {
      for (final muscle in exercise.primaryMuscles) {
        counts[muscle] = (counts[muscle] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  String _capitalize(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  List<ExerciseDefinition> get _results {
    final found = widget.library.search(_query);
    final muscle = _muscle;
    if (muscle == null) return found;
    return found.where((e) => e.primaryMuscles.contains(muscle)).toList();
  }

  bool get _multi => _selected.isNotEmpty;

  void _tap(ExerciseDefinition exercise) {
    if (_multi) {
      _toggle(exercise);
      return;
    }
    Navigator.of(context).pop([exercise]);
  }

  void _toggle(ExerciseDefinition exercise) {
    setState(() {
      if (!_selected.remove(exercise)) _selected.add(exercise);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRecents = _query.trim().isEmpty && _muscle == null;
    final recents = showRecents
        ? widget.recentIds
              .map((id) => _byId[id])
              .whereType<ExerciseDefinition>()
              .take(8)
              .toList()
        : const <ExerciseDefinition>[];
    final results = _results;
    final items = <Object>[
      if (recents.isNotEmpty) 'Recientes',
      ...recents,
      if (recents.isNotEmpty) 'Todos los ejercicios',
      ...results,
    ];
    final height =
        (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom) *
        .8;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar ejercicio',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final muscle in _muscles)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(_capitalize(muscle)),
                        selected: _muscle == muscle,
                        onSelected: (selected) =>
                            setState(() => _muscle = selected ? muscle : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty && recents.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No encontramos ejercicios. Probá otro nombre o músculo.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              item,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }
                        final exercise = item as ExerciseDefinition;
                        final selected = _selected.contains(exercise);
                        final inSession = widget.inSessionIds.contains(
                          exercise.id,
                        );
                        return ListTile(
                          leading: ExerciseThumbnail(
                            exercise: WorkoutExercise(
                              id: exercise.id,
                              name: exercise.name,
                            ),
                            size: 40,
                          ),
                          title: Text(exercise.name),
                          subtitle: Text(
                            [
                              exercise.primaryMuscles.join(', '),
                              if (inSession) 'ya en la sesión',
                            ].where((t) => t.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: selected,
                          onTap: () => _tap(exercise),
                          trailing: widget.allowMultiple
                              ? IconButton(
                                  tooltip: selected
                                      ? 'Quitar ${exercise.name} de la selección'
                                      : 'Seleccionar ${exercise.name}',
                                  onPressed: () => _toggle(exercise),
                                  icon: Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            if (_multi)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(List.of(_selected)),
                    child: Text(
                      _selected.length == 1
                          ? 'Agregar 1 ejercicio'
                          : 'Agregar ${_selected.length} ejercicios',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
