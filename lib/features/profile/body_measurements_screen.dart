import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data/account_storage_scope.dart';
import '../common/theme/app_colors.dart';
import '../workout/data/workout_preferences.dart';
import '../workout/domain/training_units.dart';
import 'body_measurement.dart';
import 'body_measurement_form.dart';
import 'data/body_measurement_repository.dart';

class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key, this.repository, this.now});
  final BodyMeasurementRepository? repository;
  final DateTime? now;
  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  late final _repository = widget.repository ?? BodyMeasurementRepository();
  List<BodyMeasurement> _records = [];
  var _metric = BodyMetric.weight;
  var _days = 90, _visible = 30;
  var _loading = true, _busy = false;
  String? _error, _fromId, _toId;
  var _lengthUnit = 'cm';
  var _weight = WeightUnit.kg;
  @override
  void initState() {
    super.initState();
    _load();
  }

  String _unit(BodyMetric metric) => switch (metric.unit) {
    'kg' => _weight.label,
    'cm' => _lengthUnit,
    _ => '%',
  };
  String _number(BodyValue value) =>
      TrainingUnits.number(value.inUnit(_unit(_metric)));
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _repository.records();
      final prefs = await ScopedPreferences.getInstance(
        scope: _repository.owner,
      );
      final units = await WorkoutPreferences.load(scope: _repository.owner);
      final length = prefs.getString('body.length_unit.v1') ?? 'cm';
      if (length != 'cm' && length != 'in') {
        throw const FormatException('Unidad inválida');
      }
      if (_repository.owner != AccountStorageScope.current) {
        throw StateError('Cuenta cambiada');
      }
      if (mounted) {
        setState(() {
          _records = records;
          _weight = units.units.weight;
          _lengthUnit = length;
          _fromId = _toId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo leer tu historial. Los datos se conservan. Reintentá con la misma cuenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeLength(String? unit) async {
    if (unit == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final prefs = await ScopedPreferences.getInstance(
        scope: _repository.owner,
      );
      if (_repository.owner != AccountStorageScope.current) {
        throw StateError('Cuenta cambiada');
      }
      await prefs.setString('body.length_unit.v1', unit);
      if (mounted && _repository.owner == AccountStorageScope.current) {
        setState(() => _lengthUnit = unit);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo guardar la unidad. Reintentá.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([BodyMeasurement? record]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BodyMeasurementForm(
          repository: _repository,
          unitFor: _unit,
          existing: record,
          recentFields: _records.isEmpty
              ? const [BodyMetric.weight, BodyMetric.waist]
              : _records.first.values.keys,
          now: widget.now,
        ),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _delete(BodyMeasurement record) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este registro?'),
        content: Text(
          'Se eliminarán las medidas del ${DateFormat('dd/MM/yyyy').format(record.date)} de este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.delete(record.id, expectedRevision: record.revision);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo eliminar. Reintentá.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<BodyMeasurement> get _series {
    final now = DateUtils.dateOnly(widget.now ?? DateTime.now());
    final cutoff = DateTime(now.year, now.month, now.day - _days + 1);
    return _records
        .where(
          (r) =>
              r.values.containsKey(_metric) &&
              (_days == 0 || !r.date.isBefore(cutoff)) &&
              !r.date.isAfter(now),
        )
        .toList()
        .reversed
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final series = _series;
    final from =
        series.where((r) => r.id == _fromId).firstOrNull ?? series.firstOrNull;
    final to =
        series.where((r) => r.id == _toId).firstOrNull ?? series.lastOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Medidas corporales')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando medidas',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline),
                  title: Text('Tu progreso, en privado'),
                  subtitle: Text(
                    'Solo vos · datos locales en este dispositivo',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Semantics(liveRegion: true, child: Text(_error!)),
                  TextButton(
                    onPressed: _busy ? null : _load,
                    child: const Text('Reintentar'),
                  ),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _busy || _error != null ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar medidas'),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<BodyMetric>(
                  initialValue: _metric,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Medida'),
                  items: [
                    for (final m in BodyMetric.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _metric = v;
                        _fromId = _toId = null;
                        _visible = 30;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _days,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('Últimos 30 días')),
                    DropdownMenuItem(value: 90, child: Text('Últimos 90 días')),
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Todo el historial'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _days = v;
                        _fromId = _toId = null;
                        _visible = 30;
                      });
                    }
                  },
                ),
                if (_metric.unit == 'cm') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_lengthUnit),
                    initialValue: _lengthUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unidad de perímetros',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'cm',
                        child: Text('Centímetros (cm)'),
                      ),
                      DropdownMenuItem(
                        value: 'in',
                        child: Text('Pulgadas (in)'),
                      ),
                    ],
                    onChanged: _busy ? null : _changeLength,
                  ),
                ],
                const SizedBox(height: 24),
                if (series.isEmpty)
                  const Text(
                    'Todavía no hay registros de esta medida en el período elegido.',
                  ),
                if (series.isNotEmpty) ...[
                  Text(
                    '${_metric.label} · ${_unit(_metric)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _BodyTrend(
                    series: series,
                    metric: _metric,
                    unit: _unit(_metric),
                  ),
                  if (series.length > 1)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Comparar dos registros'),
                      subtitle: Text(
                        '${DateFormat('dd/MM/yy').format(from!.date)} → ${DateFormat('dd/MM/yy').format(to!.date)}: '
                        '${TrainingUnits.number(to.values[_metric]!.inUnit(_unit(_metric)) - from.values[_metric]!.inUnit(_unit(_metric)))} ${_unit(_metric)}',
                      ),
                      children: [
                        for (final start in [true, false])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(
                                '${_metric.name}:$_days:$start:${start ? from.id : to.id}',
                              ),
                              initialValue: start ? from.id : to.id,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: start ? 'Desde' : 'Hasta',
                              ),
                              items: [
                                for (final r in series)
                                  DropdownMenuItem(
                                    value: r.id,
                                    child: Text(
                                      '${DateFormat('dd/MM/yyyy').format(r.date)} · ${_number(r.values[_metric]!)} ${_unit(_metric)}',
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() {
                                if (start) {
                                  _fromId = v;
                                } else {
                                  _toId = v;
                                }
                              }),
                            ),
                          ),
                        const Text(
                          'Diferencia entre los registros elegidos; no es una valoración de salud.',
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Historial',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (final record in series.reversed.take(_visible))
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_number(record.values[_metric]!)} ${_unit(_metric)}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '${DateFormat('dd/MM/yyyy').format(record.date)} · Manual',
                            ),
                            if (record.values[_metric]!.unit != _unit(_metric))
                              Text(
                                'Original: ${TrainingUnits.number(record.values[_metric]!.value)} ${record.values[_metric]!.unit}',
                              ),
                            if (record.notes.isNotEmpty) Text(record.notes),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: _busy || _error != null
                                      ? null
                                      : () => _edit(record),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Editar'),
                                ),
                                TextButton.icon(
                                  onPressed: _busy || _error != null
                                      ? null
                                      : () => _delete(record),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (series.length > _visible)
                    TextButton(
                      onPressed: () => setState(() => _visible += 30),
                      child: const Text('Ver más registros'),
                    ),
                ],
              ],
            ),
    );
  }
}

class _BodyTrend extends StatelessWidget {
  const _BodyTrend({
    required this.series,
    required this.metric,
    required this.unit,
  });
  final List<BodyMeasurement> series;
  final BodyMetric metric;
  final String unit;
  @override
  Widget build(BuildContext context) {
    // Calendar components avoid DST shifts; x is elapsed calendar days, not
    // evenly spaced samples that would misrepresent irregular measurements.
    double day(DateTime d) =>
        DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch /
        Duration.millisecondsPerDay;
    final spots = [
      for (final r in series)
        FlSpot(day(r.date), r.values[metric]!.inUnit(unit)),
    ];
    final reduced = MediaQuery.disableAnimationsOf(context);
    final low = spots.map((s) => s.y).reduce(math.min);
    final high = spots.map((s) => s.y).reduce(math.max);
    final padding = high == low
        ? math.max(high.abs() * .05, .5)
        : (high - low) * .1;
    return Semantics(
      label:
          'Tendencia de ${metric.label}. Los valores exactos y fechas están en el historial.',
      child: SizedBox(
        height: 200,
        child: ExcludeSemantics(
          child: LineChart(
            LineChartData(
              minX: spots.first.x - .5,
              maxX: spots.last.x + .5,
              minY: math.max(0, low - padding),
              maxY: high + padding,
              titlesData: const FlTitlesData(show: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      Theme.of(context).colorScheme.inverseSurface,
                  getTooltipItems: (touched) => [
                    for (final spot in touched)
                      LineTooltipItem(
                        '${DateFormat('dd/MM/yyyy').format(series[spot.spotIndex].date)}\n${TrainingUnits.number(spot.y)} $unit',
                        Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
  }
}
