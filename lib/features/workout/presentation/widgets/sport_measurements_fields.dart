import 'package:flutter/material.dart';

import '../../domain/sport_activity.dart';

class SportMeasurementsFields extends StatefulWidget {
  const SportMeasurementsFields({
    super.key,
    required this.activity,
    required this.initial,
    required this.onChanged,
  });
  final FootballActivity activity;
  final SportMeasurements initial;
  final ValueChanged<SportMeasurements?> onChanged;
  @override
  State<SportMeasurementsFields> createState() =>
      _SportMeasurementsFieldsState();
}

class _SportMeasurementsFieldsState extends State<SportMeasurementsFields> {
  late final Map<SportMetric, String> _raw = {
    for (final e in widget.initial.values.entries) e.key: '${e.value}',
  };
  late String _position = widget.initial.position,
      _notes = widget.initial.notes;
  void _emit() {
    final values = <SportMetric, double>{};
    for (final e in _raw.entries) {
      if (e.value.trim().isEmpty) continue;
      final parsed = double.tryParse(e.value.replaceAll(',', '.'));
      if (parsed == null || !e.key.valid(parsed)) {
        widget.onChanged(null);
        return;
      }
      values[e.key] = parsed;
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
            key: ValueKey(metric),
            initialValue: _raw[metric] ?? '',
            keyboardType: TextInputType.numberWithOptions(
              decimal: !metric.integer,
            ),
            decoration: InputDecoration(labelText: metric.label),
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
            initialValue: _position,
            decoration: const InputDecoration(labelText: 'Posición'),
            onChanged: (v) {
              _position = v;
              _emit();
            },
          ),
        ),
      TextFormField(
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
