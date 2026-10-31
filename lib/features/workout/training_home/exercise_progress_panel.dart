import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../presentation/widgets/workout_units_host.dart';
import '../presentation/widgets/workout_report_widgets.dart';

import 'package:intl/intl.dart';

import '../data/training_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import '../presentation/widgets/training_record_tile.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import '../domain/routine_labels.dart';
import '../domain/training_export.dart';
import '../presentation/training_export_screen.dart';
import '../presentation/workout_history_detail_screen.dart';
import '../pro/models/workout_models.dart';

class ExerciseProgressPanel extends StatefulWidget {
  const ExerciseProgressPanel({
    super.key,
    required this.exercise,
    required this.historyOnly,
    this.repository,
    this.library,
  });
  final WorkoutExercise exercise;
  final bool historyOnly;
  final WorkoutRepository? repository;
  final TrainingLibraryRepository? library;
  @override
  State<ExerciseProgressPanel> createState() => _ExerciseProgressPanelState();
}

class _ExerciseProgressPanelState extends State<ExerciseProgressPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  late final _repository = widget.repository ?? WorkoutRepository();
  late final _library = widget.library ?? TrainingLibraryRepository();
  late Future<TrainingPerformanceIndex> _data;
  final _note = TextEditingController();
  var _noteLoaded = false, _saving = false, _dirty = false;
  String? _noteError;
  bool _leaving = false;
  var _period = TrainingPeriod.all;
  var _metric = ExerciseMetric.load;
  String? _loadKey;
  int? _selected;
  var _limit = 50;
  @override
  void initState() {
    super.initState();
    _data = _repository.performanceIndex();
    _repository.historyRevision.addListener(_reload);
    if (!widget.historyOnly) _loadNote();
  }

  void _reload() {
    if (mounted) setState(() => _data = _repository.performanceIndex());
  }

  Future<void> _loadNote() async {
    try {
      final value = await _library.exerciseNote(widget.exercise.id);
      if (!mounted) return;
      setState(() {
        _note.text = value;
        _noteLoaded = true;
        _noteError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _noteError = 'No se pudo leer la nota. El original se conserva.',
        );
      }
    }
  }

  Future<void> _saveNote() async {
    if (_saving || !_noteLoaded) return;
    setState(() => _saving = true);
    try {
      await _library.saveExerciseNote(widget.exercise.id, _note.text);
      if (mounted) {
        setState(() {
          _dirty = false;
          _noteError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _noteError = 'No se pudo guardar la nota. Tu texto sigue disponible para reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _repository.historyRevision.removeListener(_reload);
    _note.dispose();
    super.dispose();
  }

  void _open(ExerciseObservation o) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WorkoutHistoryDetailScreen(
        sessionId: o.report.session.id,
        repository: _repository,
      ),
    ),
  );

  Future<void> _requestLeave() async {
    if (_leaving || _saving) return;
    _leaving = true;
    try {
      final action = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Nota sin guardar'),
          content: const Text(
            'Guardá tu nota permanente antes de salir o descartá la edición.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, 'cancel'),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, 'discard'),
              child: const Text('Descartar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, 'save'),
              child: const Text('Guardar y salir'),
            ),
          ],
        ),
      );
      if (!mounted || action == null || action == 'cancel') return;
      if (action == 'save') {
        await _saveNote();
        if (_dirty || !mounted) return;
      } else {
        setState(() => _dirty = false);
      }
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop();
    } finally {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestLeave();
      },
      child: FutureBuilder<TrainingPerformanceIndex>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _reload,
                child: const Text('No se pudo cargar el progreso. Reintentar'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final index = snapshot.data!;
          final all = index.exerciseHistory(widget.exercise.id);
          final variants = <String, String>{
            for (final o in all) o.loadKey: o.label,
          };
          final selectedKey = variants.containsKey(_loadKey)
              ? _loadKey!
              : variants.keys.firstOrNull;
          final history = index.exerciseHistory(
            widget.exercise.id,
            period: _period,
            loadKey: selectedKey,
          );
          final available = ExerciseMetric.values
              .where((m) => history.any((o) => o.value(m) != null))
              .toList();
          final metric = available.contains(_metric)
              ? _metric
              : available.firstOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          RoutineLabels.exerciseName(widget.exercise.name),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          RoutineLabels.equipmentName(
                            widget.exercise.equipment ??
                                WorkoutAnalytics.definition(widget.exercise)
                                    ?.equipment,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExerciseThumbnail(exercise: widget.exercise, size: 80),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    widget.historyOnly ? 'Tus sesiones' : 'Tu progreso',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  DropdownButton<TrainingPeriod>(
                    isExpanded: true,
                    itemHeight: null,
                    value: _period,
                    items: [
                      for (final p in TrainingPeriod.values)
                        DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) {
                      if (p != null) {
                        setState(() {
                          _period = p;
                          _selected = null;
                          _limit = 50;
                        });
                      }
                    },
                  ),
                ],
              ),
              if (variants.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: selectedKey,
                  key: ValueKey(selectedKey),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de carga comparable',
                  ),
                  items: [
                    for (final v in variants.entries)
                      DropdownMenuItem(
                        value: v.key,
                        child: Text(
                          v.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _loadKey = v;
                    _selected = null;
                  }),
                ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Todavía no hay series completadas y verificables de este ejercicio en el período. Los registros antiguos sin confirmación siguen disponibles en el historial general.',
                  ),
                )
              else if (widget.historyOnly) ...[
                Text(
                  '${history.map((o) => o.report.session.id).toSet().length} sesiones registradas',
                ),
                for (final o in history.take(_limit)) _historyCard(o),
                if (history.length > _limit)
                  TextButton(
                    onPressed: () => setState(() => _limit += 50),
                    child: const Text('Ver 50 registros más'),
                  ),
              ] else ...[
                if (metric != null) ...[
                  DropdownButtonFormField<ExerciseMetric>(
                    key: ValueKey(metric),
                    initialValue: metric,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Métrica'),
                    items: [
                      for (final m in available)
                        DropdownMenuItem(value: m, child: Text(m.label)),
                    ],
                    onChanged: (m) {
                      if (m != null) {
                        setState(() {
                          _metric = m;
                          _selected = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (metric == ExerciseMetric.estimatedMax)
                    const Text(
                      'Estimación Epley: carga × (1 + reps/30), solo 1–10 repeticiones. Una repetición conserva su carga. Excluye lastre, asistencia y RIR mayor que cero. No equivale a un máximo medido.',
                    ),
                  _chart(history, metric),
                ],
                const SizedBox(height: 24),
                Text(
                  'Récords personales',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Marcas vigentes de toda tu historia; tocá una para abrir su sesión de origen.',
                ),
                for (final r in index.records.where(
                  (r) =>
                      r.exerciseId == widget.exercise.id &&
                      r.loadKey == selectedKey &&
                      r.kind != RecordKind.repLoad,
                ))
                  TrainingRecordTile(record: r, repository: _repository),
                ExpansionTile(
                  title: const Text('Mejores cargas por repeticiones'),
                  subtitle: const Text(
                    'Solo resultados observados, sin interpolaciones',
                  ),
                  children: [
                    for (final r
                        in (index.records
                            .where(
                              (r) =>
                                  r.exerciseId == widget.exercise.id &&
                                  r.loadKey == selectedKey &&
                                  r.kind == RecordKind.repLoad,
                            )
                            .toList()
                          ..sort((a, b) => a.reps!.compareTo(b.reps!))))
                      TrainingRecordTile(record: r, repository: _repository),
                  ],
                ),
                if (history.length >= 2) _comparison(history[0], history[1]),
              ],
              if (!widget.historyOnly) ...[
                const SizedBox(height: 24),
                Text(
                  'Nota permanente del ejercicio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Privada y exclusiva de esta cuenta. Independiente de las notas de rutina, sesión y serie.',
                ),
                const SizedBox(height: 8),
                if (_noteError != null)
                  Text(
                    _noteError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (!_noteLoaded && _noteError != null)
                  TextButton(
                    onPressed: _loadNote,
                    child: const Text('Reintentar lectura'),
                  ),
                TextField(
                  controller: _note,
                  enabled: _noteLoaded && !_saving,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Tu nota',
                    hintText: 'Ajustes personales que querés recordar',
                  ),
                  onChanged: (_) => setState(() => _dirty = true),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _dirty && !_saving ? _saveNote : null,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(
                      _saving
                          ? 'Guardando…'
                          : _dirty
                          ? 'Guardar nota'
                          : 'Nota guardada',
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _historyCard(ExerciseObservation o) => Card(
    child: ExpansionTile(
      title: Text(
        DateFormat.yMMMd('es').format(o.report.session.date.toLocal()),
      ),
      subtitle: Text('${o.sets.length} series · ${o.label}'),
      children: [
        for (final s in o.sets)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${workoutSetLabel(o.sets.indexOf(s) + 1, o.exercise, s, WorkoutUnits.of(context))}${s.note?.isNotEmpty == true ? ' · ${s.note}' : ''}',
              ),
            ),
          ),
        TextButton(
          onPressed: () => _open(o),
          child: const Text('Abrir sesión completa'),
        ),
      ],
    ),
  );

  Widget _comparison(
    ExerciseObservation current,
    ExerciseObservation previous,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Últimas dos sesiones comparables',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${DateFormat.yMd('es').format(previous.report.session.date.toLocal())} → ${DateFormat.yMd('es').format(current.report.session.date.toLocal())}',
          ),
          for (final m in [
            ExerciseMetric.load,
            ExerciseMetric.sessionVolume,
            ExerciseMetric.repetitions,
            ExerciseMetric.sets,
            ExerciseMetric.duration,
          ])
            if (current.value(m) != null && previous.value(m) != null)
              Text(
                '${m.label}: ${WorkoutUnits.of(context).valueWithUnit(m.unit, previous.value(m)!)} → ${WorkoutUnits.of(context).valueWithUnit(m.unit, current.value(m)!)}',
              ),
        ],
      ),
    ),
  );

  Widget _chart(List<ExerciseObservation> history, ExerciseMetric metric) {
    final units = WorkoutUnits.of(context);
    final points = <_ProgressPoint>[];
    if (metric == ExerciseMetric.frequency) {
      final weeks = <DateTime, List<ExerciseObservation>>{};
      for (final o in history.reversed) {
        final d = o.report.session.date.toLocal();
        final monday = DateTime(d.year, d.month, d.day - d.weekday + 1);
        weeks.putIfAbsent(monday, () => []).add(o);
      }
      for (final entry in weeks.entries) {
        points.add(
          _ProgressPoint(
            entry.key,
            entry.value
                .map((o) => o.report.session.id)
                .toSet()
                .length
                .toDouble(),
            entry.value,
          ),
        );
      }
    } else {
      for (final o in history.reversed) {
        if (o.value(metric) case final value?) {
          points.add(
            _ProgressPoint(
              o.report.session.date.toLocal(),
              units.metricValue(metric.unit, value),
              [o],
            ),
          );
        }
      }
    }
    if (points.isEmpty) {
      return const Text('Sin datos comparables para esta métrica.');
    }
    final selected = _selected != null && _selected! < points.length
        ? points[_selected!]
        : points.last;
    // Bound painting cost without hiding exact history: the graph samples evenly;
    // the accessible table below retains every observed value with pagination.
    final plotted = points.length <= 120
        ? [for (var i = 0; i < points.length; i++) i]
        : [
            for (var i = 0; i < 120; i++)
              (i * (points.length - 1) / 119).round(),
          ];
    final origin = DateTime.utc(
      points.first.date.year,
      points.first.date.month,
      points.first.date.day,
    );
    double xFor(_ProgressPoint p) => DateTime.utc(
      p.date.year,
      p.date.month,
      p.date.day,
    ).difference(origin).inDays.toDouble();
    final span = xFor(points.last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrainingExportScreen(
                  data: TrainingExportData(
                    kind: 'EVOLUCIÓN',
                    metricLabel:
                        '${metric.label} · ${units.metricUnit(metric.unit)}',
                    points: [
                      for (final i in plotted)
                        TrainingExportPoint(points[i].date, points[i].value),
                    ],
                    sections: [
                      TrainingExportSection('name', 'Ejercicio', [
                        RoutineLabels.exerciseName(widget.exercise.name),
                      ]),
                      TrainingExportSection('period', 'Período', [
                        _period.label,
                        history.first.label,
                      ]),
                      TrainingExportSection('metrics', metric.label, [
                        '${trainingNumber(selected.value)} ${units.metricUnit(metric.unit)} · ${DateFormat.yMd('es').format(selected.date)}',
                      ]),
                      TrainingExportSection('evolution', 'Gráfico', [
                        '${points.length} resultados observados${points.length > 120 ? ' · gráfico reducido a 120 muestras' : ''}',
                      ]),
                    ],
                  ),
                ),
              ),
            ),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Crear tarjeta de evolución'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${trainingNumber(selected.value)} ${units.metricUnit(metric.unit)}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          '${metric == ExerciseMetric.frequency ? 'Semana del ' : ''}${DateFormat.yMMMd('es').format(selected.date)}',
        ),
        const SizedBox(height: 16),
        Semantics(
          label:
              'Gráfico de ${metric.label}. Valores exactos disponibles debajo.',
          child: SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: span <= 0 ? 1 : span,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (final i in plotted)
                        FlSpot(xFor(points[i]), points[i].value),
                    ],
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    isCurved: false,
                    dotData: FlDotData(show: points.length < 20),
                  ),
                ],
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        NumberFormat.compact(locale: 'es').format(value),
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: (span / 3).ceilToDouble().clamp(
                        1,
                        double.infinity,
                      ),
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat.MMMd('es').format(
                            DateTime(
                              origin.year,
                              origin.month,
                              origin.day + value.round(),
                            ),
                          ),
                          style: Theme.of(context).textTheme.labelSmall,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent &&
                        response?.lineBarSpots?.isNotEmpty == true) {
                      setState(
                        () => _selected =
                            plotted[response!.lineBarSpots!.first.spotIndex],
                      );
                    }
                  },
                ),
              ),
              duration: Duration.zero,
            ),
          ),
        ),
        Text(
          metric == ExerciseMetric.frequency
              ? 'Sesiones por semana calendario. Última semana posiblemente parcial.'
              : 'Sesiones en orden cronológico. Tocá un punto para seleccionarlo.',
        ),
        if (points.length > 120)
          const Text(
            'Gráfico reducido a 120 muestras equidistantes. La tabla conserva todos los valores.',
          ),
        for (final o in selected.observations)
          TextButton(
            onPressed: () => _open(o),
            child: Text(
              'Abrir sesión · ${DateFormat.yMd('es').format(o.report.session.date.toLocal())}',
            ),
          ),
        ExpansionTile(
          title: const Text('Tabla de valores exactos'),
          children: [
            for (final p in points.reversed.take(_limit))
              ListTile(
                title: Text(DateFormat.yMd('es').format(p.date)),
                subtitle: Text(
                  '${trainingNumber(p.value)} ${units.metricUnit(metric.unit)}',
                ),
                onTap: () => setState(() => _selected = points.indexOf(p)),
              ),
            if (points.length > _limit)
              TextButton(
                onPressed: () => setState(() => _limit += 50),
                child: const Text('Ver 50 valores más'),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProgressPoint {
  const _ProgressPoint(this.date, this.value, this.observations);
  final DateTime date;
  final double value;
  final List<ExerciseObservation> observations;
}
