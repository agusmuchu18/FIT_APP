import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../domain/home_activity_utils.dart';
import 'widgets/activity_calendar_sheet.dart';
import 'widgets/activity_day_components.dart';
import 'widgets/home_date_selector_chip.dart';

class WorkoutDayDetailScreen extends StatelessWidget {
  const WorkoutDayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return _ModuleDayDetailScreen(
      initialDate: date,
      module: ActivityModuleType.workout,
    );
  }
}

class MealsDayDetailScreen extends StatelessWidget {
  const MealsDayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return _ModuleDayDetailScreen(
      initialDate: date,
      module: ActivityModuleType.meal,
    );
  }
}

class SleepDayDetailScreen extends StatelessWidget {
  const SleepDayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return _ModuleDayDetailScreen(
      initialDate: date,
      module: ActivityModuleType.sleep,
    );
  }
}

class _ModuleDayDetailScreen extends StatefulWidget {
  const _ModuleDayDetailScreen({
    required this.initialDate,
    required this.module,
  });

  final DateTime initialDate;
  final ActivityModuleType module;

  @override
  State<_ModuleDayDetailScreen> createState() => _ModuleDayDetailScreenState();
}

class _ModuleDayDetailScreenState extends State<_ModuleDayDetailScreen> {
  late DateTime _selectedDay;
  late Future<_ActivityDayData> _dayFuture;

  @override
  void initState() {
    super.initState();
    _selectedDay = normalizeDay(widget.initialDate);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
          top: false,
          child: FutureBuilder<_ActivityDayData>(
            future: _dayFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }

              final data = snapshot.data ?? _ActivityDayData.empty(_selectedDay);
              final summary = data.summary;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.module.label,
                                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatDateLong(_selectedDay),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        HomeDateSelectorChip(
                          text: formatDateChipText(_selectedDay),
                          onTap: () => _openCalendar(data.activeDays),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildStats(summary),
                    const SizedBox(height: 18),
                    Text(
                      'Registros del día',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    _buildRecords(summary),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStats(HomeDayActivitySummary summary) {
    switch (widget.module) {
      case ActivityModuleType.workout:
        const goalMinutes = 30;
        const goalSessions = 2;
        return ModuleStatsHeader(
          children: [
            GlassStatCard(
              child: Row(
                children: [
                  RingStat(
                    progress: percentage(summary.totalTrainingMinutes, goalMinutes),
                    color: AppColors.accentTraining,
                    value: '${summary.totalTrainingMinutes} min',
                    label: 'de $goalMinutes min',
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ProgressBar(
                      value: percentage(summary.workouts.length, goalSessions),
                      label: 'Sesiones del día',
                      trailing: '${summary.workouts.length}/$goalSessions',
                      color: AppColors.accentTraining,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case ActivityModuleType.meal:
        const kcalGoal = 2000;
        final carbs = summary.meals.fold<int>(0, (sum, meal) => sum + meal.macros.carbs);
        final protein = summary.meals.fold<int>(0, (sum, meal) => sum + meal.macros.protein);
        final fat = summary.meals.fold<int>(0, (sum, meal) => sum + meal.macros.fat);
        final hasMacroData = carbs > 0 || protein > 0 || fat > 0;

        return ModuleStatsHeader(
          children: [
            GlassStatCard(
              child: Column(
                children: [
                  ProgressBar(
                    value: percentage(summary.totalCalories, kcalGoal),
                    label: 'Kcal consumidas',
                    trailing: '${summary.totalCalories}/$kcalGoal',
                    color: AppColors.accentFood,
                    height: 12,
                  ),
                  if (hasMacroData) ...[
                    const SizedBox(height: 14),
                    ProgressBar(
                      value: percentage(carbs, 300),
                      label: 'Carbs',
                      trailing: '$carbs g',
                      color: AppColors.accentFood,
                      height: 8,
                    ),
                    const SizedBox(height: 10),
                    ProgressBar(
                      value: percentage(protein, 140),
                      label: 'Protein',
                      trailing: '$protein g',
                      color: const Color(0xFFDEB868),
                      height: 8,
                    ),
                    const SizedBox(height: 10),
                    ProgressBar(
                      value: percentage(fat, 80),
                      label: 'Fat',
                      trailing: '$fat g',
                      color: const Color(0xFFF7DD8C),
                      height: 8,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      case ActivityModuleType.sleep:
        const sleepGoal = 8.0;
        final totalHours = summary.sleepEntries.fold<double>(0, (sum, e) => sum + e.hours);
        final scores = summary.sleepEntries
            .map((entry) => entry.qualityScore)
            .whereType<int>()
            .toList(growable: false);
        final qualityAvg = average(scores);

        return ModuleStatsHeader(
          children: [
            GlassStatCard(
              child: Row(
                children: [
                  RingStat(
                    progress: percentageDouble(totalHours, sleepGoal),
                    color: AppColors.accentSleep,
                    value: '${compactNumber(totalHours)} h',
                    label: 'de ${compactNumber(sleepGoal)} h',
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ProgressBar(
                      value: qualityAvg > 0 ? (qualityAvg / 5).clamp(0.0, 1.0) : 0,
                      label: 'Calidad del sueño',
                      trailing: qualityAvg > 0 ? '${compactNumber(qualityAvg)}/5' : 'Sin datos',
                      color: AppColors.accentSleep,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _buildRecords(HomeDayActivitySummary summary) {
    switch (widget.module) {
      case ActivityModuleType.workout:
        if (summary.workouts.isEmpty) {
          return EmptyModuleState(
            message: 'No registraste entrenamientos para este día.',
            ctaLabel: 'Agregar entrenamiento',
            onCtaTap: () => Navigator.pushNamed(context, '/workout'),
          );
        }
        return Column(
          children: summary.workouts.map((workout) {
            final date = parseEntryDate(workout.id);
            final time = formatTimeLabel(date);
            return DayRecordTile(
              title: workout.name,
              subtitle: time.isEmpty ? 'Sin hora' : time,
              value: '${workout.durationMinutes} min',
              onTap: () => _showRecordModal(
                title: workout.name,
                detail: '${workout.intensity} · ${workout.durationMinutes} min',
              ),
            );
          }).toList(growable: false),
        );
      case ActivityModuleType.meal:
        if (summary.meals.isEmpty) {
          return EmptyModuleState(
            message: 'Todavía no hay comidas registradas para este día.',
            ctaLabel: 'Agregar comida',
            onCtaTap: () => Navigator.pushNamed(context, '/nutrition'),
          );
        }
        return Column(
          children: summary.meals.map((meal) {
            final date = parseEntryDate(meal.id);
            final time = formatTimeLabel(date);
            return DayRecordTile(
              title: meal.title,
              subtitle: time.isEmpty ? 'Sin hora' : time,
              value: '${meal.calories} kcal',
              onTap: () => _showRecordModal(
                title: meal.title,
                detail:
                    '${meal.calories} kcal · C${meal.macros.carbs} P${meal.macros.protein} G${meal.macros.fat}',
              ),
            );
          }).toList(growable: false),
        );
      case ActivityModuleType.sleep:
        if (summary.sleepEntries.isEmpty) {
          return EmptyModuleState(
            message: 'No hay registros de sueño para este día.',
            ctaLabel: 'Agregar sueño',
            onCtaTap: () => Navigator.pushNamed(context, '/sleep'),
          );
        }
        return Column(
          children: summary.sleepEntries.map((sleep) {
            final subtitle = sleep.wakeTime != null && sleep.bedtime != null
                ? '${sleep.bedtime} - ${sleep.wakeTime}'
                : 'Registro de sueño';
            return DayRecordTile(
              title: sleep.quality.isEmpty ? 'Sueño' : sleep.quality,
              subtitle: subtitle,
              value: '${compactNumber(sleep.hours)} h',
              onTap: () => _showRecordModal(
                title: sleep.quality.isEmpty ? 'Sueño' : sleep.quality,
                detail: '${compactNumber(sleep.hours)} h · Calidad ${sleep.qualityScore ?? '-'} / 5',
              ),
            );
          }).toList(growable: false),
        );
    }
  }

  Future<void> _showRecordModal({required String title, required String detail}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111926),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        );
      },
    );
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
