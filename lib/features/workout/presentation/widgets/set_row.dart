import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import '../../pro/models/workout_models.dart';
import '../../domain/training_units.dart';
import 'workout_units_host.dart';
import 'bodyweight_mode_selector.dart';

/// Shared column widths so [SetRowHeader] and [SetRow] stay aligned.
class SetRowColumns {
  static const double index = 44;
  static const double check = 48;
  static const int previousFlex = 5;
  static const int loadFlex = 4;
  static const int resultFlex = 4;
}

/// Accepts `90`, `1:30` or `01:30`; returns seconds or null when invalid.
int? parseDurationInput(String text) {
  final input = text.trim();
  if (input.isEmpty) return null;
  final parts = input.split(':');
  if (parts.length == 1) {
    final value = int.tryParse(parts.single);
    return value != null && value > 0 ? value : null;
  }
  if (parts.length == 2) {
    final minutes = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    if (minutes < 0 || seconds < 0 || seconds > 59) return null;
    final total = minutes * 60 + seconds;
    return total > 0 ? total : null;
  }
  return null;
}

String formatDurationInput(int seconds) {
  if (seconds < 60) return '$seconds';
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Column titles shown once above the sets of an exercise.
class SetRowHeader extends StatelessWidget {
  const SetRowHeader({
    super.key,
    this.isTimed = false,
    this.isAssisted = false,
    this.isDistance = false,
    this.showLoad,
    this.loadTitle,
  });
  final bool isTimed, isAssisted, isDistance;
  final bool? showLoad;
  final String? loadTitle;

  @override
  Widget build(BuildContext context) {
    final units = WorkoutUnits.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      letterSpacing: .6,
    );
    final result = isDistance
        ? units.distance.label.toUpperCase()
        : isTimed
        ? 'TIEMPO'
        : 'REPS';
    Widget cell(String text, {int? flex, double? width}) {
      final child = Text(
        text,
        style: style,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      return width != null
          ? SizedBox(width: width, child: child)
          : Expanded(flex: flex!, child: child);
    }

    final loadVisible = showLoad ?? (!isTimed && !isDistance);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
        child: Row(
          children: [
            cell('SERIE', width: SetRowColumns.index),
            cell('ANTERIOR', flex: SetRowColumns.previousFlex),
            if (loadVisible)
              cell(
                loadTitle ??
                    (isAssisted ? 'ASIST.' : units.weight.label.toUpperCase()),
                flex: SetRowColumns.loadFlex,
              ),
            cell(
              result,
              flex: loadVisible
                  ? SetRowColumns.resultFlex
                  : SetRowColumns.loadFlex + SetRowColumns.resultFlex,
            ),
            SizedBox(
              width: SetRowColumns.check,
              child: Icon(Icons.check, size: 16, color: style?.color),
            ),
          ],
        ),
      ),
    );
  }
}

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.onChanged,
    this.isTimed = false,
    this.isAssisted = false,
    this.onDurationChanged,
    this.onDelete,
    this.isExpanded = false,
    this.onToggleExpanded,
    this.onDetailsChanged,
    this.isDistance = false,
    this.onDistanceChanged,
    this.loadIncrement,
    this.onCompleteRequested,
    this.isRecord = false,
    this.onKindChanged,
    this.isBodyweight = false,
    this.loadType,
    this.reserveLoadColumn = false,
    this.onLoadTypeChanged,
    this.onApplyPrevious,
  });
  final SetInSession set;
  final bool isBodyweight, reserveLoadColumn;
  final RoutineExerciseLoadType? loadType;
  final ValueChanged<RoutineExerciseLoadType>? onLoadTypeChanged;
  final VoidCallback? onApplyPrevious;
  final bool isTimed, isAssisted, isExpanded, isDistance;
  final double? loadIncrement;
  final ValueChanged<int?>? onDurationChanged;
  final ValueChanged<double?>? onDistanceChanged;
  final VoidCallback? onDelete, onToggleExpanded;
  final ValueChanged<SetInSession>? onDetailsChanged;

  /// When provided, the check is always available for unchecked sets: the
  /// owner fills empty fields (previous session or plan) and completes it.
  final VoidCallback? onCompleteRequested;

  /// Completed set that beats every saved session for this exercise.
  final bool isRecord;

  /// Warm-up / drop / failure label; allowed on completed sets too.
  final ValueChanged<SetKind>? onKindChanged;
  final void Function({
    double? kg,
    bool? clearKg,
    int? reps,
    bool? clearReps,
    bool? done,
  })
  onChanged;
  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final _kg = TextEditingController(text: _loadText),
      _result = TextEditingController(text: _resultText);
  late final _kgFocus = FocusNode()..addListener(_sync),
      _resultFocus = FocusNode()..addListener(_sync);
  RoutineExerciseLoadType get _mode =>
      widget.set.loadType ??
      widget.loadType ??
      (widget.isAssisted
          ? RoutineExerciseLoadType.assistedKg
          : RoutineExerciseLoadType.weightedKg);
  bool get _assisted => _mode == RoutineExerciseLoadType.assistedKg;
  bool get _loadVisible =>
      _mode != RoutineExerciseLoadType.bodyweight &&
      !widget.isDistance &&
      (!widget.isTimed || widget.isBodyweight);
  bool _kgInvalid = false, _resultInvalid = false;
  TrainingUnits _units = const TrainingUnits();
  double get _step =>
      widget.loadIncrement ??
      WorkoutUnits.preferencesOf(context).loadIncrementKg;
  String get _stepLabel => TrainingUnits.number(_units.weight.fromKg(_step));

  String _formatLoad(double value) =>
      TrainingUnits.number(_units.weight.fromKg(value));

  String get _loadText {
    final value = _assisted ? widget.set.assistanceKg : widget.set.kg;
    return value == null ? '' : _formatLoad(value);
  }

  String get _resultText {
    if (widget.isDistance) {
      return widget.set.distanceMeters == null
          ? ''
          : TrainingUnits.number(
              _units.distance.fromMeters(widget.set.distanceMeters!),
            );
    }
    if (widget.isTimed) {
      final seconds = widget.set.durationSeconds;
      return seconds == null ? '' : formatDurationInput(seconds);
    }
    return widget.set.reps?.toString() ?? '';
  }

  PreviousSet? get _previous => widget.set.previous;

  String? get _previousLoadHint {
    final previous = _previous;
    if (previous?.compatibleWith(_mode, bodyweight: widget.isBodyweight) !=
        true) {
      return null;
    }
    final value = _assisted ? previous?.assistanceKg : previous?.kg;
    return value == null ? null : _formatLoad(value);
  }

  String? get _previousResultHint {
    final previous = _previous;
    if (previous == null || widget.isDistance) return null;
    if (widget.isTimed) {
      return previous.durationSeconds == null
          ? null
          : formatDurationInput(previous.durationSeconds!);
    }
    return previous.reps?.toString();
  }

  /// Short previous value for the table column, e.g. `60 × 8`.
  String get _previousCompact {
    final p = _previous;
    if (p == null) return '—';
    final result = p.durationSeconds != null
        ? formatDurationInput(p.durationSeconds!)
        : '${p.reps ?? '—'}';
    if (p.loadIsAmbiguous) {
      return '? ${p.kg == null ? '' : _formatLoad(p.kg!)} × $result';
    }
    if (p.loadType == RoutineExerciseLoadType.bodyweight) return result;
    if (p.assistanceKg != null &&
        (p.loadType == null ||
            p.loadType == RoutineExerciseLoadType.assistedKg)) {
      return '−${_formatLoad(p.assistanceKg!)} × $result';
    }
    if (p.kg == null || p.kg == 0) return result;
    return '${p.loadType == RoutineExerciseLoadType.addedWeightKg ? '+' : ''}${_formatLoad(p.kg!)} × $result';
  }

  bool get _canCopyPrevious {
    final previous = _previous;
    if (widget.set.done || previous == null || widget.isDistance) return false;
    return widget.isTimed
        ? previous.durationSeconds != null
        : previous.reps != null;
  }

  void _copyPrevious() {
    final previous = _previous;
    if (previous == null || widget.set.done) return;
    if (widget.onApplyPrevious != null) {
      widget.onApplyPrevious!();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _kgInvalid = false;
      _resultInvalid = false;
    });
    if (widget.isTimed) {
      if (previous.durationSeconds != null) {
        widget.onDurationChanged?.call(previous.durationSeconds);
      }
      return;
    }
    final load =
        !previous.compatibleWith(_mode, bodyweight: widget.isBodyweight) ||
            _mode == RoutineExerciseLoadType.bodyweight
        ? null
        : _assisted
        ? previous.assistanceKg
        : previous.kg;
    widget.onChanged(
      kg: load,
      clearKg: load == null,
      reps: previous.reps,
      clearReps: false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = WorkoutUnits.of(context),
        changed =
            units.weight != _units.weight || units.distance != _units.distance;
    _units = units;
    if (changed) {
      _kgInvalid = false;
      _resultInvalid = false;
      _kg.text = _loadText;
      _result.text = _resultText;
    }
  }

  void _sync() {
    if (!_kgFocus.hasFocus && !_kgInvalid && _kg.text != _loadText) {
      _kg.text = _loadText;
    }
    if (!_resultFocus.hasFocus &&
        !_resultInvalid &&
        _result.text != _resultText) {
      _result.text = _resultText;
    }
  }

  @override
  void didUpdateWidget(covariant SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMode =
        oldWidget.set.loadType ??
        oldWidget.loadType ??
        (oldWidget.isAssisted
            ? RoutineExerciseLoadType.assistedKg
            : RoutineExerciseLoadType.weightedKg);
    if (oldMode != _mode) {
      _kgInvalid = false;
      _kg.text = _loadText;
    }
    _sync();
  }

  @override
  void dispose() {
    _kg.dispose();
    _result.dispose();
    _kgFocus.dispose();
    _resultFocus.dispose();
    super.dispose();
  }

  void _changeLoad(String text) {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    final invalid =
        text.trim().isNotEmpty &&
        (value == null || !value.isFinite || value < 0);
    setState(() => _kgInvalid = invalid);
    widget.onChanged(
      kg: invalid || value == null ? null : _units.weight.toKg(value),
      clearKg: invalid || value == null,
    );
  }

  void _changeResult(String text) {
    if (widget.isTimed) {
      final seconds = parseDurationInput(text);
      final invalid = text.trim().isNotEmpty && seconds == null;
      setState(() => _resultInvalid = invalid);
      widget.onDurationChanged?.call(invalid ? null : seconds);
      return;
    }
    final value = num.tryParse(text.trim().replaceAll(',', '.'));
    final invalid =
        text.trim().isNotEmpty &&
        (value == null ||
            !value.isFinite ||
            value <= 0 ||
            (!widget.isDistance && value != value.round()));
    setState(() => _resultInvalid = invalid);
    if (widget.isDistance) {
      widget.onDistanceChanged?.call(
        invalid || value == null ? null : _units.distance.toMeters(value),
      );
    } else {
      widget.onChanged(
        reps: invalid ? null : value?.toInt(),
        clearReps: invalid || value == null,
      );
    }
  }

  void _increment(double direction) {
    final old = _assisted ? widget.set.assistanceKg : widget.set.kg;
    final next = ((old ?? 0) + direction * _step).clamp(0, double.infinity);
    widget.onChanged(kg: next.toDouble(), clearKg: false);
  }

  void _selectAll(TextEditingController controller) => controller.selection =
      TextSelection(baseOffset: 0, extentOffset: controller.text.length);

  String get _loadLabel => _assisted
      ? 'Asist. ${_units.weight.label}'
      : _mode == RoutineExerciseLoadType.addedWeightKg
      ? 'Lastre (${_units.weight.label})'
      : _units.weight == WeightUnit.kg
      ? 'Kg'
      : 'Lb';

  String get _resultLabel => widget.isDistance
      ? switch (_units.distance) {
          DistanceUnit.meters => 'Metros',
          DistanceUnit.kilometers => 'Kilómetros',
          DistanceUnit.miles => 'Millas',
        }
      : widget.isTimed
      ? 'Tiempo (s o m:ss)'
      : 'Reps';

  InputDecoration _decoration({
    required bool compact,
    required String label,
    required String? hint,
    required String? error,
  }) => compact
      ? InputDecoration(
          isDense: true,
          hintText: hint,
          errorText: error,
          errorMaxLines: 2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 10,
          ),
        )
      : InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          errorText: error,
        );

  Widget _loadField({required bool compact}) => Semantics(
    label: '$_loadLabel, serie ${widget.set.index}',
    child: TextField(
      key: ValueKey('set-load-${widget.set.id}'),
      controller: _kg,
      focusNode: _kgFocus,
      readOnly: widget.set.done,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      textInputAction: TextInputAction.next,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onTap: () => _selectAll(_kg),
      onSubmitted: (_) => _resultFocus.requestFocus(),
      decoration:
          _decoration(
            compact: compact,
            label: _loadLabel,
            hint: _previousLoadHint,
            error: _kgInvalid ? 'Carga inválida' : null,
          ).copyWith(
            // Distinguish mixed bodyweight modes without opening the row details.
            // The minus sign denotes assistance, never negative lifted volume.
            prefixIcon: compact && widget.isBodyweight
                ? ExcludeSemantics(
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Text(_assisted ? '−' : '+'),
                    ),
                  )
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 18),
          ),
      onChanged: _changeLoad,
    ),
  );

  Widget _resultField({required bool compact}) => Semantics(
    label: '$_resultLabel, serie ${widget.set.index}',
    child: TextField(
      key: ValueKey('set-result-${widget.set.id}'),
      controller: _result,
      focusNode: _resultFocus,
      readOnly: widget.set.done,
      textAlign: compact ? TextAlign.center : TextAlign.start,
      // `next` moves to the following set's first field: the controls in
      // between are excluded from focus traversal.
      textInputAction: TextInputAction.next,
      keyboardType: widget.isTimed
          ? TextInputType.datetime
          : TextInputType.numberWithOptions(decimal: widget.isDistance),
      onTap: () => _selectAll(_result),
      decoration: _decoration(
        compact: compact,
        label: _resultLabel,
        hint: _previousResultHint,
        error: _resultInvalid
            ? (widget.isTimed
                  ? 'Duración inválida'
                  : widget.isDistance
                  ? 'Distancia inválida'
                  : 'Repeticiones inválidas')
            : null,
      ),
      onChanged: _changeResult,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final done = widget.set.done, scheme = Theme.of(context).colorScheme;
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final valid =
        !_kgInvalid &&
        !_resultInvalid &&
        widget.set.hasValidResult(
          isTimed: widget.isTimed,
          isDistance: widget.isDistance,
        );
    final canComplete =
        done ||
        valid ||
        (widget.onCompleteRequested != null && !_kgInvalid && !_resultInvalid);
    final toggle = ExcludeFocusTraversal(
      child: IconButton(
        tooltip: widget.isExpanded
            ? 'Contraer serie ${widget.set.index}'
            : 'Detalles de serie ${widget.set.index}',
        onPressed: widget.onToggleExpanded,
        padding: EdgeInsets.zero,
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isRecord)
              Icon(Icons.emoji_events, size: 18, color: scheme.tertiary)
            else if (widget.set.kind != SetKind.normal)
              Text(
                widget.set.kind.badge,
                semanticsLabel:
                    '${widget.set.kind.label}, serie ${widget.set.index}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: widget.set.kind == SetKind.warmup
                      ? scheme.secondary
                      : scheme.error,
                ),
              )
            else
              Text(
                '${widget.set.index}',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            if (widget.onToggleExpanded != null && enlarged)
              Icon(
                widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
          ],
        ),
      ),
    );
    final check = ExcludeFocusTraversal(
      child: Checkbox(
        value: done,
        semanticLabel: 'Serie ${widget.set.index} completada',
        onChanged: canComplete
            ? (v) {
                if (v == true) FocusScope.of(context).unfocus();
                if (v == true && !valid && widget.onCompleteRequested != null) {
                  widget.onCompleteRequested!();
                  return;
                }
                widget.onChanged(done: v ?? false);
              }
            : null,
      ),
    );
    final previous = ExcludeFocusTraversal(
      child: Semantics(
        button: _canCopyPrevious,
        label: _previous == null
            ? 'Sin registro anterior'
            : 'Anterior: ${_previous!.labelFor(_units)}${_canCopyPrevious ? '. Tocá para copiar' : ''}',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _canCopyPrevious ? _copyPrevious : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Text(
              enlarged ? 'Anterior: $_previousCompact' : _previousCompact,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
    final loadVisible = _loadVisible;
    final columnVisible = loadVisible || widget.reserveLoadColumn;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      margin: EdgeInsets.only(bottom: enlarged ? 8 : 4),
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: enlarged ? 8 : 2),
      decoration: BoxDecoration(
        color: done
            ? scheme.primary.withValues(alpha: .14)
            : widget.isExpanded
            ? scheme.surfaceContainerHighest.withValues(alpha: .35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: enlarged
            ? Border.all(color: done ? scheme.primary : scheme.outlineVariant)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (enlarged) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Serie ${widget.set.index}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                toggle,
                check,
              ],
            ),
            if (loadVisible) ...[
              _loadField(compact: false),
              const SizedBox(height: 8),
            ],
            _resultField(compact: false),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: previous),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: SetRowColumns.index, child: toggle),
                Expanded(flex: SetRowColumns.previousFlex, child: previous),
                if (columnVisible)
                  Expanded(
                    flex: SetRowColumns.loadFlex,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: loadVisible
                          ? _loadField(compact: true)
                          : const Text('—', textAlign: TextAlign.center),
                    ),
                  ),
                Expanded(
                  flex: columnVisible
                      ? SetRowColumns.resultFlex
                      : SetRowColumns.loadFlex + SetRowColumns.resultFlex,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _resultField(compact: true),
                  ),
                ),
                SizedBox(
                  width: SetRowColumns.check,
                  child: Center(child: check),
                ),
              ],
            ),
          if (widget.set.loadIsAmbiguous && widget.set.kg != null)
            Text(
              'Carga guardada sin clasificar: ${_units.valueWithUnit('kg', widget.set.kg!)}. No se usa como lastre ni para volumen.',
            ),
          if (widget.isExpanded) ...[
            if (widget.isBodyweight && widget.onLoadTypeChanged != null)
              BodyweightModeSelector(
                value: _mode,
                title: 'Modalidad de esta serie',
                onChanged: (value) {
                  FocusScope.of(context).unfocus();
                  widget.onLoadTypeChanged!(value);
                },
              ),
            const SizedBox(height: 12),
            if (widget.onKindChanged != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final kind in SetKind.values)
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: widget.set.kind == kind,
                      onSelected: (_) => widget.onKindChanged!(kind),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (loadVisible)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Reducir carga $_stepLabel ${_units.weight.label}',
                    onPressed: done ? null : () => _increment(-1),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('Paso: $_stepLabel ${_units.weight.label}'),
                  IconButton(
                    tooltip:
                        'Aumentar carga $_stepLabel ${_units.weight.label}',
                    onPressed: done ? null : () => _increment(1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            if (widget.onDetailsChanged != null) ...[
              if (loadVisible && !_assisted) ...[
                DropdownButtonFormField<LoadConvention>(
                  initialValue: widget.set.loadConvention,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Cómo registrás la carga',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: LoadConvention.recorded,
                      child: Text('Tal como fue registrada'),
                    ),
                    DropdownMenuItem(
                      value: LoadConvention.total,
                      child: Text('Carga total'),
                    ),
                    DropdownMenuItem(
                      value: LoadConvention.perImplement,
                      child: Text('Por implemento'),
                    ),
                  ],
                  onChanged: done
                      ? null
                      : (v) {
                          if (v != null) {
                            widget.onDetailsChanged!(
                              widget.set.copyWith(loadConvention: v),
                            );
                          }
                        },
                ),
                if (widget.set.loadConvention == LoadConvention.perImplement)
                  DropdownButtonFormField<int>(
                    initialValue: widget.set.implementCount,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad de implementos',
                      helperText: 'Necesaria para calcular volumen. No se asume una pareja.',
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Un implemento')),
                      DropdownMenuItem(
                        value: 2,
                        child: Text('Dos implementos'),
                      ),
                    ],
                    onChanged: done
                        ? null
                        : (v) => widget.onDetailsChanged!(
                            widget.set.copyWith(implementCount: v),
                          ),
                  ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: widget.set.rir ?? -1,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Repeticiones en reserva (opcional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: -1,
                    child: Text('Sin registrar'),
                  ),
                  for (var i = 0; i <= 10; i++)
                    DropdownMenuItem(value: i, child: Text('RIR $i')),
                ],
                onChanged: done
                    ? null
                    : (v) => widget.onDetailsChanged!(
                        widget.set.copyWith(rir: v, clearRir: v == -1),
                      ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: widget.set.note ?? '',
                readOnly: done,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota de esta serie',
                ),
                onChanged: (v) =>
                    widget.onDetailsChanged!(widget.set.copyWith(note: v)),
              ),
            ],
            if (widget.onDelete != null)
              TextButton.icon(
                onPressed: widget.onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar serie'),
              ),
          ],
        ],
      ),
    );
  }
}
