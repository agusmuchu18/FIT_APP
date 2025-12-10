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
}
