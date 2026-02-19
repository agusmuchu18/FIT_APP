import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_models.dart';
import '../pro/models/workout_models.dart';

class WorkoutRepository {
  static const draftKey = 'workout_in_progress_v2_draft';
  static const sessionsKey = 'workout_in_progress_v2_sessions';
  static const legacySessionsKey = 'pro_workout_sessions';

  Future<DateTime?> loadDraftStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.tryParse(json['sessionStart'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<List<ExerciseInSession>?> loadDraftExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final serialized = json['exercises'] as List<dynamic>? ?? [];
      return serialized.map((item) => ExerciseInSession.fromJson(Map<String, dynamic>.from(item as Map))).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> persistDraft(List<ExerciseInSession> exercises) async {
    final startTime = await loadDraftStartTime() ?? DateTime.now();
    await persistDraftWithStartTime(exercises, startTime: startTime);
  }

  Future<void> persistDraftWithStartTime(
    List<ExerciseInSession> exercises, {
    required DateTime startTime,
    String? workoutId,
    String? routineName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      draftKey,
      jsonEncode({
        'updatedAt': DateTime.now().toIso8601String(),
        'sessionStart': startTime.toIso8601String(),
        'workoutId': workoutId,
        'routineName': routineName,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(draftKey);
  }

  Future<void> persistCompletedWorkout(
    List<ExerciseInSession> exercises, {
    String? routineId,
    String? routineName,
    Duration? duration,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(sessionsKey) ?? [];
    final now = DateTime.now();
    final totalDoneSets = exercises.fold<int>(0, (sum, e) => sum + e.sets.where((set) => set.done).length);
    final volumeKg = exercises.fold<double>(0, (sum, e) {
      return sum + e.sets.where((set) => set.done).fold<double>(0, (acc, set) => acc + ((set.kg ?? 0) * (set.reps ?? 0)));
    });

    final session = {
      'id': now.microsecondsSinceEpoch.toString(),
      'date': now.toIso8601String(),
      'routineId': routineId,
      'routineName': routineName,
      'durationMinutes': duration?.inMinutes,
      'totalDoneSets': totalDoneSets,
      'totalVolumeKg': volumeKg,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
    stored.insert(0, jsonEncode(session));
    await prefs.setStringList(sessionsKey, stored.take(100).toList());
    await clearDraft();
  }


  Future<List<ExerciseInSession>?> loadLatestCompletedSessionExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(sessionsKey) ?? [];
    if (values.isEmpty) return null;

    for (final raw in values) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final serialized = json['exercises'] as List<dynamic>? ?? [];
        return serialized
            .map((item) => ExerciseInSession.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<List<WorkoutSession>> listSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(sessionsKey) ?? [];
    final parsed = <WorkoutSession>[];
    for (final raw in values) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final exercises = (json['exercises'] as List<dynamic>? ?? [])
            .map((rawExercise) => ExerciseInSession.fromJson(Map<String, dynamic>.from(rawExercise as Map)))
            .map(
              (e) => WorkoutExercise(
                id: e.exerciseId,
                name: e.name,
                notes: e.notes,
                targetSets: e.sets.length,
                sets: e.sets
                    .map(
                      (s) => SetEntry(
                        id: s.id,
                        reps: s.reps,
                        externalLoadKg: s.kg,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();

        parsed.add(
          WorkoutSession(
            id: json['id'] as String,
            type: WorkoutType.strength,
            date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
            templateId: json['routineId'] as String?,
            templateName: json['routineName'] as String?,
            durationMinutes: json['durationMinutes'] as int?,
            exercises: exercises,
            notes: 'Sets: ${json['totalDoneSets'] ?? 0} · Volumen: ${((json['totalVolumeKg'] as num?)?.toStringAsFixed(0) ?? '0')} kg',
          ),
        );
      } catch (_) {
        continue;
      }
    }
    parsed.sort((a, b) => a.date.compareTo(b.date));
    return parsed;
  }

  Future<List<PreviousSet>> getPreviousSetsForExercise(String exerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = [...(prefs.getStringList(sessionsKey) ?? []), ...(prefs.getStringList(legacySessionsKey) ?? [])];

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
