import '../../../core/domain/entities.dart';
import '../../sleep/domain/sleep_time_utils.dart';

DateTime normalizeDay(DateTime day) => DateTime(day.year, day.month, day.day);

Set<DateTime> buildActiveDaysSet({
  required List<WorkoutEntry> workouts,
  required List<MealEntry> meals,
  required List<SleepEntry> sleepEntries,
}) {
  final activeDays = <DateTime>{};

  for (final workout in workouts) {
    activeDays.add(normalizeDay(workoutEntryDate(workout)));
  }
  for (final meal in meals) {
    activeDays.add(normalizeDay(meal.recordedAt));
  }
  for (final sleep in sleepEntries) {
    activeDays.add(normalizeDay(sleepEntryDate(sleep)));
  }

  return activeDays;
}

bool hasActivity({required DateTime day, required Set<DateTime> activeDays}) {
  return activeDays.contains(normalizeDay(day));
}

HomeDayActivitySummary getActivityForDay({
  required DateTime day,
  required List<WorkoutEntry> workouts,
  required List<MealEntry> meals,
  required List<SleepEntry> sleepEntries,
}) {
  final normalized = normalizeDay(day);
  final dayWorkouts = workouts
      .where((workout) => normalizeDay(workoutEntryDate(workout)) == normalized)
      .toList(growable: false);
  final dayMeals = meals
      .where((meal) => normalizeDay(meal.recordedAt) == normalized)
      .toList(growable: false);
  final daySleep = sleepEntries
      .where((sleep) => normalizeDay(sleepEntryDate(sleep)) == normalized)
      .toList(growable: false);

  final trainingMinutes = dayWorkouts.fold<int>(
    0,
    (sum, workout) => sum + workout.durationMinutes,
  );
  final calories = dayMeals
      .fold<double>(0, (sum, meal) => sum + meal.energyKcal)
      .round();

  return HomeDayActivitySummary(
    day: normalized,
    workouts: dayWorkouts,
    meals: dayMeals,
    sleepEntries: daySleep,
    totalTrainingMinutes: trainingMinutes,
    totalCalories: calories,
    hasActivity:
        dayWorkouts.isNotEmpty || dayMeals.isNotEmpty || daySleep.isNotEmpty,
  );
}

class HomeDayActivitySummary {
  const HomeDayActivitySummary({
    required this.day,
    required this.workouts,
    required this.meals,
    required this.sleepEntries,
    required this.totalTrainingMinutes,
    required this.totalCalories,
    required this.hasActivity,
  });

  final DateTime day;
  final List<WorkoutEntry> workouts;
  final List<MealEntry> meals;
  final List<SleepEntry> sleepEntries;
  final int totalTrainingMinutes;
  final int totalCalories;
  bool get hasIncompleteEnergy =>
      meals.any((m) => m.unknownNutrients.contains('kcal'));
  final bool hasActivity;
}
