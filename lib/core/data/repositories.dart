import 'local_storage_service.dart';
import 'remote_sync_service.dart';
import '../domain/entities.dart';

class FitnessRepository {
  FitnessRepository({
    required LocalStorageService local,
    required RemoteSyncService remote,
  })  : _local = local,
        _remote = remote;

  final LocalStorageService _local;
  final RemoteSyncService _remote;

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
}
