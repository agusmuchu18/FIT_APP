import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart';
import '../../../main.dart';

class HomeSummaryScreen extends StatefulWidget {
  const HomeSummaryScreen({super.key});

  @override
  State<HomeSummaryScreen> createState() => _HomeSummaryScreenState();
}

class _HomeSummaryScreenState extends State<HomeSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<_HomeSummaryData> _loadSummary(FitnessRepository repository) async {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    final nutritionToday = await repository.getDailyNutritionStats(now);
    final macros = await repository.getMacroDistribution(days: 7);
    final workoutDurations = await repository.getWorkoutDurationByDay(days: 7);
    final sleepEntries = await repository.getRecentSleep(days: 7);

    final todayMinutes = workoutDurations[todayKey] ?? 0;
    final weeklyMinutes =
        workoutDurations.values.fold<int>(0, (sum, value) => sum + value);
    final averageMinutes = workoutDurations.isEmpty
        ? 0
        : (weeklyMinutes / workoutDurations.length).round();

    final averageSleepHours = sleepEntries.isEmpty
        ? 0
        : sleepEntries
                .map((entry) => entry.hours)
                .reduce((a, b) => a + b) /
            sleepEntries.length;

    return _HomeSummaryData(
      calories: nutritionToday?.totalCalories ?? 0,
      macros: macros,
      trainingMinutes: todayMinutes,
      secondaryTrainingMinutes: averageMinutes,
      sleepHours: averageSleepHours,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = RepositoryScope.of(context);
    const backgroundColor = Color(0xFF0E1624);

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: backgroundColor,
          child: FutureBuilder<_HomeSummaryData>(
            future: _loadSummary(repository),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }

              final data = snapshot.data ??
                  _HomeSummaryData(
                    calories: 0,
                    macros: Macros(carbs: 1, protein: 1, fat: 1),
                    trainingMinutes: 0,
                    secondaryTrainingMinutes: 0,
                    sleepHours: 0,
                  );

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HeaderSection(),
                          const SizedBox(height: 24),
                          const _StreakCard(),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard.training(
                                  primaryValue: '${data.trainingMinutes} min',
                                  secondaryValue: '${data.secondaryTrainingMinutes} min',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _MetricCard.nutrition(
                                  calories: data.calories,
                                  macros: data.macros,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Expanded(child: _SleepInfoCard()),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _SleepMetricsCard(
                                  hours: data.sleepHours,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          const _RegisterActivityButton(),
                        ],
                      ),
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
    required this.calories,
    required this.macros,
    required this.trainingMinutes,
    required this.secondaryTrainingMinutes,
    required this.sleepHours,
  });

  final int calories;
  final Macros macros;
  final int trainingMinutes;
  final int secondaryTrainingMinutes;
  final double sleepHours;
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
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          _StreakIcon(),
          SizedBox(width: 16),
          Expanded(child: _StreakDetails()),
        ],
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
  const _StreakDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Racha activa',
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFFE4E8EE),
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: 4),
        Text(
          '12 días',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        SizedBox(height: 14),
        _StreakDotsRow(),
      ],
    );
  }
}

class _StreakDotsRow extends StatelessWidget {
  const _StreakDotsRow();

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
        return Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.only(right: index == 11 ? 0 : 6),
          decoration: BoxDecoration(
            color: gradientColors[index],
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
  });

  factory _MetricCard.training({
    required String primaryValue,
    required String secondaryValue,
  }) {
    return _MetricCard._(
      title: 'Entrenamiento',
      value: primaryValue,
      valueColor: const Color(0xFF2AF5D2),
      content: _TrainingChart(secondaryValue: secondaryValue),
    );
  }

  factory _MetricCard.nutrition({
    required int calories,
    required Macros macros,
  }) {
    return _MetricCard._(
      title: 'Alimentación',
      value: '${calories.toString()} kcal',
      valueColor: Colors.white,
      content: _NutritionCharts(macros: macros),
    );
  }

  final String title;
  final String value;
  final Color valueColor;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
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
    );
  }
}

class _TrainingChart extends StatelessWidget {
  const _TrainingChart({required this.secondaryValue});

  final String secondaryValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _MiniBar(height: 12),
              _MiniBar(height: 28),
              _MiniBar(height: 20),
              _MiniBar(height: 32),
              _MiniBar(height: 16),
              _MiniBar(height: 24),
            ],
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
        const SizedBox(
          height: 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniBarNeutral(height: 10),
              _MiniBarNeutral(height: 16),
              _MiniBarNeutral(height: 6),
              _MiniBarNeutral(height: 18),
              _MiniBarNeutral(height: 12),
              _MiniBarNeutral(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniBarNeutral extends StatelessWidget {
  const _MiniBarNeutral({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF5F6A7A),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SleepInfoCard extends StatelessWidget {
  const _SleepInfoCard();

  @override
  Widget build(BuildContext context) {
    return const SummaryCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sueño',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFFE4E8EE),
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 12),
          _SleepBulletItem(
            color: Color(0xFF7B5CFF),
            title: 'Entrenamiento',
            highlight: 'Semanal',
          ),
          SizedBox(height: 8),
          _SleepBulletItem(
            color: Color(0xFF8F9AE6),
            title: 'Regularidad',
            highlight: 'del Sueño',
          ),
        ],
      ),
    );
  }
}

class _SleepBulletItem extends StatelessWidget {
  const _SleepBulletItem({
    required this.color,
    required this.title,
    required this.highlight,
  });

  final Color color;
  final String title;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7785A0),
              fontWeight: FontWeight.w400,
              fontFamily: 'Inter',
            ),
            children: [
              TextSpan(
                text: '$title ',
                style: const TextStyle(color: Color(0xFF92A0C0)),
              ),
              TextSpan(
                text: highlight,
                style: const TextStyle(
                  color: Color(0xFF5E7CFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SleepMetricsCard extends StatelessWidget {
  const _SleepMetricsCard({required this.hours});

  final double hours;

  @override
  Widget build(BuildContext context) {
    final hoursPart = hours.floor();
    final minutesPart = ((hours - hoursPart) * 60).round();
    final formattedHours =
        '${hoursPart.toString()} h ${minutesPart.toString().padLeft(2, '0')} min';

    return SummaryCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Flexible(
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
                Icons.arrow_upward_rounded,
                color: Color(0xFF34D27B),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tendencias',
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
                formattedHours,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFA4A7FF),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_downward_rounded,
                color: Color(0xFF7B5CFF),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegisterActivityButton extends StatelessWidget {
  const _RegisterActivityButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: BorderSide(color: Colors.white.withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: Colors.white,
        ),
        icon: const Icon(
          Icons.add_rounded,
          color: Color(0xFF7CF4FF),
        ),
        label: const Text(
          '+ Registrar Actividad',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}
