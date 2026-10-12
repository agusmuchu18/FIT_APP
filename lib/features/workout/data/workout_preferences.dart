import 'dart:convert';

import '../../../core/data/account_storage_scope.dart';

class WorkoutPreferences {
  const WorkoutPreferences({
    this.defaultRestEnabled = false,
    this.defaultRestSeconds = 90,
  });

  static const storageKey = 'workout_preferences_v1';
  final bool defaultRestEnabled;
  final int defaultRestSeconds;

  WorkoutPreferences copyWith({
    bool? defaultRestEnabled,
    int? defaultRestSeconds,
  }) {
    return WorkoutPreferences(
      defaultRestEnabled: defaultRestEnabled ?? this.defaultRestEnabled,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    );
  }

  static Future<WorkoutPreferences> load() async {
    final prefs = await ScopedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return const WorkoutPreferences();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final seconds = json['defaultRestSeconds'] as int? ?? 90;
      return WorkoutPreferences(
        defaultRestEnabled: json['defaultRestEnabled'] as bool? ?? false,
        defaultRestSeconds: seconds > 0 && seconds <= 3600 ? seconds : 90,
      );
    } catch (_) {
      return const WorkoutPreferences();
    }
  }

  Future<void> save() async {
    final prefs = await ScopedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode({
        'defaultRestEnabled': defaultRestEnabled,
        'defaultRestSeconds': defaultRestSeconds,
      }),
    );
  }
}
