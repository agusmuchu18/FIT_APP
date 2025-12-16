import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/entities.dart';

/// Local storage facade to keep data layer swappable (Hive, Sqflite, etc.).
class LocalStorageService {
  LocalStorageService._(
    this._workoutsBox,
    this._mealsBox,
    this._sleepBox,
    this._prefsBox,
  );

  final Box<String> _workoutsBox;
  final Box<String> _mealsBox;
  final Box<String> _sleepBox;
  final Box<String> _prefsBox;

  static Future<LocalStorageService> create() async {
    final workoutsBox = await Hive.openBox<String>('fit_workouts');
    final mealsBox = await Hive.openBox<String>('fit_meals');
    final sleepBox = await Hive.openBox<String>('fit_sleep');
    final prefsBox = await Hive.openBox<String>('fit_prefs');
    return LocalStorageService._(workoutsBox, mealsBox, sleepBox, prefsBox);
  }

  Future<void> saveWorkout(WorkoutEntry entry) async {
    await _workoutsBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  Future<List<WorkoutEntry>> fetchWorkouts() async {
    return _workoutsBox.values
        .map((raw) => _safeDecode(raw, WorkoutEntry.fromJson))
        .whereType<WorkoutEntry>()
        .toList();
  }

  Future<void> saveMeal(MealEntry entry) async {
    await _mealsBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  Future<List<MealEntry>> fetchMeals() async {
    return _mealsBox.values
        .map((raw) => _safeDecode(raw, MealEntry.fromJson))
        .whereType<MealEntry>()
        .toList();
  }

  Future<void> saveSleep(SleepEntry entry) async {
    await _sleepBox.put(entry.id, jsonEncode(entry.toJson()));
  }

  Future<List<SleepEntry>> fetchSleep() async {
    return _sleepBox.values
        .map((raw) => _safeDecode(raw, SleepEntry.fromJson))
        .whereType<SleepEntry>()
        .toList();
  }

  Future<void> savePreferences(UserPreferences preferences) async {
    await _prefsBox.put('prefs', jsonEncode(preferences.toJson()));
  }

  Future<UserPreferences?> fetchPreferences() async {
    final raw = _prefsBox.get('prefs');
    if (raw == null) return null;
    return _safeDecode(raw, UserPreferences.fromJson);
  }

  T? _safeDecode<T>(String raw, T Function(Map<String, Object?>) factoryFn) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, Object?>) {
        return factoryFn(map);
      }
      if (map is Map<String, dynamic>) {
        return factoryFn(map.cast<String, Object?>());
      }
    } catch (_) {}
    return null;
  }
}
