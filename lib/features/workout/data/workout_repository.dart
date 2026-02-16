import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_models.dart';

class WorkoutRepository {
  static const draftKey = 'workout_in_progress_v2_draft';
  static const sessionsKey = 'workout_in_progress_v2_sessions';
  static const legacySessionsKey = 'pro_workout_sessions';

  Future<List<ExerciseInSession>?> loadDraftExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final serialized = json['exercises'] as List<dynamic>? ?? [];
      return serialized
          .map((item) => ExerciseInSession.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> persistDraft(List<ExerciseInSession> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      draftKey,
      jsonEncode({
        'updatedAt': DateTime.now().toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);
  }

  Future<void> persistCompletedWorkout(List<ExerciseInSession> exercises) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(sessionsKey) ?? [];
    final session = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'date': DateTime.now().toIso8601String(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
    stored.insert(0, jsonEncode(session));
    await prefs.setStringList(sessionsKey, stored.take(50).toList());
    await clearDraft();
  }

  Future<List<PreviousSet>> getPreviousSetsForExercise(String exerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = [
      ...(prefs.getStringList(sessionsKey) ?? []),
      ...(prefs.getStringList(legacySessionsKey) ?? []),
    ];

    for (final raw in sessions) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final exercises = (json['exercises'] as List<dynamic>? ?? []);
        for (final exerciseRaw in exercises) {
          final exercise = Map<String, dynamic>.from(exerciseRaw as Map);
          final currentExerciseId = exercise['exerciseId'] as String? ?? exercise['id'] as String?;
          if (currentExerciseId != exerciseId) continue;

          final sets = (exercise['sets'] as List<dynamic>? ?? []);
          return sets.map((setRaw) {
            final set = Map<String, dynamic>.from(setRaw as Map);
            final kg = (set['kg'] as num?)?.toDouble() ?? (set['externalLoadKg'] as num?)?.toDouble();
            final reps = set['reps'] as int?;
            return PreviousSet(kg: kg, reps: reps);
          }).toList();
        }
      } catch (_) {
        continue;
      }
    }

    return [];
  }
}
