import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/data/repositories.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';

class AnalyticsOverviewScreen extends StatefulWidget {
  const AnalyticsOverviewScreen({super.key});

  @override
  State<AnalyticsOverviewScreen> createState() => _AnalyticsOverviewScreenState();
}

class _AnalyticsOverviewScreenState extends State<AnalyticsOverviewScreen> {
  late FitnessRepository _repository;
  late Future<_AnalyticsOverviewData> _dataFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = RepositoryScope.of(context);
    _dataFuture = _loadData();
  }

  Future<_AnalyticsOverviewData> _loadData() async {
    final nutritionHistory = await _repository.getWeeklyNutritionStats();
    final macroTotals = await _repository.getMacroDistribution();
    final sleepEntries = await _repository.getRecentSleep();
    final workoutByDay = await _repository.getWorkoutDurationByDay();

    final sleepByDay = _aggregateSleepByDay(sleepEntries);

    return _AnalyticsOverviewData(
      nutritionHistory: nutritionHistory,
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
          )
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
                    Text('No se pudo cargar la vista de datos',
                        style: textTheme.titleMedium),
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
                        'Visión semanal de energía ingerida y distribución de macronutrientes.',
                  ),
                  const SizedBox(height: 12),
                  _WeeklyCaloriesChart(data: data),
                  const SizedBox(height: 12),
                  _MacroPieChart(macroTotals: data.macroTotals),
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
              ),
            );
          },
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}

class _AnalyticsOverviewData {
  const _AnalyticsOverviewData({
    required this.nutritionHistory,
    required this.macroTotals,
    required this.sleepByDay,
    required this.workoutByDay,
  });

  final List<NutritionMetrics> nutritionHistory;
  final Macros macroTotals;
  final Map<DateTime, double> sleepByDay;
  final Map<DateTime, int> workoutByDay;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

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
    final theme = Theme.of(context);
    final days = _lastSevenDays();
    final caloriesByDay = _caloriesByDate(days, data.nutritionHistory);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calorías por día', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barTouchData: BarTouchData(enabled: true),
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= days.length) {
                            return const SizedBox();
                          }
                          final day = days[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _weekdayLabel(day.weekday),
                              style: theme.textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, interval: 200),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i = 0; i < days.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: caloriesByDay[days[i]]?.toDouble() ?? 0,
                            color: theme.colorScheme.primary,
                            width: 18,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
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

  Map<DateTime, int> _caloriesByDate(
    List<DateTime> days,
    List<NutritionMetrics> history,
  ) {
    final map = {for (final day in days) day: 0};
    for (final metrics in history) {
      final key = DateTime(metrics.date.year, metrics.date.month, metrics.date.day);
      if (map.containsKey(key)) {
        map[key] = metrics.totalCalories;
      }
    }
    return map;
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

class _MacroPieChart extends StatelessWidget {
  const _MacroPieChart({required this.macroTotals});

  final Macros macroTotals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total =
        (macroTotals.carbs + macroTotals.protein + macroTotals.fat).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Distribución de macros',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Suma semanal de carbohidratos, proteínas y grasas.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _LegendDot(color: theme.colorScheme.primary, label: 'Carbohidratos'),
                  const SizedBox(height: 6),
                  _LegendDot(
                      color: theme.colorScheme.secondary, label: 'Proteína'),
                  const SizedBox(height: 6),
                  _LegendDot(color: theme.colorScheme.tertiary, label: 'Grasas'),
                ],
              ),
            ),
            SizedBox(
              width: 180,
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 38,
                  sections: [
                    PieChartSectionData(
                      color: theme.colorScheme.primary,
                      value: macroTotals.carbs.toDouble(),
                      title: total == 0
                          ? '0%'
                          : '${((macroTotals.carbs / total) * 100).round()}%',
                      radius: 52,
                      titleStyle: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onPrimary),
                    ),
                    PieChartSectionData(
                      color: theme.colorScheme.secondary,
                      value: macroTotals.protein.toDouble(),
                      title: total == 0
                          ? '0%'
                          : '${((macroTotals.protein / total) * 100).round()}%',
                      radius: 48,
                      titleStyle: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSecondary),
                    ),
                    PieChartSectionData(
                      color: theme.colorScheme.tertiary,
                      value: macroTotals.fat.toDouble(),
                      title: total == 0
                          ? '0%'
                          : '${((macroTotals.fat / total) * 100).round()}%',
                      radius: 44,
                      titleStyle: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onTertiary),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
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
          (day) => FlSpot(
            days.indexOf(day).toDouble(),
            data.sleepByDay[day] ?? 0,
          ),
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
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
    final totalMinutes = data.workoutByDay.values.fold<int>(0, (sum, v) => sum + v);
    final bestDay = data.workoutByDay.entries.isEmpty
        ? null
        : data.workoutByDay.entries.reduce((a, b) => a.value >= b.value ? a : b);
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
