import 'package:flutter/foundation.dart';

import 'local_storage_service.dart';
import 'remote_sync_service.dart';
import 'statistics_service.dart';
import '../domain/entities.dart';

class FitnessRepository {
  FitnessRepository({
    required this._local,
    required this._remote,
    required this._statistics,
  });

  final LocalStorageService _local;
  final RemoteSyncService _remote;
  final StatisticsService _statistics;
  final ValueNotifier<int> workoutsRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> mealsRevision = ValueNotifier<int>(0);

  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    await _local.saveWorkout(entry);
    workoutsRevision.value++;
    if (sync) await _remote.syncWorkout(entry);
  }

  Future<List<WorkoutEntry>> getWorkouts() async =>
      (await _local.fetchWorkouts()).where((e) => !e.deleted).toList();

  /// Includes tombstones solely for idempotent local projection reconciliation.
  Future<List<WorkoutEntry>> getWorkoutProjections() => _local.fetchWorkouts();

  Future<void> saveMeal(MealEntry entry, {bool sync = false}) async {
    await _local.saveMeal(entry);
    mealsRevision.value++;
    if (sync) await _remote.syncMeal(entry);
  }

  Future<List<MealEntry>> getMealProjections() => _local.fetchMeals();

  Future<List<MealEntry>> getMeals() async =>
      (await _local.fetchMeals()).where((m) => !m.deleted).toList();

  Future<void> saveSleep(SleepEntry entry, {bool sync = false}) async {
    await _local.saveSleep(entry);
    await _statistics.recordSleepInsights(entry);
    if (sync) await _remote.syncSleep(entry);
  }

  Future<List<SleepEntry>> getSleep() => _local.fetchSleep();

  Future<void> savePreferences(
    UserPreferences preferences, {
    bool sync = false,
  }) async {
    await _local.savePreferences(preferences);
    if (sync) await _remote.syncPreferences(preferences);
  }

  Future<UserPreferences?> getPreferences() => _local.fetchPreferences();

  Future<void> exportNutritionStats({
    required DateTime date,
    required int totalCalories,
    required Macros macros,
  }) async {
    await _statistics.recordNutritionMetrics(
      NutritionMetrics(
        date: date,
        totalCalories: totalCalories,
        macros: macros,
      ),
    );
  }

  Future<NutritionMetrics?> getDailyNutritionStats(DateTime date) {
    return _nutritionHistory().then(
      (rows) => rows
          .where((r) => r.date == DateTime(date.year, date.month, date.day))
          .firstOrNull,
    );
  }

  Future<List<NutritionMetrics>> getWeeklyNutritionStats({int days = 7}) {
    return _nutritionHistory(days: days);
  }

  Future<Macros> getMacroDistribution({int days = 7}) async => _statistics
      .summarizeNutrition(await _nutritionMeals(days: days), DateTime.now())
      .macros;

  Future<List<MealEntry>> _nutritionMeals({int? days}) async {
    final rows = await getMeals();
    if (days == null) return rows;
    final now = DateTime.now(),
        start = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day - days + 1,
        );
    final end = DateTime(now.year, now.month, now.day + 1);
    return rows
        .where(
          (m) => !m.recordedAt.isBefore(start) && m.recordedAt.isBefore(end),
        )
        .toList();
  }

  Future<List<NutritionMetrics>> _nutritionHistory({int? days}) async {
    final grouped = <DateTime, List<MealEntry>>{};
    for (final m in await _nutritionMeals(days: days)) {
      final date = DateTime(
        m.recordedAt.year,
        m.recordedAt.month,
        m.recordedAt.day,
      );
      grouped.putIfAbsent(date, () => []).add(m);
    }
    return [
      for (final entry in grouped.entries)
        _statistics.summarizeNutrition(entry.value, entry.key),
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<SleepEntry>> getRecentSleep({int days = 7}) {
    return _statistics.getSleepEntries(days: days);
  }

  Future<Map<DateTime, int>> getWorkoutDurationByDay({int days = 7}) async {
    final workouts = await _local.fetchWorkouts();
    final now = DateTime.now();
    final startDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));

    final Map<DateTime, int> minutesByDay = {};
    for (final workout in workouts) {
      final date = workoutEntryDate(workout);
      if (date.isBefore(startDate) || date.isAfter(now)) continue;
      final day = DateTime(date.year, date.month, date.day);
      minutesByDay[day] = (minutesByDay[day] ?? 0) + workout.durationMinutes;
    }

    return minutesByDay;
  }
}
