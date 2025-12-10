import '../domain/entities.dart';

/// Placeholder remote sync using Firebase/REST.
class RemoteSyncService {
  const RemoteSyncService();

  Future<void> syncWorkout(WorkoutEntry entry) async {
    // Integrate Firebase or REST client here.
  }

  Future<void> syncMeal(MealEntry entry) async {}

  Future<void> syncSleep(SleepEntry entry) async {}

  Future<void> syncPreferences(UserPreferences preferences) async {}
}
