import 'local_storage_service.dart';
import 'remote_sync_service.dart';
import 'statistics_service.dart';
import '../domain/entities.dart';

class FitnessRepository {
  FitnessRepository({
    required LocalStorageService local,
    required RemoteSyncService remote,
    required StatisticsService statistics,
  })  : _local = local,
        _remote = remote,
        _statistics = statistics;

  final LocalStorageService _local;
  final RemoteSyncService _remote;
  final StatisticsService _statistics;

  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    await _local.saveWorkout(entry);
    if (sync) await _remote.syncWorkout(entry);
  }

  Future<List<WorkoutEntry>> getWorkouts() => _local.fetchWorkouts();

  Future<void> saveMeal(MealEntry entry, {bool sync = false}) async {
    await _local.saveMeal(entry);
    if (sync) await _remote.syncMeal(entry);
  }

  Future<List<MealEntry>> getMeals() => _local.fetchMeals();

  Future<void> saveSleep(SleepEntry entry, {bool sync = false}) async {
    await _local.saveSleep(entry);
    await _statistics.recordSleepInsights(entry);
    if (sync) await _remote.syncSleep(entry);
  }

  Future<List<SleepEntry>> getSleep() => _local.fetchSleep();

  Future<void> savePreferences(UserPreferences preferences, {bool sync = false}) async {
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
      NutritionMetrics(date: date, totalCalories: totalCalories, macros: macros),
    );
  }

  Future<NutritionMetrics?> getDailyNutritionStats(DateTime date) {
    return _statistics.getNutritionMetrics(date);
  }

  Future<List<NutritionMetrics>> getWeeklyNutritionStats({int days = 7}) {
    return _statistics.getNutritionHistory(days: days);
  }

  Future<Macros> getMacroDistribution({int days = 7}) {
    return _statistics.getMacroDistribution(days: days);
  }

  Future<List<SleepEntry>> getRecentSleep({int days = 7}) {
    return _statistics.getSleepEntries(days: days);
  }

  Future<Map<DateTime, int>> getWorkoutDurationByDay({int days = 7}) async {
    final workouts = await _local.fetchWorkouts();
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    final Map<DateTime, int> minutesByDay = {};
    for (final workout in workouts) {
      final date = _safeParseDate(workout.id);
      if (date.isBefore(startDate) || date.isAfter(now)) continue;
      final day = DateTime(date.year, date.month, date.day);
      minutesByDay[day] = (minutesByDay[day] ?? 0) + workout.durationMinutes;
    }

    return minutesByDay;
  }

  DateTime _safeParseDate(String raw) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
}
