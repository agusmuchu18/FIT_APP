import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/data/repositories.dart';
import '../../core/data/statistics_service.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';

class AnalyticsOverviewScreen extends StatefulWidget {
  const AnalyticsOverviewScreen({super.key, this.nutritionOnly = false});
  final bool nutritionOnly;

  @override
  State<AnalyticsOverviewScreen> createState() =>
      _AnalyticsOverviewScreenState();
}

class _AnalyticsOverviewScreenState extends State<AnalyticsOverviewScreen> {
  late FitnessRepository _repository;
  int _nutritionDays = 7;
  late Future<_AnalyticsOverviewData> _dataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = RepositoryScope.of(context);
    _dataFuture = _loadData();
  }

  Future<_AnalyticsOverviewData> _loadData() async {
    final nutritionHistory = await _repository.getWeeklyNutritionStats(
      days: _nutritionDays,
    );
    final macroTotals = await _repository.getMacroDistribution(
      days: _nutritionDays,
    );
    final sleepEntries = widget.nutritionOnly
        ? <SleepEntry>[]
        : await _repository.getRecentSleep();
    final workoutByDay = widget.nutritionOnly
        ? <DateTime, int>{}
        : await _repository.getWorkoutDurationByDay();

    final sleepByDay = _aggregateSleepByDay(sleepEntries);

    return _AnalyticsOverviewData(
      nutritionHistory: nutritionHistory,
      nutritionDays: _nutritionDays,
      macroTotals: macroTotals,
      sleepByDay: sleepByDay,
      workoutByDay: workoutByDay,
    );
  }

  Map<DateTime, double> _aggregateSleepByDay(List<SleepEntry> entries) {
    final map = <DateTime, double>{};
    for (final entry in entries) {
      final date = _dateOnly(DateTime.tryParse(entry.id) ?? DateTime.now());
      map[date] = (map[date] ?? 0) + entry.hours;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => setState(() => _dataFuture = _loadData()),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_AnalyticsOverviewData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'No se pudo cargar la vista de datos',
                      style: textTheme.titleMedium,
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => setState(() => _dataFuture = _loadData()),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SectionHeader(
                    title: 'Calorías y macros',
                    subtitle:
                        'Últimos ${data.nutritionDays} días de energía y macronutrientes registrados.',
                  ),
                  if (widget.nutritionOnly)
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _nutritionDays,
                      decoration: const InputDecoration(labelText: 'Período'),
                      items: [
                        for (final days in const [7, 30, 90])
                          DropdownMenuItem(
                            value: days,
                            child: Text('Últimos $days días'),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _nutritionDays = v;
                            _dataFuture = _loadData();
                          });
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  _WeeklyCaloriesChart(data: data),
                  const SizedBox(height: 12),
                  if (data.nutritionHistory.any(
                    (m) => m.unknownNutrients.any((n) => n != 'kcal'),
                  ))
                    const Text(
                      'Macronutrientes incompletos: consultá los registros originales.',
                    )
                  else
                    _MacroPieChart(macroTotals: data.macroTotals),
                  if (!widget.nutritionOnly) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Sueño',
                      subtitle: 'Horas registradas cada día.',
                    ),
                    const SizedBox(height: 12),
                    _SleepChart(data: data),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Entrenamiento',
                      subtitle: 'Resumen de minutos entrenados en la semana.',
                    ),
                    const SizedBox(height: 12),
                    _WorkoutSummaryCard(data: data),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _AnalyticsOverviewData {
  const _AnalyticsOverviewData({
    required this.nutritionHistory,
    this.nutritionDays = 7,
    required this.macroTotals,
    required this.sleepByDay,
    required this.workoutByDay,
  });

  final List<NutritionMetrics> nutritionHistory;
  final int nutritionDays;
  final Macros macroTotals;
  final Map<DateTime, double> sleepByDay;
  final Map<DateTime, int> workoutByDay;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: textTheme.bodyMedium),
      ],
    );
  }
}

class _WeeklyCaloriesChart extends StatelessWidget {
  const _WeeklyCaloriesChart({required this.data});
  final _AnalyticsOverviewData data;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      data.nutritionDays,
      (i) =>
          DateTime(now.year, now.month, now.day - data.nutritionDays + 1 + i),
    );
    final byDay = {
      for (final m in data.nutritionHistory)
        DateTime(m.date.year, m.date.month, m.date.day): m,
    };
    final known = byDay.values
        .where((m) => !m.unknownNutrients.contains('kcal'))
        .toList();
    final max = known.fold<int>(
      0,
      (v, m) => m.totalCalories > v ? m.totalCalories : v,
    );
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calorías por día',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Consultá la tabla para distinguir cero, dato ausente y día sin registro.',
            ),
            Text(
              '${days.first.day}/${days.first.month}/${days.first.year} – ${days.last.day}/${days.last.month}/${days.last.year}',
            ),
            if (days.length > 7 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5)
              const Text(
                'Deslizá el gráfico horizontalmente para ver todos los días.',
              ),
            const SizedBox(height: 16),
            if (known.isEmpty)
              const Text(
                'Todavía no hay valores de energía disponibles para este período.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width:
                        constraints.maxWidth >
                            days.length *
                                (days.length <= 7 ? 30 : 60) *
                                MediaQuery.textScalerOf(context).scale(1)
                        ? constraints.maxWidth
                        : days.length *
                              (days.length <= 7 ? 30 : 60) *
                              MediaQuery.textScalerOf(context).scale(1),
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        minY: 0,
                        maxY: max == 0 ? 1 : null,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(enabled: true),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= days.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    days.length <= 7
                                        ? '${days[i].day}'
                                        : '${days[i].day}/${days[i].month}',
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < days.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods:
                                  byDay[days[i]] == null ||
                                      byDay[days[i]]!.unknownNutrients.contains(
                                        'kcal',
                                      )
                                  ? []
                                  : [
                                      BarChartRodData(
                                        toY: byDay[days[i]]!.totalCalories
                                            .toDouble(),
                                        color: colors.primary,
                                        width: 16,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Valores exactos y días sin registro'),
              children: [
                for (final d in days)
                  ListTile(
                    dense: true,
                    title: Text('${d.day}/${d.month}/${d.year}'),
                    trailing: Text(
                      byDay[d] == null
                          ? 'Sin registro'
                          : byDay[d]!.unknownNutrients.contains('kcal')
                          ? '— kcal'
                          : '${byDay[d]!.totalCalories} kcal',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPieChart extends StatelessWidget {
  const _MacroPieChart({required this.macroTotals});
  final Macros macroTotals;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final values = [macroTotals.carbs, macroTotals.protein, macroTotals.fat];
    final total = values.fold(0, (s, n) => s + n);
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin macronutrientes registrados en este período.'),
        ),
      );
    }
    final colors = [scheme.primary, scheme.secondary, scheme.tertiary];
    final ink = [scheme.onPrimary, scheme.onSecondary, scheme.onTertiary];
    const names = ['Carbohidratos', 'Proteínas', 'Grasas'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución de macronutrientes',
              style: theme.textTheme.titleMedium,
            ),
            const Text(
              'Proporción de los gramos registrados, no del aporte energético.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 40,
                      sectionsSpace: 4,
                      sections: [
                        for (var i = 0; i < 3; i++)
                          if (values[i] > 0)
                            PieChartSectionData(
                              value: values[i].toDouble(),
                              color: colors[i],
                              radius: 40,
                              title: '${(values[i] / total * 100).round()}%',
                              titleStyle: theme.textTheme.labelMedium?.copyWith(
                                color: ink[i],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${names[i]} · ${values[i]} g',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepChart extends StatelessWidget {
  const _SleepChart({required this.data});

  final _AnalyticsOverviewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _lastSevenDays();
    final sleepSeries = days
        .map(
          (day) =>
              FlSpot(days.indexOf(day).toDouble(), data.sleepByDay[day] ?? 0),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Horas de sueño', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 12,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdayLabel(days[index].weekday),
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 2),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineTouchData: LineTouchData(enabled: true),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: theme.colorScheme.secondary,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      spots: sleepSeries,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DateTime> _lastSevenDays() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return DateTime(day.year, day.month, day.day);
    });
  }

  String _weekdayLabel(int weekday) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return labels[(weekday - 1) % labels.length];
  }
}

class _WorkoutSummaryCard extends StatelessWidget {
  const _WorkoutSummaryCard({required this.data});

  final _AnalyticsOverviewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = data.workoutByDay.values.fold<int>(
      0,
      (sum, v) => sum + v,
    );
    final bestDay = data.workoutByDay.entries.isEmpty
        ? null
        : data.workoutByDay.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
          );
    final average = data.workoutByDay.isEmpty
        ? 0
        : (totalMinutes / data.workoutByDay.length).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Carga semanal', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Minutos totales entrenados en los últimos 7 días.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _HighlightMetric(
                  label: 'Total',
                  value: '$totalMinutes min',
                  icon: Icons.timer_rounded,
                ),
                const SizedBox(width: 16),
                _HighlightMetric(
                  label: 'Promedio',
                  value: '$average min/día',
                  icon: Icons.timeline_rounded,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _HighlightMetric(
                    label: 'Mejor día',
                    value: bestDay == null
                        ? 'Sin datos'
                        : '${_weekdayLabel(bestDay.key.weekday)} · ${bestDay.value} min',
                    icon: Icons.star_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return labels[(weekday - 1) % labels.length];
  }
}

class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
