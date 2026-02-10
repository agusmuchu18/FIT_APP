import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../domain/home_activity_utils.dart';
import 'activity_module_day_detail_screens.dart';
import 'widgets/activity_calendar_sheet.dart';
import 'widgets/activity_day_components.dart';
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
                          text: formatDateChipText(_selectedDay),
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
                    ActivityModuleTile(
                      module: ActivityModuleType.workout,
                      subtitle: summary.workouts.isEmpty
                          ? 'Sin entrenamientos cargados'
                          : '${summary.workouts.length} sesión(es) · ${summary.totalTrainingMinutes} min',
                      count: summary.workouts.length,
                      hasActivity: summary.workouts.isNotEmpty,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutDayDetailScreen(date: _selectedDay),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ActivityModuleTile(
                      module: ActivityModuleType.meal,
                      subtitle: summary.meals.isEmpty
                          ? 'Sin comidas cargadas'
                          : '${summary.meals.length} comida(s) · ${summary.totalCalories} kcal',
                      count: summary.meals.length,
                      hasActivity: summary.meals.isNotEmpty,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MealsDayDetailScreen(date: _selectedDay),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ActivityModuleTile(
                      module: ActivityModuleType.sleep,
                      subtitle: summary.sleepEntries.isEmpty
                          ? 'Sin sueño cargado'
                          : '${summary.sleepEntries.length} registro(s) · ${_sleepHours(summary)} h',
                      count: summary.sleepEntries.length,
                      hasActivity: summary.sleepEntries.isNotEmpty,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SleepDayDetailScreen(date: _selectedDay),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    ActivityTimelineSection(events: _buildTimeline(summary)),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<TimelineEvent> _buildTimeline(HomeDayActivitySummary summary) {
    final events = <TimelineEvent>[];

    for (final workout in summary.workouts) {
      final date = parseEntryDate(workout.id);
      final time = formatTimeLabel(date);
      events.add(
        TimelineEvent(
          module: ActivityModuleType.workout,
          description: '${workout.name} · ${workout.durationMinutes} min',
          timeLabel: time.isNotEmpty ? time : fallbackTimeLabelForModule(ActivityModuleType.workout),
          orderDate: date,
        ),
      );
    }

    for (final meal in summary.meals) {
      final date = parseEntryDate(meal.id);
      final time = formatTimeLabel(date);
      events.add(
        TimelineEvent(
          module: ActivityModuleType.meal,
          description: '${meal.title} · ${meal.calories} kcal',
          timeLabel: time.isNotEmpty ? time : fallbackTimeLabelForModule(ActivityModuleType.meal),
          orderDate: date,
        ),
      );
    }

    for (final sleep in summary.sleepEntries) {
      final date = parseEntryDate(sleep.id);
      final time = sleep.wakeTime?.isNotEmpty == true
          ? sleep.wakeTime!
          : (formatTimeLabel(date).isNotEmpty
              ? formatTimeLabel(date)
              : fallbackTimeLabelForModule(ActivityModuleType.sleep));
      events.add(
        TimelineEvent(
          module: ActivityModuleType.sleep,
          description: 'Sueño ${sleep.quality.toLowerCase()} · ${compactNumber(sleep.hours)} h',
          timeLabel: time,
          orderDate: date,
        ),
      );
    }

    return sortTimeline(events);
  }

  String _sleepHours(HomeDayActivitySummary summary) {
    final total = summary.sleepEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.hours,
    );
    return compactNumber(total);
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
