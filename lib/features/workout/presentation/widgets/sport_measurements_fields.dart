import 'package:flutter/material.dart';

import '../../domain/sport_activity.dart';
import '../../domain/training_units.dart';
import 'workout_units_host.dart';

class SportMeasurementsDraft {
  Map<SportMetric, String>? raw;
  String? position, notes;
  DistanceUnit? distanceUnit;
}

class SportMeasurementsFields extends StatefulWidget {
  const SportMeasurementsFields({
    super.key,
    required this.activity,
    required this.initial,
    required this.onChanged,
    this.draft,
    this.enabled = true,
  });
  final SportMeasurementsDraft? draft;
  final bool enabled;
  final FootballActivity activity;
  final SportMeasurements initial;
  final ValueChanged<SportMeasurements?> onChanged;
  @override
  State<SportMeasurementsFields> createState() =>
      _SportMeasurementsFieldsState();
}

class _SportMeasurementsFieldsState extends State<SportMeasurementsFields> {
  late Map<SportMetric, String> _raw;
  DistanceUnit? _unit;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = WorkoutUnits.of(context).distance;
    final previous = _unit ?? widget.draft?.distanceUnit ?? DistanceUnit.meters;
    if (_unit == null) {
      _raw = {
        ...?widget.draft?.raw,
        if (widget.draft?.raw == null)
          for (final e in widget.initial.values.entries) e.key: '${e.value}',
      };
    }
    if (next != previous) {
      final value = double.tryParse(
        (_raw[SportMetric.distanceMeters] ?? '').replaceAll(',', '.'),
      );
      if (value != null) {
        _raw[SportMetric.distanceMeters] =
            '${next.fromMeters(previous.toMeters(value))}';
      }
    }
    _unit = next;
    widget.draft?.distanceUnit = next;
  }

  late String _position = widget.draft?.position ?? widget.initial.position,
      _notes = widget.draft?.notes ?? widget.initial.notes;
  void _emit() {
    widget.draft?.raw = _raw;
    widget.draft?.position = _position;
    widget.draft?.notes = _notes;
    final values = <SportMetric, double>{};
    for (final e in _raw.entries) {
      if (e.value.trim().isEmpty) continue;
      final parsed = double.tryParse(e.value.replaceAll(',', '.'));
      if (parsed == null || !e.key.valid(parsed)) {
        widget.onChanged(null);
        return;
      }
      values[e.key] = e.key == SportMetric.distanceMeters
          ? _unit!.toMeters(parsed)
          : parsed;
    }
    widget.onChanged(
      SportMeasurements(values: values, position: _position, notes: _notes),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final metric in widget.activity.metrics)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            enabled: widget.enabled,
            key: ValueKey(
              '${metric.name}|${metric == SportMetric.distanceMeters ? _unit : ''}',
            ),
            initialValue: _raw[metric] ?? '',
            keyboardType: TextInputType.numberWithOptions(
              decimal: !metric.integer,
            ),
            decoration: InputDecoration(
              labelText: metric == SportMetric.distanceMeters
                  ? 'Distancia (${_unit!.label})'
                  : metric.label,
            ),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (raw) {
              if (raw?.trim().isEmpty != false) return null;
              final value = double.tryParse(raw!.replaceAll(',', '.'));
              return value != null && metric.valid(value)
                  ? null
                  : 'Ingresá un valor válido';
            },
            onChanged: (raw) {
              _raw[metric] = raw;
              _emit();
            },
          ),
        ),
      if (widget.activity.mode == FootballMode.competition)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            enabled: widget.enabled,
            initialValue: _position,
            decoration: const InputDecoration(labelText: 'Posición'),
            onChanged: (v) {
              _position = v;
              _emit();
            },
          ),
        ),
      TextFormField(
        enabled: widget.enabled,
        initialValue: _notes,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Observaciones y sensaciones',
        ),
        onChanged: (v) {
          _notes = v;
          _emit();
        },
      ),
    ],
  );
}
