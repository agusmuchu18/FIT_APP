import 'package:flutter/material.dart';

import '../data/exercise_definition.dart';
import '../models/workout_models.dart';

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.definition,
    required this.onDuplicate,
    required this.onDelete,
    required this.onAddSet,
    required this.onCopySet,
    required this.onBumpReps,
    required this.onBumpWeight,
    required this.onUpdateSet,
    required this.onDeleteSet,
    required this.onRestoreSet,
    required this.onUpdateNotes,
  });

  final WorkoutExercise exercise;
  final ExerciseDefinition? definition;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onAddSet;
  final VoidCallback onCopySet;
  final VoidCallback onBumpReps;
  final VoidCallback onBumpWeight;
  final void Function(SetEntry set) onUpdateSet;
  final void Function(String setId) onDeleteSet;
  final void Function(int index, SetEntry set) onRestoreSet;
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
    final weightAvailable = widget.exercise.sets.any((s) => s.externalLoadKg != null);
    final collapsedSummary = widget._buildCollapsedSummary();
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.black.withOpacity(0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        child: ExpansionTile(
          maintainState: true,
          initiallyExpanded: expanded,
          onExpansionChanged: (value) => setState(() => expanded = value),
          title: Text(widget.exercise.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.exercise.muscleGroup ?? 'Sin grupo'),
              if (!expanded) ...[
                const SizedBox(height: 4),
                Text(
                  collapsedSummary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
          trailing: Text(summary),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: widget.onAddSet,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Serie'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onCopySet,
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copiar última'),
                      ),
                      OutlinedButton.icon(
                        onPressed: widget.onBumpReps,
                        icon: const Icon(Icons.fitness_center),
                        label: const Text('+1 rep a todas'),
                      ),
                      if (weightAvailable)
                        OutlinedButton.icon(
                          onPressed: widget.onBumpWeight,
                          icon: const Icon(Icons.scale),
                          label: const Text('+2.5 kg a todas'),
                        ),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      key: ValueKey(widget.exercise.sets.length),
                      children: [
                        for (var i = 0; i < widget.exercise.sets.length; i++)
                          Dismissible(
                            key: ValueKey(widget.exercise.sets[i].id),
                            background: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) {
                              final removed = widget.exercise.sets[i];
                              widget.onDeleteSet(removed.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Serie eliminada'),
                                  action: SnackBarAction(
                                    label: 'Deshacer',
                                    onPressed: () => widget.onRestoreSet(i, removed),
                                  ),
                                ),
                              );
                            },
                            child: _SetRow(
                              set: widget.exercise.sets[i],
                              index: i,
                              autofocus: (widget.exercise.sets[i].reps ??
                                          widget.exercise.sets[i].externalLoadKg ??
                                          widget.exercise.sets[i].assistanceKg ??
                                          widget.exercise.sets[i].bodyweightKg ??
                                          widget.exercise.sets[i].bodyweightFactor ??
                                          widget.exercise.sets[i].durationSeconds ??
                                          widget.exercise.sets[i].rir ??
                                          widget.exercise.sets[i].restSeconds) ==
                                      null &&
                                  i == widget.exercise.sets.length - 1,
                              definition: widget.definition,
                              onChanged: (updated) => widget.onUpdateSet(updated),
                              onDelete: () => widget.onDeleteSet(widget.exercise.sets[i].id),
                            ),
                          ),
                      ],
                    ),
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
      ),
    );
  }
}

extension on ExerciseCard {
  String _buildCollapsedSummary() {
    final sets = exercise.sets.length;
    final volume = exercise.sets.fold<double>(
      0,
      (sum, set) => sum + ((set.externalLoadKg ?? 0) * (set.reps ?? 0)),
    );
    final best = exercise.sets
        .where((s) => s.externalLoadKg != null && s.reps != null)
        .fold<SetEntry?>(
          null,
          (best, current) =>
              best == null || (current.externalLoadKg ?? 0) > (best.externalLoadKg ?? 0)
                  ? current
                  : best,
        );

    final bestLabel = best == null
        ? 'sin PR'
        : '${best.externalLoadKg?.toStringAsFixed(1)}kg x ${best.reps ?? 0}';

    final volumeLabel = volume == 0 ? 'volumen —' : 'volumen ${volume.toStringAsFixed(1)}kg';

    return '$sets series · $volumeLabel · $bestLabel';
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.index,
    required this.autofocus,
    required this.definition,
    required this.onChanged,
    required this.onDelete,
  });

  final SetEntry set;
  final int index;
  final bool autofocus;
  final ExerciseDefinition? definition;
  final ValueChanged<SetEntry> onChanged;
  final VoidCallback onDelete;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _repsController;
  late final TextEditingController _externalLoadController;
  late final TextEditingController _assistanceController;
  late final TextEditingController _bodyweightController;
  late final TextEditingController _bodyweightFactorController;
  late final TextEditingController _durationController;
  late final TextEditingController _restController;
  late final FocusNode _repsFocus;
  late final FocusNode _externalFocus;
  late final FocusNode _assistanceFocus;
  late final FocusNode _bodyweightFactorFocus;
  late final FocusNode _durationFocus;
  late final FocusNode _restFocus;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _repsController = TextEditingController(text: widget.set.reps?.toString() ?? '');
    _externalLoadController =
        TextEditingController(text: widget.set.externalLoadKg?.toString() ?? '');
    _assistanceController =
        TextEditingController(text: widget.set.assistanceKg?.toString() ?? '');
    _bodyweightController =
        TextEditingController(text: widget.set.bodyweightKg?.toString() ?? '');
    _bodyweightFactorController =
        TextEditingController(
            text: (widget.set.bodyweightFactor ?? widget.definition?.bodyweightFactor)
                    ?.toString() ??
                '');
    _durationController = TextEditingController(text: widget.set.durationSeconds?.toString() ?? '');
    _restController = TextEditingController(text: widget.set.restSeconds?.toString() ?? '');
    _repsFocus = FocusNode();
    _externalFocus = FocusNode();
    _assistanceFocus = FocusNode();
    _bodyweightFactorFocus = FocusNode();
    _durationFocus = FocusNode();
    _restFocus = FocusNode();
    _showAdvanced =
        widget.set.restSeconds != null || widget.set.durationSeconds != null || widget.set.rir != null;
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repsText = widget.set.reps?.toString() ?? '';
    if (_repsController.text != repsText) {
      _repsController.text = repsText;
    }
    final externalText = widget.set.externalLoadKg?.toString() ?? '';
    if (_externalLoadController.text != externalText) {
      _externalLoadController.text = externalText;
    }
    final assistanceText = widget.set.assistanceKg?.toString() ?? '';
    if (_assistanceController.text != assistanceText) {
      _assistanceController.text = assistanceText;
    }
    final bodyweightText = widget.set.bodyweightKg?.toString() ?? '';
    if (_bodyweightController.text != bodyweightText) {
      _bodyweightController.text = bodyweightText;
    }
    final bodyweightFactorText =
        (widget.set.bodyweightFactor ?? widget.definition?.bodyweightFactor)?.toString() ?? '';
    if (_bodyweightFactorController.text != bodyweightFactorText) {
      _bodyweightFactorController.text = bodyweightFactorText;
    }
    final durationText = widget.set.durationSeconds?.toString() ?? '';
    if (_durationController.text != durationText) {
      _durationController.text = durationText;
    }
    final restText = widget.set.restSeconds?.toString() ?? '';
    if (_restController.text != restText) {
      _restController.text = restText;
    }
    if (widget.set.restSeconds != null || widget.set.durationSeconds != null || widget.set.rir != null) {
      _showAdvanced = true;
    }
  }

  @override
  void dispose() {
    _repsController.dispose();
    _externalLoadController.dispose();
    _assistanceController.dispose();
    _bodyweightController.dispose();
    _bodyweightFactorController.dispose();
    _durationController.dispose();
    _restController.dispose();
    _repsFocus.dispose();
    _externalFocus.dispose();
    _assistanceFocus.dispose();
    _bodyweightFactorFocus.dispose();
    _durationFocus.dispose();
    _restFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadType = widget.definition?.loadType;
    final loadFields = _buildLoadFields(loadType);
    final focusOrder = _focusOrder(loadType);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('S${widget.index + 1}', style: Theme.of(context).textTheme.labelLarge),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _numberField(
                          controller: _repsController,
                          label: 'Reps',
                          autofocus: widget.autofocus,
                          focusNode: _repsFocus,
                          nextFocus: _nextFocus(_repsFocus, focusOrder),
                          onChanged: (value) => widget.onChanged(
                            widget.set.copyWith(reps: int.tryParse(value)),
                          ),
                        ),
                        ...loadFields,
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  icon: Icon(_showAdvanced ? Icons.expand_less : Icons.more_horiz),
                  label: Text(_showAdvanced ? 'Ocultar' : 'Más'),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: !_showAdvanced
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _numberField(
                              controller: _durationController,
                              label: 'Tiempo',
                              suffix: 's',
                              focusNode: _durationFocus,
                              nextFocus: _nextFocus(_durationFocus, focusOrder),
                              onChanged: (value) => widget.onChanged(
                                widget.set.copyWith(durationSeconds: int.tryParse(value)),
                              ),
                            ),
                            _numberField(
                              controller: _restController,
                              label: 'Desc',
                              suffix: 's',
                              focusNode: _restFocus,
                              nextFocus: _nextFocus(_restFocus, focusOrder),
                              onChanged: (value) => widget.onChanged(
                                widget.set.copyWith(restSeconds: int.tryParse(value)),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<int>(
                                decoration: const InputDecoration(labelText: 'RIR', isDense: true),
                                value: widget.set.rir ?? 0,
                                items: List.generate(
                                  6,
                                  (index) => DropdownMenuItem(
                                    value: index,
                                    child: Text('RIR $index'),
                                  ),
                                ),
                                onChanged: (value) => widget.onChanged(widget.set.copyWith(rir: value)),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    bool autofocus = false,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox(
      width: 96,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: nextFocus == null ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
        ),
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: (_) {
          if (nextFocus != null) {
            FocusScope.of(context).requestFocus(nextFocus);
          } else {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }

  List<Widget> _buildLoadFields(LoadType? loadType) {
    final type = loadType ?? LoadType.external;
    final effectiveLoad = _effectiveLoad(type);
    final loadFocus = _loadFocusForType(type);
    final focusOrder = _focusOrder(loadType);

    switch (type) {
      case LoadType.external:
        return [
          _numberField(
            controller: _externalLoadController,
            label: 'Peso',
            suffix: 'kg',
            focusNode: loadFocus,
            nextFocus: _nextFocus(loadFocus, focusOrder),
            onChanged: (value) => widget.onChanged(
              widget.set.copyWith(externalLoadKg: _parseDouble(value)),
            ),
          ),
        ];
      case LoadType.bodyweight_effective:
        return [
          _readonlyField(
            controller: _bodyweightController,
            label: 'BW',
            suffix: 'kg',
          ),
          _numberField(
            controller: _bodyweightFactorController,
            label: 'Factor BW',
            focusNode: loadFocus,
            nextFocus: _nextFocus(loadFocus, focusOrder),
            onChanged: (value) => widget.onChanged(
              widget.set.copyWith(bodyweightFactor: _parseDouble(value)),
            ),
          ),
          _effectiveLoadField(effectiveLoad),
        ];
      case LoadType.bodyweight_plus_external:
        return [
          _readonlyField(
            controller: _bodyweightController,
            label: 'BW',
            suffix: 'kg',
          ),
          _numberField(
            controller: _externalLoadController,
            label: 'Lastre',
            suffix: 'kg',
            focusNode: loadFocus,
            nextFocus: _nextFocus(loadFocus, focusOrder),
            onChanged: (value) => widget.onChanged(
              widget.set.copyWith(externalLoadKg: _parseDouble(value)),
            ),
          ),
          _effectiveLoadField(effectiveLoad),
        ];
      case LoadType.assisted_bodyweight:
        return [
          _readonlyField(
            controller: _bodyweightController,
            label: 'BW',
            suffix: 'kg',
          ),
          _numberField(
            controller: _assistanceController,
            label: 'Asistencia',
            suffix: 'kg',
            focusNode: loadFocus,
            nextFocus: _nextFocus(loadFocus, focusOrder),
            onChanged: (value) => widget.onChanged(
              widget.set.copyWith(assistanceKg: _parseDouble(value)),
            ),
          ),
          _effectiveLoadField(effectiveLoad),
        ];
    }
  }

  Widget _readonlyField({
    required TextEditingController controller,
    required String label,
    String? suffix,
  }) {
    return SizedBox(
      width: 106,
      child: TextField(
        controller: controller,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          isDense: true,
        ),
      ),
    );
  }

  Widget _effectiveLoadField(double? value) {
    final display = value == null ? '—' : '${value.toStringAsFixed(1)} kg';
    return SizedBox(
      width: 120,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Carga efectiva', isDense: true),
        child: Text(display),
      ),
    );
  }

  double? _effectiveLoad(LoadType loadType) {
    final bw = widget.set.bodyweightKg;
    final ext = widget.set.externalLoadKg;
    final assistance = widget.set.assistanceKg;
    final factor = widget.set.bodyweightFactor ?? widget.definition?.bodyweightFactor;

    switch (loadType) {
      case LoadType.external:
        return ext;
      case LoadType.bodyweight_effective:
        if (bw == null) return null;
        return bw * (factor ?? 1);
      case LoadType.bodyweight_plus_external:
        if (bw == null && ext == null) return null;
        return (bw ?? 0) + (ext ?? 0);
      case LoadType.assisted_bodyweight:
        if (bw == null && assistance == null) return null;
        return (bw ?? 0) - (assistance ?? 0);
    }
  }

  double? _parseDouble(String value) {
    if (value.isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  List<FocusNode> _focusOrder(LoadType? type) {
    final order = <FocusNode>[_repsFocus];
    final loadFocus = _loadFocusForType(type ?? widget.definition?.loadType ?? LoadType.external);
    if (loadFocus != null) order.add(loadFocus);
    if (_showAdvanced) {
      order.addAll([_durationFocus, _restFocus]);
    }
    return order;
  }

  FocusNode? _loadFocusForType(LoadType type) {
    switch (type) {
      case LoadType.external:
      case LoadType.bodyweight_plus_external:
        return _externalFocus;
      case LoadType.bodyweight_effective:
        return _bodyweightFactorFocus;
      case LoadType.assisted_bodyweight:
        return _assistanceFocus;
    }
  }

  FocusNode? _nextFocus(FocusNode? current, List<FocusNode> order) {
    if (current == null) return null;
    final index = order.indexOf(current);
    if (index == -1 || index + 1 >= order.length) return null;
    return order[index + 1];
  }
}
