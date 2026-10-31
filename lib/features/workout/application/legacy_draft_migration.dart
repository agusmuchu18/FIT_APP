import 'dart:convert';

import '../../../core/data/account_storage_scope.dart';
import '../data/workout_repository.dart';
import '../domain/session_models.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';

/// Moves a draft written by the old "Pro" screen into the current session
/// format, so it opens in the live session screen instead of the old one.
///
/// Only drafts the live screen can represent move: those with exercises (or
/// strength sessions). Activity logs without exercises — a run recorded by
/// duration and distance — stay where they are, as does any draft that is
/// unreadable or halfway through being saved, so no data is ever lost.
class LegacyDraftMigration {
  const LegacyDraftMigration._();

  static const legacyDraftKey = 'pro_workout_draft';

  /// Returns true when the old draft was moved (or was already saved and
  /// could simply be dropped).
  static Future<bool> run(ScopedPreferences prefs) async {
    final raw = prefs.getString(legacyDraftKey);
    if (raw == null) return false;
    // Never overwrite a session already open in the current format.
    if (prefs.getString(WorkoutRepository.draftKey) != null) return false;
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    final pendingId = json['pendingCompletedSessionId'] as String?;
    if (pendingId != null) {
      // The history can only be checked for the account that is signed in.
      if (prefs.scope != AccountStorageScope.current) return false;
      final saved = await WorkoutRepository().listAllSessions().catchError(
        (Object _) => <WorkoutSession>[],
      );
      if (saved.any((session) => session.id == pendingId)) {
        await _archive(prefs, raw);
        await prefs.remove(legacyDraftKey);
        return true;
      }
      // The old screen knows how to finish this save; leave it there.
      return false;
    }

    final type = WorkoutType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => WorkoutType.strength,
    );
    final List<WorkoutExercise> exercises;
    try {
      exercises = [
        for (final item in json['exercises'] as List<dynamic>? ?? const [])
          WorkoutExercise.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } catch (_) {
      return false;
    }
    if (exercises.isEmpty && type != WorkoutType.strength) return false;

    final start =
        DateTime.tryParse(json['sessionStart'] as String? ?? '') ??
        DateTime.now();
    final now = DateTime.now().toIso8601String();
    final migrated = {
      'updatedAt': now,
      'lastUpdated': now,
      'sessionStart': start.toIso8601String(),
      'workoutId': json['workoutId'],
      'routineId': json['templateId'],
      'routineName': json['templateName'] ?? json['activityName'],
      'sourceSessionId': json['sourceSessionId'],
      'workoutType': type.name,
      'isPaused': json['isPaused'] ?? false,
      'pausedAt': json['pausedAt'],
      'accumulatedPausedSeconds': json['accumulatedPausedSeconds'] ?? 0,
      'exercises': [for (final e in exercises) _toLive(e).toJson()],
    };
    await _archive(prefs, raw);
    await prefs.setString(WorkoutRepository.draftKey, jsonEncode(migrated));
    await prefs.remove(legacyDraftKey);
    return true;
  }

  static Future<void> _archive(ScopedPreferences prefs, String raw) async {
    const key = 'workout_legacy_draft_sources_v1';
    final originals = prefs.getStringList(key) ?? <String>[];
    if (!originals.contains(raw)) {
      await prefs.setStringList(key, [...originals, raw]);
    }
  }

  static ExerciseInSession _toLive(WorkoutExercise exercise) {
    final id = exercise.instanceId ?? exercise.id;
    return ExerciseInSession(
      id: id,
      exerciseId: exercise.id,
      plan: exercise.copyWith(sets: []),
      name: exercise.name,
      notes: exercise.notes,
      restEnabled: exercise.restEnabled ?? exercise.restSeconds != null,
      restSeconds: exercise.restSeconds,
      isTimed: WorkoutAnalytics.isTimed(exercise),
      isBodyweight: WorkoutAnalytics.isBodyweight(exercise),
      isDistance: exercise.measurement == 'distance',
      isAssisted: exercise.targetLoadType == RoutineExerciseLoadType.assistedKg,
      sportResult: exercise.sportResult,
      supersetId: exercise.supersetId,
      sets: [
        for (var i = 0; i < exercise.sets.length; i++)
          SetInSession(
            id: exercise.sets[i].id,
            index: i + 1,
            // An ambiguous old load is not shown as if it were known.
            kg: exercise.sets[i].externalLoadKg,
            bodyweightKg: exercise.sets[i].bodyweightKg,
            bodyweightFactor: exercise.sets[i].bodyweightFactor,
            loadType: WorkoutAnalytics.setLoadType(exercise, exercise.sets[i]),
            loadIsAmbiguous:
                WorkoutAnalytics.setLoadType(exercise, exercise.sets[i]) ==
                null,
            reps: exercise.sets[i].reps,
            durationSeconds: exercise.sets[i].durationSeconds,
            assistanceKg: exercise.sets[i].assistanceKg,
            distanceMeters: exercise.sets[i].distanceMeters,
            loadConvention: exercise.sets[i].loadConvention,
            implementCount: exercise.sets[i].implementCount,
            rir: exercise.sets[i].rir,
            note: exercise.sets[i].note,
            performedAt: exercise.sets[i].performedAt,
            kind: exercise.sets[i].kind,
            done: exercise.sets[i].done ?? false,
          ),
      ],
    );
  }
}
