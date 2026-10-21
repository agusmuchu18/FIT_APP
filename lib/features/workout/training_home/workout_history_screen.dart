import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/account_storage_scope.dart';
import '../../common/theme/app_layout.dart';
import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import '../presentation/widgets/workout_report_widgets.dart';
import '../presentation/widgets/workout_units_host.dart';
import '../presentation/workout_history_detail_screen.dart';
import '../presentation/workout_insights_screen.dart';
export '../presentation/workout_history_detail_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key, this.repository, this.now});
  final WorkoutRepository? repository;
  final DateTime? now;
  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  late final WorkoutRepository _repository =
      widget.repository ?? WorkoutRepository();
  final String _scope = AccountStorageScope.current;
  ScopedPreferences? _prefs;
  WorkoutHistoryPeriod _period = WorkoutHistoryPeriod.month;
  List<WorkoutReport> _source = [];
  WorkoutHistoryReport? _report;
  List<Object> _rows = [];
  Object? _error;
  bool _loading = true;
  static const labels = ['7 días', '30 días', '3 meses', 'Todo'];
  int _loadGeneration = 0;
  @override
  void initState() {
    super.initState();
    _repository.historyRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _repository.historyRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    try {
      final prefs = await ScopedPreferences.getInstance(scope: _scope);
      final saved = prefs.getString('workout_history_period');
      _period = WorkoutHistoryPeriod.values.firstWhere(
        (p) => p.name == saved,
        orElse: () => WorkoutHistoryPeriod.month,
      );
      final sessions = await _repository.listAllSessions();
      if (!mounted || generation != _loadGeneration) return;
      _prefs = prefs;
      _source = sessions.map(WorkoutReport.new).toList(growable: false);
      setState(() {
        _error = null;
        _loading = false;
        _aggregate();
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _aggregate() {
    _report = WorkoutHistoryReport(
      source: _source,
      period: _period,
      now: widget.now ?? DateTime.now(),
    );
    final rows = <Object>[];
    String? month;
    for (final report in _report!.sessions) {
      final date = report.session.date.toLocal();
      final key = '${date.year}-${date.month}';
      if (month != key) {
        rows.add(workoutMonth(date));
        month = key;
      }
      rows.add(report);
    }
    _rows = rows;
  }

  Future<void> _filter(WorkoutHistoryPeriod period) async {
    try {
      await _prefs?.setString('workout_history_period', period.name);
      if (mounted) {
        setState(() {
          _period = period;
          _aggregate();
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el filtro. Reintentá.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Análisis, músculos y calendario',
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WorkoutInsightsScreen(
                  repository: _repository,
                  now: widget.now,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) return const Center(child: CircularProgressIndicator());
          if (_error != null) {
            return Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Text('No se pudo cargar el historial. Reintentar'),
              ),
            );
          }
          final report = _report!;
          return RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final p in WorkoutHistoryPeriod.values)
                              ChoiceChip(
                                label: Text(labels[p.index]),
                                selected: p == _period,
                                onSelected: (_) => _filter(p),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (_repository.unreadableHistoryRows > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg,
                            ),
                            child: Text(
                              '${_repository.unreadableHistoryRows} registros antiguos no se pudieron leer. Se conservaron sin cambios.',
                            ),
                          ),
                        if (report.sessions.isNotEmpty) ...[
                          WorkoutMetricGrid(
                            metrics: [
                              ('Sesiones', '${report.sessions.length}'),
                              (
                                'Volumen externo',
                                (WorkoutUnits.of(context).valueWithUnit(
                                  'kg·rep',
                                  report.externalVolume,
                                )),
                              ),
                              (
                                'Duración registrada',
                                report.missingDurations ==
                                        report.sessions.length
                                    ? 'Sin registro'
                                    : workoutDuration(report.duration),
                              ),
                              (
                                'Sesiones / semana',
                                workoutNumber(report.weeklyFrequency),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Frecuencia: ${report.sessions.length} sesiones × 7 / ${report.periodDays} días calendario.',
                          ),
                          Text(
                            'Volumen: suma de ${WorkoutUnits.of(context).weight.label} externos × repeticiones de series válidas; excluye peso corporal y asistencia.',
                          ),
                          if (report.missingDurations > 0)
                            Text(
                              '${report.missingDurations} sesiones sin duración: no se incluyen en el total de tiempo.',
                            ),
                          if (report.mixedDurationKinds)
                            const Text(
                              'El total incluye duraciones declaradas y tiempos sin pausas. No equivale a tiempo efectivo de ejercicio.',
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          _HistoryChart(activity: report.activity),
                          const SizedBox(height: AppSpacing.xl),
                        ] else ...[
                          const SizedBox(height: AppSpacing.xl),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppShape.card),
                            child: const SizedBox(
                              height: 96,
                              width: double.infinity,
                              child: WorkoutArtwork(empty: true),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _source.isEmpty
                                ? 'Tu historial empieza con tu próxima sesión'
                                : 'Sin entrenamientos en este período',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _source.isEmpty
                                ? 'Al guardar un entrenamiento verás aquí tus sesiones, volumen y frecuencia.'
                                : 'Probá otro filtro para consultar los registros disponibles.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: _source.isEmpty
                                ? () =>
                                      Navigator.of(context)
                                          .pushNamed('/workout')
                                : () => _filter(WorkoutHistoryPeriod.all),
                            child: Text(
                              _source.isEmpty
                                  ? 'Empezar entrenamiento'
                                  : 'Ver todo el historial',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  sliver: SliverList.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      if (row is String) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.lg,
                            bottom: AppSpacing.md,
                          ),
                          child: Text(
                            row,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        );
                      }
                      final session = row as WorkoutReport;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppShape.card),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              settings: RouteSettings(
                                name: '/workout/detail',
                                arguments: session.session.id,
                              ),
                              builder: (_) => WorkoutHistoryDetailScreen(
                                sessionId: session.session.id,
                                repository: _repository,
                              ),
                            ),
                          ),
                          child: ReportPanel(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppShape.small,
                                  ),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: WorkoutArtwork(
                                      category: session.artCategory,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(workoutDate(session.session.date)),
                                      Text(
                                        '${workoutDuration(session.duration)} · ${session.recordedExercises} ejercicios · ${session.performedSets} series',
                                      ),
                                      if (session.externalVolume > 0)
                                        Text(
                                          '${WorkoutUnits.of(context).valueWithUnit('kg·rep', session.externalVolume)} externos',
                                        ),
                                      if (session.mainMuscles.isNotEmpty)
                                        Text(session.mainMuscles.join(' · ')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.activity});
  final List<WeeklyWorkoutActivity> activity;
  @override
  Widget build(BuildContext context) => ReportPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad semanal',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Sesiones guardadas por semana · lunes a domingo'),
        const SizedBox(height: AppSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: activity.length > 8
                ? activity.length * 48.0
                : MediaQuery.sizeOf(context).width - 64,
            height: 160,
            child: Semantics(
              label: activity
                  .map(
                    (w) =>
                        'Semana ${DateFormat('dd/MM').format(w.monday)}: ${w.sessions} sesiones',
                  )
                  .join('. '),
              child: ExcludeSemantics(
                child: BarChart(
                  BarChartData(
                    minY: 0,
                    maxY:
                        (activity.fold<int>(
                                  0,
                                  (v, w) => w.sessions > v ? w.sessions : v,
                                ) +
                                1)
                            .toDouble(),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          maxIncluded: false,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            return Text(
                              i >= 0 && i < activity.length
                                  ? DateFormat('dd/MM')
                                        .format(activity[i].monday)
                                  : '',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < activity.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: activity[i].sessions.toDouble(),
                              width: 14,
                              borderRadius: BorderRadius.circular(
                                AppShape.small,
                              ),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppVisual.motionNormal,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
