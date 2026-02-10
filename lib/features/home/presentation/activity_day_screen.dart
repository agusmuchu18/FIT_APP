import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';
import '../domain/home_activity_utils.dart';
import 'widgets/activity_calendar_sheet.dart';
import 'widgets/home_date_selector_chip.dart';

class ActivityDayScreen extends StatefulWidget {
  const ActivityDayScreen({
    super.key,
    required this.date,
  });

  final DateTime date;

  @override
  State<ActivityDayScreen> createState() => _ActivityDayScreenState();
}

class _ActivityDayScreenState extends State<ActivityDayScreen> {
  late DateTime _selectedDay;
  late Future<_ActivityDayData> _dayFuture;

  @override
  void initState() {
    super.initState();
    _selectedDay = normalizeDay(widget.date);
    _dayFuture = _loadData();
  }

  Future<_ActivityDayData> _loadData() async {
    final repository = RepositoryScope.of(context);
    final workouts = await repository.getWorkouts();
    final meals = await repository.getMeals();
    final sleepEntries = await repository.getSleep();

    final activeDays = buildActiveDaysSet(
      workouts: workouts,
      meals: meals,
      sleepEntries: sleepEntries,
    );

    final summary = getActivityForDay(
      day: _selectedDay,
      workouts: workouts,
      meals: meals,
      sleepEntries: sleepEntries,
    );

    return _ActivityDayData(summary: summary, activeDays: activeDays);
  }

  Future<void> _openCalendar(Set<DateTime> activeDays) async {
    final selected = await ActivityCalendarSheet.show(
      context,
      activeDays: activeDays,
      initialSelectedDay: _selectedDay,
    );
    if (selected == null) return;
    setState(() {
      _selectedDay = normalizeDay(selected);
      _dayFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0B1220),
              Color(0xFF0E1624),
              Color(0xFF070B12),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_ActivityDayData>(
            future: _dayFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              final data = snapshot.data ?? _ActivityDayData.empty(_selectedDay);
              final summary = data.summary;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          color: Colors.white,
                        ),
                        Expanded(
                          child: Text(
                            'Actividad del día',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                          ),
                        ),
                        HomeDateSelectorChip(
                          text: _formatDateShort(_selectedDay),
                          onTap: () => _openCalendar(data.activeDays),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tu día, de un vistazo.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 18),
                    if (!summary.hasActivity)
                      const _PremiumEmptyState()
                    else ...[
                      _ActivityMetricCard(
                        icon: Icons.fitness_center_rounded,
                        title: 'Entrenamiento',
                        subtitle:
                            '${summary.workouts.length} sesión(es) · ${summary.totalTrainingMinutes} min',
                      ),
                      const SizedBox(height: 12),
                      _ActivityMetricCard(
                        icon: Icons.restaurant_menu_rounded,
                        title: 'Alimentación',
                        subtitle: summary.meals.isEmpty
                            ? '${summary.meals.length} comida(s)'
                            : '${summary.meals.length} comida(s) · ${summary.totalCalories} kcal',
                      ),
                      const SizedBox(height: 12),
                      _ActivityMetricCard(
                        icon: Icons.nightlight_round,
                        title: 'Sueño',
                        subtitle:
                            '${summary.sleepEntries.length} registro(s) · ${_sleepHours(summary)} h',
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _sleepHours(HomeDayActivitySummary summary) {
    final total = summary.sleepEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.hours,
    );
    return total.toStringAsFixed(1);
  }

  String _formatDateShort(DateTime date) {
    const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final capWeekday = '${weekday[0].toUpperCase()}${weekday.substring(1)}';
    final capMonth = '${month[0].toUpperCase()}${month.substring(1)}';
    return '$capWeekday, ${date.day} $capMonth';
  }
}

class _ActivityDayData {
  const _ActivityDayData({
    required this.summary,
    required this.activeDays,
  });

  factory _ActivityDayData.empty(DateTime day) {
    return _ActivityDayData(
      summary: HomeDayActivitySummary(
        day: day,
        workouts: const [],
        meals: const [],
        sleepEntries: const [],
        totalTrainingMinutes: 0,
        totalCalories: 0,
        hasActivity: false,
      ),
      activeDays: const <DateTime>{},
    );
  }

  final HomeDayActivitySummary summary;
  final Set<DateTime> activeDays;
}

class _ActivityMetricCard extends StatelessWidget {
  const _ActivityMetricCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      glass: true,
      minHeight: 96,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8AE9D2).withOpacity(0.16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Icon(icon, color: const Color(0xFF8AE9D2), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
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

class _PremiumEmptyState extends StatelessWidget {
  const _PremiumEmptyState();

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      glass: true,
      minHeight: 132,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sin registros para este día.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Cuando cargues entrenamientos, comidas o sueño, los vas a ver acá automáticamente.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
