import 'package:flutter/material.dart';

import '../../../core/domain/entities.dart';
import '../../../main.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  Future<_StreakData> _loadData(BuildContext context) async {
    final repository = RepositoryScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final workoutsFuture = repository.getWorkouts();
    final mealsFuture = repository.getMeals();
    final sleepFuture = repository.getSleep();

    final workouts = await workoutsFuture;
    final meals = await mealsFuture;
    final sleepEntries = await sleepFuture;

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
    for (var i = 0;; i++) {
      final day = today.subtract(Duration(days: i));
      if (activityDays.contains(day)) {
        streak++;
      } else {
        break;
      }
    }

    final recentDays = List.generate(14, (index) {
      final day = today.subtract(Duration(days: index));
      return _DayActivityStatus(
        date: day,
        hasActivity: activityDays.contains(day),
      );
    });

    return _StreakData(streak: streak, recentDays: recentDays);
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0E1624);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'Racha activa',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<_StreakData>(
        future: _loadData(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator.adaptive(),
            );
          }

          final data = snapshot.data ?? _StreakData.empty();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroCard(streak: data.streak),
                const SizedBox(height: 20),
                const _ExplanationSection(),
                const SizedBox(height: 16),
                _RecentDaysList(days: data.recentDays),
              ],
            ),
          );
        },
      ),
    );
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _safeParseDate(String raw) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
}

class _StreakData {
  const _StreakData({required this.streak, required this.recentDays});

  factory _StreakData.empty() {
    return _StreakData(streak: 0, recentDays: const []);
  }

  final int streak;
  final List<_DayActivityStatus> recentDays;
}

class _DayActivityStatus {
  const _DayActivityStatus({required this.date, required this.hasActivity});

  final DateTime date;
  final bool hasActivity;
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return _DecoratedCard(
      padding: const EdgeInsets.all(22),
      child: Column(
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
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$streak',
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Inter',
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'días consecutivos',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF9BA7B4),
                    fontWeight: FontWeight.w600,
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

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection();

  @override
  Widget build(BuildContext context) {
    return _DecoratedCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Cómo se calcula',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: 10),
          Text(
            'La racha aumenta cada día que registras al menos un entrenamiento, '
            'una comida o una sesión de sueño. Se reinicia si hay un día sin '
            'actividad registrada.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9BA7B4),
              height: 1.4,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentDaysList extends StatelessWidget {
  const _RecentDaysList({required this.days});

  final List<_DayActivityStatus> days;

  @override
  Widget build(BuildContext context) {
    final weekdayNames = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

    return _DecoratedCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Últimos días',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (context, index) {
              final dayStatus = days[index];
              final date = dayStatus.date;
              final weekdayLabel = weekdayNames[date.weekday - 1];
              final dateLabel = '${date.day.toString().padLeft(2, '0')}/'
                  '${date.month.toString().padLeft(2, '0')}';

              return Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: dayStatus.hasActivity
                          ? const Color(0xFF1D2C3A)
                          : const Color(0xFF101722),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: dayStatus.hasActivity
                            ? const Color(0xFF2AF5D2)
                            : const Color(0xFF1F2B3C),
                      ),
                    ),
                    child: Icon(
                      dayStatus.hasActivity
                          ? Icons.check_rounded
                          : Icons.remove_rounded,
                      color: dayStatus.hasActivity
                          ? const Color(0xFF2AF5D2)
                          : const Color(0xFF6F7C93),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekdayLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9BA7B4),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: dayStatus.hasActivity
                          ? const Color(0x1A2AF5D2)
                          : const Color(0x112AF5D2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: dayStatus.hasActivity
                            ? const Color(0xFF2AF5D2)
                            : const Color(0xFF233146),
                      ),
                    ),
                    child: Text(
                      dayStatus.hasActivity ? 'Actividad registrada' : 'Sin actividad',
                      style: TextStyle(
                        fontSize: 12,
                        color: dayStatus.hasActivity
                            ? const Color(0xFF2AF5D2)
                            : const Color(0xFF6F7C93),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: days.length,
          ),
        ],
      ),
    );
  }
}

class _DecoratedCard extends StatelessWidget {
  const _DecoratedCard({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161F2C),
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
