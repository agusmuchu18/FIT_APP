import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';
import '../../home/domain/goal_insight_service.dart';
import '../../nutrition/data/food_repository.dart';
import '../../sleep/domain/sleep_time_utils.dart';

class HomeSummaryScreen extends StatefulWidget {
  const HomeSummaryScreen({super.key});

  @override
  State<HomeSummaryScreen> createState() => _HomeSummaryScreenState();
}

class _HomeSummaryScreenState extends State<HomeSummaryScreen> {
  final FoodRepository _foodRepository = FoodRepository();
  late Future<_HomeSummaryData> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummaryData();
  }

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
    final preferencesFuture = repository.getPreferences();
    final nutritionTodayFuture = repository.getDailyNutritionStats(today);
    final weeklyNutritionFuture = repository.getWeeklyNutritionStats(days: 7);
    final macroDistributionFuture = repository.getMacroDistribution(days: 7);
    final workoutDurationsFuture = repository.getWorkoutDurationByDay(days: 14);

    final meals = await mealsFuture;
    final workouts = await workoutsFuture;
    final sleepEntries = await sleepFuture;
    final preferences = await preferencesFuture;
    final nutritionToday = await nutritionTodayFuture;
    final weeklyNutrition = await weeklyNutritionFuture;
    final macroDistribution = await macroDistributionFuture;
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
      activityDays.add(dateOnly(sleepEntryDate(sleep)));
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
    final trainingDays = recentTrainingMinutes.where((m) => m > 0).length;
    final targetSessions = preferences?.targetSessionsPerWeek ?? 3;

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

      final calories =
          meal.calories > 0 ? meal.calories : matchingFood.caloriesPer100g;
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
        final date = sleepEntryDate(entry);
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList();
      if (filtered.isEmpty) return 0;
      final total = filtered.fold<double>(0, (sum, entry) => sum + entry.hours);
      return total / filtered.length;
    }

    double _circularStdDev(
      DateTime start,
      DateTime end,
      List<SleepEntry> entries,
      int? Function(SleepEntry) extractor,
    ) {
      final minutes = entries
          .where((e) {
            final date = sleepEntryDate(e);
            return !date.isBefore(start) && !date.isAfter(end);
          })
          .map(extractor)
          .whereType<int>()
          .toList();
      return circularStdDevMinutes(minutes);
    }

    final avgSleepDuration =
        _averageHoursForRange(lastWeekStart, today, sleepEntries);
    final previousSleepAvg =
        _averageHoursForRange(previousWeekStart, previousWeekEnd, sleepEntries);
    final avgSleepDelta = avgSleepDuration - previousSleepAvg;

    final bedStd = _circularStdDev(
      lastWeekStart,
      today,
      sleepEntries,
      (e) => parseHHmmToMinutes(e.bedtime),
    );
    final wakeStd = _circularStdDev(
      lastWeekStart,
      today,
      sleepEntries,
      (e) => parseHHmmToMinutes(e.wakeTime),
    );
    final previousBedStd = _circularStdDev(
      previousWeekStart,
      previousWeekEnd,
      sleepEntries,
      (e) => parseHHmmToMinutes(e.bedtime),
    );
    final previousWakeStd = _circularStdDev(
      previousWeekStart,
      previousWeekEnd,
      sleepEntries,
      (e) => parseHHmmToMinutes(e.wakeTime),
    );
    final regularityScore = ((bedStd + wakeStd) / 2)
        .clamp(0, double.infinity)
        .toDouble();
    final previousRegularity = ((previousBedStd + previousWakeStd) / 2)
        .clamp(0, double.infinity)
        .toDouble();
    final regularityWeekDelta = regularityScore - previousRegularity;

    var averageCalories = 0.0;
    if (weeklyNutrition.isNotEmpty) {
      final totalCalories =
          weeklyNutrition.fold<int>(0, (sum, entry) => sum + entry.totalCalories);
      averageCalories = totalCalories / weeklyNutrition.length;
    } else if (nutritionToday != null) {
      averageCalories = nutritionToday.totalCalories.toDouble();
    }

    final averageDailyMacros = Macros(
      carbs: (macroDistribution.carbs / 7).round(),
      protein: (macroDistribution.protein / 7).round(),
      fat: (macroDistribution.fat / 7).round(),
    );

    final hasUserGoal = (preferences?.primaryGoal?.isNotEmpty ?? false) ||
        (preferences?.targetCalories != null &&
            (preferences?.targetCalories ?? 0) > 0);

    final goalInsight = GoalInsightService().buildInsight(
      preferences: preferences,
      weeklyTrainingMinutes: trainingWeekTotal,
      trainingDays: trainingDays,
      targetSessions: targetSessions,
      averageSleepHours: avgSleepDuration,
      sleepRegularityMinutes: regularityScore,
      averageCalories: averageCalories,
      averageDailyMacros: averageDailyMacros,
    );

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
      goalInsight: goalInsight,
      hasUserGoal: hasUserGoal,
    );
  }

  void _refreshSummary() {
    setState(() {
      _summaryFuture = _loadSummaryData();
    });
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _safeParseDate(String raw) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 20.0;
    const verticalSectionSpacing = 20.0;

    return Scaffold(
      floatingActionButton: _QuickActionsFab(onRefresh: _refreshSummary),
      body: SafeArea(
        child: Container(
          color: AppColors.background,
          child: FutureBuilder<_HomeSummaryData>(
            future: _summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              final data = snapshot.data ?? _HomeSummaryData.empty();

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    20,
                    horizontalPadding,
                    20,
                  ),
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
                          onTap: () async {
                            await Navigator.pushNamed(context, '/streak');
                            _refreshSummary();
                          },
                        ),
                        const SizedBox(height: verticalSectionSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard.training(
                                primaryValue: '${data.trainingToday} min',
                                secondaryValue:
                                    'Promedio semanal: ${data.trainingWeeklyAvg} min',
                                distribution: data.trainingWeeklyDistribution,
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/workout/lite',
                                  );
                                  _refreshSummary();
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricCard.nutrition(
                                calories: data.caloriesToday,
                                macros: data.macrosToday,
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/nutrition/lite',
                                  );
                                  _refreshSummary();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: verticalSectionSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: _SleepInfoCard(
                                avgSleepHours: data.avgSleepDuration,
                                avgSleepDelta: data.avgSleepDelta,
                                onTap: () async {
                                  await Navigator.pushNamed(
                                    context,
                                    '/sleep/overview',
                                  );
                                  _refreshSummary();
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SleepMetricsCard(
                                regularityScore: data.regularityScore,
                                regularityDelta: data.regularityWeekDelta,
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/sleep/overview',
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: verticalSectionSpacing),
                        if (!data.hasUserGoal)
                          _PendingGoalCard(
                            onTap: () {
                              Navigator.pushNamed(context, '/onboarding');
                            },
                          )
                        else
                          _GoalInsightCard(data: data.goalInsight),
                        const SizedBox(height: verticalSectionSpacing),
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
    required this.goalInsight,
    required this.hasUserGoal,
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
      goalInsight: GoalInsightData(
        title: 'Objetivo pendiente',
        subtitle: 'Completa tu onboarding',
        metricPills: const <String>[],
        insightText: 'Configura tu objetivo para ver recomendaciones.',
      ),
      hasUserGoal: false,
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
  final GoalInsightData goalInsight;
  final bool hasUserGoal;
}

class _QuickActionsFab extends StatefulWidget {
  const _QuickActionsFab({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  State<_QuickActionsFab> createState() => _QuickActionsFabState();
}

class _QuickActionsFabState extends State<_QuickActionsFab> {
  Future<void> _testFirebaseWrite(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tenés que iniciar sesión para guardar en Firebase.'),
        ),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('debug')
          .add({
        'createdAt': FieldValue.serverTimestamp(),
        'from': 'home_summary',
        'note': 'test write',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Guardado OK en Firestore (users/{uid}/debug)'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error guardando en Firestore: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guardamos el context de la pantalla (no el del bottom sheet),
    // porque el del bottom sheet se destruye cuando hacemos pop().
    final rootContext = context;

    return FloatingActionButton(
      backgroundColor: const Color(0xFF1D6C6F),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  _FabAction(
                    icon: Icons.fitness_center_rounded,
                    label: 'Registrar actividad',
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(rootContext, '/workout/lite');
                      widget.onRefresh();
                    },
                  ),
                  _FabAction(
                    icon: Icons.auto_graph_rounded,
                    label: 'Ver estadísticas',
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(rootContext, '/analytics/overview');
                      widget.onRefresh();
                    },
                  ),
                  _FabAction(
                    icon: Icons.cloud_done_rounded,
                    label: 'Probar guardado en Firebase',
                    onTap: () async {
                      Navigator.pop(context);
                      await _testFirebaseWrite(rootContext);
                    },
                  ),
                  _FabAction(
                    icon: Icons.group_rounded,
                    label: 'Ir a grupos',
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.pushNamed(rootContext, '/groups/list');
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      child: const Icon(Icons.add_rounded),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nameGreeting = 'Hola';
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
          'Hoy · $formattedDate',
          style: textTheme.labelMedium?.copyWith(
            color: const Color(0xFF9BA7B4),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$nameGreeting 👋',
          style: textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Este es tu resumen de hoy',
          style: textTheme.bodySmall?.copyWith(
            color: const Color(0xFF9BA7B4),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GoalInsightCard extends StatelessWidget {
  const _GoalInsightCard({required this.data});

  final GoalInsightData data;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      minHeight: 150,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9BA7B4),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF7CF4FF),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: data.metricPills
                .map((pill) => _InsightPill(label: pill))
                .toList(),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_rounded,
                color: Color(0xFFA4A7FF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.insightText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFE4E8EE),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingGoalCard extends StatelessWidget {
  const _PendingGoalCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      minHeight: 150,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Objetivo pendiente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF7CF4FF),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Completa tu onboarding',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFE4E8EE),
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(
                Icons.psychology_alt_rounded,
                size: 16,
                color: Color(0xFF9BA7B4),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Configura tu objetivo para ver recomendaciones.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9BA7B4),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  const _InsightPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2834),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F3B4C)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFFE4E8EE),
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
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
    final gradient = _streakGradient(activeDays);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: gradient,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -24,
                right: -30,
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white.withOpacity(0.07),
                  size: 140,
                ),
              ),
              Positioned(
                bottom: -30,
                left: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _BreathingIcon(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.16),
                        ),
                        child: const Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _StreakDetails(
                        activeDays: activeDays,
                        dots: dots,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Racha activa',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$activeDays días',
          style: textTheme.displaySmall?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ) ??
              const TextStyle(fontSize: 30, color: Colors.white),
        ),
        const SizedBox(height: 14),
        _StreakDots(dots: dots),
      ],
    );
  }
}

class _StreakDots extends StatelessWidget {
  const _StreakDots({required this.dots});

  final List<bool> dots;

  @override
  Widget build(BuildContext context) {
    final gradientColors = [
      const Color(0xFFFF8864),
      const Color(0xFFFF7B4F),
      const Color(0xFFFF6E3B),
      const Color(0xFFFF632C),
      const Color(0xFFFF5A24),
      const Color(0xFFF74F27),
      const Color(0xFFE7462A),
      const Color(0xFFD83C30),
      const Color(0xFFC83235),
      const Color(0xFFB92A3A),
      const Color(0xFFA9233F),
      const Color(0xFF9B1C43),
    ];

    final activeCount = dots.where((active) => active).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$activeCount/12 días recientes activos',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ) ??
              const TextStyle(fontSize: 12, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(12, (index) {
            final isActive = index < dots.length ? dots[index] : false;
            return Container(
              width: 10,
              height: 10,
              margin: EdgeInsets.only(right: index == 11 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive
                    ? gradientColors[index]
                    : Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  const _BreathingIcon({required this.child});

  final Widget child;

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 0.98 + (_controller.value * 0.04);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: Colors.white,
        ),
      ),
      title: Text(
        label,
        style: textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

LinearGradient _streakGradient(int activeDays) {
  if (activeDays <= 3) {
    return const LinearGradient(
      colors: [Color(0xFF3D1A24), Color(0xFF742B2F), Color(0xFFFF6E3B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  if (activeDays <= 10) {
    return const LinearGradient(
      colors: [Color(0xFF2B1F35), Color(0xFF8B3E2F), Color(0xFFFFB347)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  return const LinearGradient(
    colors: [Color(0xFF123E55), Color(0xFF1D6C6F), Color(0xFF7CF4B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard._({
    required this.title,
    required this.value,
    required this.valueColor,
    required this.content,
    required this.trend,
    required this.onTap,
  });

  factory _MetricCard.training({
    required String primaryValue,
    required String secondaryValue,
    required List<int> distribution,
    required VoidCallback onTap,
  }) {
    final trainingToday = int.tryParse(primaryValue.split(' ').first) ?? 0;
    final weeklyTotal = distribution.fold<int>(0, (sum, v) => sum + v);
    final weeklyAvg = distribution.isNotEmpty
        ? (weeklyTotal / distribution.length).clamp(0, double.infinity)
        : 0;
    final difference =
        weeklyAvg == 0 ? 0 : ((trainingToday - weeklyAvg) / weeklyAvg) * 100;
    return _MetricCard._(
      title: 'Entrenamiento',
      value: primaryValue,
      valueColor: const Color(0xFF2AF5D2),
      content: _TrainingChart(
        secondaryValue: secondaryValue,
        distribution: distribution,
      ),
      trend: TrendChipData.fromDelta(difference.round()),
      onTap: onTap,
    );
  }

  factory _MetricCard.nutrition({
    required int calories,
    required Macros macros,
    required VoidCallback onTap,
  }) {
    final delta = calories > 0 ? (calories - 2000) / 2000 * 100 : 0;
    return _MetricCard._(
      title: 'Alimentación',
      value: '${calories.toString()} kcal',
      valueColor: Colors.white,
      content: _NutritionCharts(macros: macros),
      trend: TrendChipData(
        label: calories == 0
            ? 'Sin registros hoy'
            : delta.abs() <= 10
                ? 'En rango'
                : delta > 0
                    ? '+${delta.round()}% vs objetivo'
                    : '${delta.round()}% vs objetivo',
        tone: delta.abs() <= 10
            ? TrendTone.neutral
            : delta > 0
                ? TrendTone.positive
                : TrendTone.negative,
      ),
      onTap: onTap,
    );
  }

  final String title;
  final String value;
  final Color valueColor;
  final Widget content;
  final TrendChipData trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SummaryCard(
      minHeight: 170,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TrendChip(data: trend),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
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
    final effectiveDistribution =
        distribution.isEmpty ? List.filled(7, 0) : distribution;
    final maxMinutes = effectiveDistribution.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
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
              final normalized =
                  maxMinutes == 0 ? 0.2 : (value / maxMinutes).clamp(0.2, 1.0);
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

enum TrendTone { positive, neutral, negative }

class TrendChipData {
  const TrendChipData({required this.label, required this.tone});

  factory TrendChipData.fromDelta(int delta) {
    if (delta == 0) {
      return const TrendChipData(label: 'En rango', tone: TrendTone.neutral);
    }
    if (delta > 0) {
      return TrendChipData(
        label: '+$delta% esta semana',
        tone: TrendTone.positive,
      );
    }
    return TrendChipData(label: '$delta% esta semana', tone: TrendTone.negative);
  }

  final String label;
  final TrendTone tone;
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.data});

  final TrendChipData data;

  Color _background(BuildContext context) {
    switch (data.tone) {
      case TrendTone.positive:
        return const Color(0x332AD27A);
      case TrendTone.neutral:
        return Colors.amber.withOpacity(0.18);
      case TrendTone.negative:
        return const Color(0x33FF6A6A);
    }
  }

  Color _foreground(BuildContext context) {
    switch (data.tone) {
      case TrendTone.positive:
        return const Color(0xFF34D27B);
      case TrendTone.neutral:
        return const Color(0xFFFFD166);
      case TrendTone.negative:
        return const Color(0xFFFF6A6A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: _foreground(context),
          fontWeight: FontWeight.w600,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _background(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(data.label, style: textStyle),
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
                    borderRadius:
                        BorderRadius.horizontal(left: Radius.circular(999)),
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
                    borderRadius:
                        BorderRadius.horizontal(right: Radius.circular(999)),
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
    final tone = deltaPositive
        ? TrendTone.positive
        : avgSleepDelta.abs() < 0.3
            ? TrendTone.neutral
            : TrendTone.negative;
    final trend = TrendChipData(
      label: deltaPositive ? 'Mejorando descanso' : 'Por debajo del objetivo',
      tone: tone,
    );
    final textTheme = Theme.of(context).textTheme;

    return SummaryCard(
      minHeight: 170,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sueño',
            style: textTheme.titleMedium?.copyWith(
              fontSize: 17,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formattedHours,
            style: textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              color: const Color(0xFFA4A7FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _TrendChip(data: trend),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                deltaPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color:
                    deltaPositive ? const Color(0xFF7CF4FF) : const Color(0xFFFF6A6A),
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
          Text(
            'Promedio últimos 7 días',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9BA7B4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SleepMetricsCard extends StatelessWidget {
  const _SleepMetricsCard({
    required this.regularityScore,
    required this.regularityDelta,
    required this.onTap,
  });

  final double regularityScore;
  final double regularityDelta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final improved = regularityDelta <= 0;
    final variability = regularityScore.round();
    final deltaMinutes = regularityDelta.abs().round();
    final trend = TrendChipData(
      label: improved ? 'En rango' : 'Por debajo del objetivo',
      tone: improved ? TrendTone.positive : TrendTone.negative,
    );
    final textTheme = Theme.of(context).textTheme;

    return SummaryCard(
      minHeight: 170,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Regularidad del Sueño',
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                improved ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: improved ? const Color(0xFF34D27B) : const Color(0xFFFF6A6A),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TrendChip(data: trend),
          const SizedBox(height: 8),
          Text(
            'Variabilidad de horario',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF9BA7B4),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${variability} min',
                style: textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      color: const Color(0xFF7CF4FF),
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(fontSize: 22, color: Color(0xFF7CF4FF)),
              ),
              const SizedBox(width: 8),
              Icon(
                improved ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: improved ? const Color(0xFF34D27B) : const Color(0xFFFF6A6A),
                size: 18,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${deltaMinutes} min vs semana previa',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9BA7B4),
                        fontWeight: FontWeight.w600,
                      ) ??
                      const TextStyle(fontSize: 12, color: Color(0xFF9BA7B4)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
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
    return SummaryCard(
      minHeight: 150,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
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
              Icons.group_rounded,
              color: Color(0xFF7CF4FF),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grupos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ) ??
                      const TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gestiona y analiza tus grupos de usuarios',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF9BA7B4),
                        fontWeight: FontWeight.w500,
                      ) ??
                      const TextStyle(fontSize: 14, color: Color(0xFF9BA7B4)),
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
    );
  }
}
