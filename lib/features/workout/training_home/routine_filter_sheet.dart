import 'package:flutter/material.dart';

import '../domain/routine_labels.dart';
import '../presentation/widgets/routine_filter_artwork.dart';

class RoutineFilterSheet extends StatefulWidget {
  const RoutineFilterSheet({
    super.key,
    required this.title,
    required this.options,
    required this.initialSelection,
    this.muscle = false,
  });
  final String title;
  final List<String> options;
  final Set<String> initialSelection;
  final bool muscle;
  @override
  State<RoutineFilterSheet> createState() => _RoutineFilterSheetState();
}

class _RoutineFilterSheetState extends State<RoutineFilterSheet> {
  late final _selected = {...widget.initialSelection};
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<String>>{};
    for (final option in widget.options) {
      final category = widget.muscle
          ? RoutineLabels.categories.contains(option.toLowerCase())
                ? 'Categorías y objetivos'
                : 'Grupos musculares'
          : option == 'carry'
          ? 'Patrones de movimiento'
          : 'Equipamiento';
      groups.putIfAbsent(category, () => []).add(option);
    }
    final entries = <({String text, bool heading})>[
      for (final section in [
        widget.muscle ? 'Grupos musculares' : 'Equipamiento',
        widget.muscle ? 'Categorías y objetivos' : 'Patrones de movimiento',
      ])
        if (groups[section] case final options?) ...[
          (text: section, heading: true),
          for (final option in options) (text: option, heading: false),
        ],
    ];
    final colors = Theme.of(context).colorScheme;
    final clear = TextButton(
      onPressed: () => setState(_selected.clear),
      child: const Text('Limpiar'),
    );
    final apply = FilledButton(
      onPressed: () => Navigator.pop(context, {..._selected}),
      child: const Text('Aplicar'),
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                'Selección múltiple · ${_selected.length} seleccionados',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry.heading) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                        child: Semantics(
                          header: true,
                          child: Text(
                            entry.text,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      );
                    }
                    final option = entry.text;
                    final selected = _selected.contains(option);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: CheckboxListTile(
                          key: ValueKey('filter:$option'),
                          value: selected,
                          selected: selected,
                          selectedTileColor: colors.primary.withValues(
                            alpha: .10,
                          ),
                          tileColor: colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? colors.primary
                                  : colors.outlineVariant,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          secondary: RoutineFilterArtwork(
                            value: option,
                            muscle: widget.muscle,
                          ),
                          title: Text(
                            widget.muscle
                                ? RoutineLabels.muscleName(option)
                                : RoutineLabels.equipmentName(option),
                          ),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selected.add(option);
                            } else {
                              _selected.remove(option);
                            }
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              if (MediaQuery.textScalerOf(context).scale(16) > 24)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [clear, const SizedBox(height: 8), apply],
                )
              else
                Row(children: [clear, const Spacer(), apply]),
            ],
          ),
        ),
      ),
    );
  }
}
