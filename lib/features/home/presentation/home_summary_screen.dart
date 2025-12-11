import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../nutrition/data/food_repository.dart';

class HomeSummaryScreen extends StatefulWidget {
  const HomeSummaryScreen({super.key});

  @override
  State<HomeSummaryScreen> createState() => _HomeSummaryScreenState();
}

class _HomeSummaryScreenState extends State<HomeSummaryScreen> {
  final FoodRepository _foodRepository = FoodRepository();

  Future<_HomeSummaryData> _loadSummaryData() async {
    final repository = RepositoryScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastWeekStart = today.subtract(const Duration(days: 6));
    final previousWeekStart = today.subtract(const Duration(days: 13));
    final previousWeekEnd = today.subtract(const Duration(days: 7));

    final workoutsFuture = repository.getWorkouts();
    final mealsFuture = repository.getMeals();
    final sleepFuture = repository.getSleep();
    final nutritionTodayFuture = repository.getDailyNutritionStats(today);
    final workoutDurationsFuture =
        repository.getWorkoutDurationByDay(days: 14);

    final meals = await mealsFuture;
    final workouts = await workoutsFuture;
    final sleepEntries = await sleepFuture;
    final nutritionToday = await nutritionTodayFuture;
    final workoutDurations = await workoutDurationsFuture;

    // Active streak calculation based on any logged activity.
    final activityDays = <DateTime>{};
    for (final workout in workouts) {
      activityDays.add(_dateOnly(_safeParseDate(workout.id)));
    }
    for (final meal in meals) {
      activityDays.add(_dateOnly(_safeParseDate(meal.id)));
    }
    for (final sleep in sleepEntries) {
      activityDays.add(_dateOnly(_safeParseDate(sleep.id)));
    }

    var streak = 0;
    final streakDots = <bool>[];
    for (var i = 11; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      final isActive = activityDays.contains(day);
      streakDots.add(isActive);
    }
    for (var i = 0;; i++) {
      final day = today.subtract(Duration(days: i));
      if (activityDays.contains(day)) {
        streak++;
      } else {
        break;
      }
    }

    // Training stats.
    final trainingToday = workoutDurations[today] ?? 0;
    final recentTrainingMinutes = <int>[];
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: 6 - i));
      recentTrainingMinutes.add(workoutDurations[day] ?? 0);
    }
    final trainingWeekTotal =
        recentTrainingMinutes.fold<int>(0, (sum, value) => sum + value);
    final trainingWeeklyAvg = (trainingWeekTotal / 7).round();

    // Nutrition stats with FoodRepository support.
    final catalog = await _foodRepository.loadLocalCatalog();
    var caloriesToday = 0;
    var macrosToday = Macros(carbs: 0, protein: 0, fat: 0);
    for (final meal in meals) {
      final entryDate = _dateOnly(_safeParseDate(meal.id));
      if (entryDate != today) continue;

      final matchingFood = catalog.firstWhere(
        (item) =>
            item.name.toLowerCase() == meal.title.toLowerCase() ||
            meal.title.toLowerCase().contains(item.name.toLowerCase()),
        orElse: () => FoodItem(
          name: meal.title,
          caloriesPer100g: meal.calories,
          macros: meal.macros,
        ),
      );

      final calories = meal.calories > 0
          ? meal.calories
          : matchingFood.caloriesPer100g;
      final macros = meal.macros.carbs + meal.macros.protein + meal.macros.fat >
              0
          ? meal.macros
          : matchingFood.macros;

      caloriesToday += calories;
      macrosToday = Macros(
        carbs: macrosToday.carbs + macros.carbs,
        protein: macrosToday.protein + macros.protein,
        fat: macrosToday.fat + macros.fat,
      );
    }

    if (caloriesToday == 0 && nutritionToday != null) {
      caloriesToday = nutritionToday.totalCalories;
      macrosToday = nutritionToday.macros;
    }

    // Sleep metrics for current and previous week.
    double _averageHoursForRange(
      DateTime start,
      DateTime end,
      List<SleepEntry> entries,
    ) {
      final filtered = entries.where((entry) {
        final date = _dateOnly(_safeParseDate(entry.id));
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList();
      if (filtered.isEmpty) return 0;
      final total =
          filtered.fold<double>(0, (sum, entry) => sum + entry.hours);
      return total / filtered.length;
    }

    double _regularityStdDev(DateTime start, DateTime end) {
      final times = <int>[];
      for (final entry in sleepEntries) {
        final date = _dateOnly(_safeParseDate(entry.id));
        if (date.isBefore(start) || date.isAfter(end)) continue;
        final bedMinutes = _parseMinutes(entry.bedtime);
        final wakeMinutes = _parseMinutes(entry.wakeTime);
        if (bedMinutes != null) times.add(bedMinutes);
        if (wakeMinutes != null) times.add(wakeMinutes);
      }
      if (times.length < 2) return 0;
      final mean = times.reduce((a, b) => a + b) / times.length;
      final variance = times
              .map((t) => math.pow(t - mean, 2))
              .reduce((a, b) => a + b) /
          times.length;
      return math.sqrt(variance);
    }

    final avgSleepDuration =
        _averageHoursForRange(lastWeekStart, today, sleepEntries);
    final previousSleepAvg =
        _averageHoursForRange(previousWeekStart, previousWeekEnd, sleepEntries);
    final avgSleepDelta = avgSleepDuration - previousSleepAvg;

    final regularityScore = _regularityStdDev(lastWeekStart, today)
        .clamp(0, double.infinity)
        .toDouble();
    final previousRegularity = _regularityStdDev(
      previousWeekStart,
      previousWeekEnd,
    ).clamp(0, double.infinity).toDouble();
    final regularityWeekDelta = regularityScore - previousRegularity;

    return _HomeSummaryData(
      activeStreak: streak,
      streakDots: streakDots,
      trainingToday: trainingToday,
      trainingWeeklyAvg: trainingWeeklyAvg,
      trainingWeeklyDistribution: recentTrainingMinutes,
      caloriesToday: caloriesToday,
      macrosToday: macrosToday,
      avgSleepDuration: avgSleepDuration,
      avgSleepDelta: avgSleepDelta,
      regularityScore: regularityScore,
      regularityWeekDelta: regularityWeekDelta,
    );
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _safeParseDate(String raw) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  int? _parseMinutes(String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    if (hours == null || minutes == null) return null;
    return hours * 60 + minutes;
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0E1624);

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: backgroundColor,
          child: FutureBuilder<_HomeSummaryData>(
            future: _loadSummaryData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              final data = snapshot.data ?? _HomeSummaryData.empty();

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 420),
                    tween: Tween<double>(begin: 0, end: 1),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeaderSection(),
                        const SizedBox(height: 24),
                        _StreakCard(
                          activeDays: data.activeStreak,
                          dots: data.streakDots,
                          onTap: () {
                            Navigator.pushNamed(context, '/streak');
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard.training(
                                primaryValue: '${data.trainingToday} min',
                                secondaryValue:
                                    'Promedio semanal: ${data.trainingWeeklyAvg} min',
                                distribution: data.trainingWeeklyDistribution,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/workout/lite',
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricCard.nutrition(
                                calories: data.caloriesToday,
                                macros: data.macrosToday,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/nutrition/lite',
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _SleepInfoCard(
                                avgSleepHours: data.avgSleepDuration,
                                avgSleepDelta: data.avgSleepDelta,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/sleep/lite',
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SleepMetricsCard(
                                regularityScore: data.regularityScore,
                                regularityDelta: data.regularityWeekDelta,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        _GroupsCard(
                          onTap: () {
                            Navigator.pushNamed(context, '/groups/list');
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeSummaryData {
  _HomeSummaryData({
    required this.activeStreak,
    required this.streakDots,
    required this.trainingToday,
    required this.trainingWeeklyAvg,
    required this.trainingWeeklyDistribution,
    required this.caloriesToday,
    required this.macrosToday,
    required this.avgSleepDuration,
    required this.avgSleepDelta,
    required this.regularityScore,
    required this.regularityWeekDelta,
  });

  factory _HomeSummaryData.empty() {
    return _HomeSummaryData(
      activeStreak: 0,
      streakDots: List.filled(12, false),
      trainingToday: 0,
      trainingWeeklyAvg: 0,
      trainingWeeklyDistribution: List.filled(7, 0),
      caloriesToday: 0,
      macrosToday: Macros(carbs: 1, protein: 1, fat: 1),
      avgSleepDuration: 0,
      avgSleepDelta: 0,
      regularityScore: 0,
      regularityWeekDelta: 0,
    );
  }

  final int activeStreak;
  final List<bool> streakDots;
  final int trainingToday;
  final int trainingWeeklyAvg;
  final List<int> trainingWeeklyDistribution;
  final int caloriesToday;
  final Macros macrosToday;
  final double avgSleepDuration;
  final double avgSleepDelta;
  final double regularityScore;
  final double regularityWeekDelta;
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF161F2C);
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdayNames = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    final monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final formattedDate =
        '${weekdayNames[now.weekday - 1]}, ${now.day} de ${monthNames[now.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formattedDate,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9BA7B4),
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Resumen',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({
    required this.activeDays,
    required this.dots,
    required this.onTap,
  });

  final int activeDays;
  final List<bool> dots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SummaryCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _StreakIcon(),
              const SizedBox(width: 16),
              Expanded(
                child: _StreakDetails(
                  activeDays: activeDays,
                  dots: dots,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakIcon extends StatelessWidget {
  const _StreakIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x1AFF4A25),
      ),
      child: const Icon(
        Icons.local_fire_department_rounded,
        color: Color(0xFFFF4A25),
        size: 42,
      ),
    );
  }
}

class _StreakDetails extends StatelessWidget {
  const _StreakDetails({
    required this.activeDays,
    required this.dots,
  });

  final int activeDays;
  final List<bool> dots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Racha activa',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFFE4E8EE),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$activeDays días',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 14),
        _StreakDotsRow(dots: dots),
      ],
    );
  }
}

class _StreakDotsRow extends StatelessWidget {
  const _StreakDotsRow({required this.dots});

  final List<bool> dots;

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      const Color(0xFFFF7A2F),
      const Color(0xFFFF6A2A),
      const Color(0xFFFF5D26),
      const Color(0xFFFF4F23),
      const Color(0xFFEE4122),
      const Color(0xFFE33522),
      const Color(0xFFD72D21),
      const Color(0xFFCD2620),
      const Color(0xFFC22020),
      const Color(0xFFB71A1F),
      const Color(0xFFAE151E),
      const Color(0xFFA6101D),
    ];

    return Row(
      children: List.generate(12, (index) {
        final isActive = index < dots.length ? dots[index] : false;
        return Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(right: index == 11 ? 0 : 6),
          decoration: BoxDecoration(
            color: isActive
                ? gradientColors[index]
                : const Color(0xFF2A3546),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard._({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.content,
    required this.onTap,
  });

  factory _MetricCard.training({
    required String primaryValue,
    required String secondaryValue,
    required List<int> distribution,
    required VoidCallback onTap,
  }) {
    return _MetricCard._(
      title: 'Entrenamiento',
      value: primaryValue,
      valueColor: const Color(0xFF2AF5D2),
      content: _TrainingChart(
        secondaryValue: secondaryValue,
        distribution: distribution,
      ),
      onTap: onTap,
    );
  }

  factory _MetricCard.nutrition({
    required int calories,
    required Macros macros,
    required VoidCallback onTap,
  }) {
    return _MetricCard._(
      title: 'Alimentación',
      value: '${calories.toString()} kcal',
      valueColor: Colors.white,
      content: _NutritionCharts(macros: macros),
      onTap: onTap,
    );
  }

  final String title;
  final String value;
  final Color valueColor;
  final Widget content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SummaryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9BA7B4),
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  color: valueColor,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingChart extends StatelessWidget {
  const _TrainingChart({
    required this.secondaryValue,
    required this.distribution,
  });

  final String secondaryValue;
  final List<int> distribution;

  @override
  Widget build(BuildContext context) {
    final effectiveDistribution = distribution.isEmpty
        ? List.filled(7, 0)
        : distribution;
    final maxMinutes =
        effectiveDistribution.fold<int>(0, (max, value) => value > max ? value : max);
    const maxHeight = 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(effectiveDistribution.length, (index) {
              final value = effectiveDistribution[index];
              final normalized = maxMinutes == 0
                  ? 0.2
                  : (value / maxMinutes).clamp(0.2, 1.0);
              final barHeight = maxHeight * normalized;
              return _MiniBar(height: barHeight);
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          secondaryValue,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9BA7B4),
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2AF5D2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _NutritionCharts extends StatelessWidget {
  const _NutritionCharts({required this.macros});

  final Macros macros;

  @override
  Widget build(BuildContext context) {
    final total = math.max(macros.carbs + macros.protein + macros.fat, 1);
    final carbsRatio = macros.carbs / total;
    final proteinRatio = macros.protein / total;
    final fatRatio = macros.fat / total;
    final carbsFlex = math.max((carbsRatio * 1000).round(), 1);
    final proteinFlex = math.max((proteinRatio * 1000).round(), 1);
    final fatFlex = math.max((fatRatio * 1000).round(), 1);
    final carbsPct = (carbsRatio * 100).round();
    final proteinPct = (proteinRatio * 100).round();
    final fatPct = (fatRatio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 11,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withOpacity(0.04),
          ),
          child: Row(
            children: [
              Expanded(
                flex: carbsFlex,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFD438),
                    borderRadius: BorderRadius.horizontal(left: Radius.circular(999)),
                  ),
                ),
              ),
              Expanded(
                flex: proteinFlex,
                child: Container(color: const Color(0xFF6D7B44)),
              ),
              Expanded(
                flex: fatFlex,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF3FA7FF),
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(999)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _MacroLegend(
              label: 'Carbs',
              grams: macros.carbs,
              percent: carbsPct,
              color: const Color(0xFFFFD438),
            ),
            _MacroLegend(
              label: 'Proteína',
              grams: macros.protein,
              percent: proteinPct,
              color: const Color(0xFF6D7B44),
            ),
            _MacroLegend(
              label: 'Grasas',
              grams: macros.fat,
              percent: fatPct,
              color: const Color(0xFF3FA7FF),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({
    required this.label,
    required this.grams,
    required this.percent,
    required this.color,
  });

  final String label;
  final int grams;
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Text(
          '$label · ${grams}g (${percent}%)',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF9BA7B4),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}

class _SleepInfoCard extends StatelessWidget {
  const _SleepInfoCard({
    required this.avgSleepHours,
    required this.avgSleepDelta,
    required this.onTap,
  });

  final double avgSleepHours;
  final double avgSleepDelta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoursPart = avgSleepHours.floor();
    final minutesPart = ((avgSleepHours - hoursPart) * 60).round();
    final formattedHours =
        '${hoursPart.toString()} h ${minutesPart.toString().padLeft(2, '0')} min';
    final deltaPositive = avgSleepDelta >= 0;
    final deltaText =
        '${deltaPositive ? '+' : '-'}${avgSleepDelta.abs().toStringAsFixed(1)} h vs semana previa';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SummaryCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sueño',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFFE4E8EE),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                formattedHours,
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFFA4A7FF),
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    deltaPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    color: deltaPositive
                        ? const Color(0xFF7CF4FF)
                        : const Color(0xFFFF6A6A),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    deltaText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9BA7B4),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Promedio últimos 7 días',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6F7C93),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepMetricsCard extends StatelessWidget {
  const _SleepMetricsCard({
    required this.regularityScore,
    required this.regularityDelta,
  });

  final double regularityScore;
  final double regularityDelta;

  @override
  Widget build(BuildContext context) {
    final improved = regularityDelta <= 0;
    final variability = regularityScore.round();
    final deltaMinutes = regularityDelta.abs().round();

    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Regularidad del Sueño',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFFE4E8EE),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Icon(
                improved
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: improved
                    ? const Color(0xFF34D27B)
                    : const Color(0xFFFF6A6A),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Variabilidad de horario',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9BA7B4),
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${variability} min',
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF7CF4FF),
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                improved
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: improved
                    ? const Color(0xFF34D27B)
                    : const Color(0xFFFF6A6A),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                '${deltaMinutes} min vs semana previa',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9BA7B4),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupsCard extends StatelessWidget {
  const _GroupsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SummaryCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x1A7CF4FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.group,
                  color: Color(0xFF7CF4FF),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Grupos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Gestiona y analiza tus grupos de usuarios',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9BA7B4),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF6F7C93),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
