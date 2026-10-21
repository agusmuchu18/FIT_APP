import 'package:flutter/material.dart';

import '../../domain/session_models.dart';
import '../../pro/models/workout_models.dart';
import '../../domain/training_units.dart';
import 'workout_units_host.dart';

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
  });
  final SetInSession set;
  final bool isTimed, isAssisted, isExpanded, isDistance;
  final double? loadIncrement;
  final ValueChanged<int?>? onDurationChanged;
  final ValueChanged<double?>? onDistanceChanged;
  final VoidCallback? onDelete, onToggleExpanded;
  final ValueChanged<SetInSession>? onDetailsChanged;
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
  bool _kgInvalid = false, _resultInvalid = false;
  TrainingUnits _units = const TrainingUnits();
  double get _step =>
      widget.loadIncrement ??
      WorkoutUnits.preferencesOf(context).loadIncrementKg;
  String get _stepLabel => TrainingUnits.number(_units.weight.fromKg(_step));
  String get _loadText {
    final value = widget.isAssisted ? widget.set.assistanceKg : widget.set.kg;
    return value == null
        ? ''
        : _units.weight == WeightUnit.kg
        ? value.toString()
        : TrainingUnits.number(_units.weight.fromKg(value));
  }

  String get _resultText => widget.isDistance
      ? widget.set.distanceMeters == null
            ? ''
            : TrainingUnits.number(
                _units.distance.fromMeters(widget.set.distanceMeters!),
              )
      : (widget.isTimed ? widget.set.durationSeconds : widget.set.reps)
                ?.toString() ??
            '';
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
    } else if (widget.isTimed) {
      widget.onDurationChanged?.call(invalid ? null : value?.toInt());
    } else {
      widget.onChanged(
        reps: invalid ? null : value?.toInt(),
        clearReps: invalid || value == null,
      );
    }
  }

  void _increment(double direction) {
    final old = widget.isAssisted ? widget.set.assistanceKg : widget.set.kg;
    final next = ((old ?? 0) + direction * _step).clamp(0, double.infinity);
    widget.onChanged(kg: next.toDouble(), clearKg: false);
  }

  Widget _loadField() => TextField(
    controller: _kg,
    focusNode: _kgFocus,
    readOnly: widget.set.done,
    textInputAction: TextInputAction.next,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onTap: () => _kg.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _kg.text.length,
    ),
    onSubmitted: (_) => _resultFocus.requestFocus(),
    decoration: InputDecoration(
      labelText: widget.isAssisted
          ? 'Asist. ${_units.weight.label}'
          : _units.weight == WeightUnit.kg
          ? 'Kg'
          : 'Lb',
      isDense: true,
      errorText: _kgInvalid ? 'Carga inválida' : null,
    ),
    onChanged: _changeLoad,
  );
  Widget _resultField() => TextField(
    controller: _result,
    focusNode: _resultFocus,
    readOnly: widget.set.done,
    textInputAction: TextInputAction.done,
    keyboardType: TextInputType.numberWithOptions(decimal: widget.isDistance),
    onTap: () => _result.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _result.text.length,
    ),
    onSubmitted: (_) => FocusScope.of(context).unfocus(),
    decoration: InputDecoration(
      labelText: widget.isDistance
          ? switch (_units.distance) {
              DistanceUnit.meters => 'Metros',
              DistanceUnit.kilometers => 'Kilómetros',
              DistanceUnit.miles => 'Millas',
            }
          : widget.isTimed
          ? 'Segundos'
          : 'Reps',
      isDense: true,
      errorText: _resultInvalid
          ? (widget.isTimed
                ? 'Duración inválida'
                : widget.isDistance
                ? 'Distancia inválida'
                : 'Repeticiones inválidas')
          : null,
    ),
    onChanged: _changeResult,
  );
  @override
  Widget build(BuildContext context) {
    final done = widget.set.done, scheme = Theme.of(context).colorScheme;
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final canComplete =
        done ||
        (!_kgInvalid &&
            !_resultInvalid &&
            widget.set.hasValidResult(
              isTimed: widget.isTimed,
              isDistance: widget.isDistance,
            ));
    final toggle = IconButton(
      tooltip: widget.isExpanded
          ? 'Contraer serie ${widget.set.index}'
          : 'Detalles de serie ${widget.set.index}',
      onPressed: widget.onToggleExpanded,
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.set.index}'),
          if (widget.onToggleExpanded != null)
            Icon(
              widget.isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 16,
            ),
        ],
      ),
    );
    final check = Checkbox(
      value: done,
      semanticLabel: 'Serie ${widget.set.index} completada',
      onChanged: canComplete ? (v) => widget.onChanged(done: v ?? false) : null,
    );
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: done
            ? scheme.primary.withValues(alpha: .12)
            : scheme.surfaceContainerHighest.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? scheme.primary : scheme.outlineVariant,
        ),
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
            if (!widget.isTimed && !widget.isDistance) ...[
              _loadField(),
              const SizedBox(height: 8),
            ],
            _resultField(),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                toggle,
                if (!widget.isTimed && !widget.isDistance) ...[
                  Expanded(child: _loadField()),
                  const SizedBox(width: 8),
                ],
                Expanded(child: _resultField()),
                check,
              ],
            ),
          const SizedBox(height: 6),
          Text(
            'Anterior: ${widget.set.previous?.labelFor(_units) ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.isExpanded) ...[
            const SizedBox(height: 12),
            if (!widget.isTimed && !widget.isDistance)
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
              if (!widget.isTimed &&
                  !widget.isDistance &&
                  !widget.isAssisted) ...[
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
