import '../domain/entities.dart';

/// Local storage facade to keep data layer swappable (Hive, Sqflite, etc.).
class LocalStorageService {
  LocalStorageService();

  final List<WorkoutEntry> _workouts = [];
  final List<MealEntry> _meals = [];
  final List<SleepEntry> _sleepLogs = [];
  UserPreferences? _preferences;

  Future<void> saveWorkout(WorkoutEntry entry) async {
    _workouts.removeWhere((item) => item.id == entry.id);
    _workouts.add(entry);
  }

  Future<List<WorkoutEntry>> fetchWorkouts() async {
    return List.unmodifiable(_workouts);
  }

  Future<void> saveMeal(MealEntry entry) async {
    _meals.removeWhere((item) => item.id == entry.id);
    _meals.add(entry);
  }

  Future<List<MealEntry>> fetchMeals() async {
    return List.unmodifiable(_meals);
  }

  Future<void> saveSleep(SleepEntry entry) async {
    _sleepLogs.removeWhere((item) => item.id == entry.id);
    _sleepLogs.add(entry);
  }

  Future<List<SleepEntry>> fetchSleep() async {
    return List.unmodifiable(_sleepLogs);
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    _preferences = preferences;
  }

  Future<UserPreferences?> fetchPreferences() async {
    return _preferences;
  }
}
