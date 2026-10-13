import 'package:uuid/uuid.dart';

import '../../../core/data/account_storage_scope.dart';
import '../data/workout_repository.dart';
import '../domain/session_models.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
import '../workout_in_progress_controller.dart';

import 'dart:convert';

/// Repetition creates a new draft with targets, never a completed copy.
class WorkoutRepeatService {
  WorkoutRepeatService() : _scope = AccountStorageScope.current;
  final String _scope;
  final WorkoutRepository _repository = WorkoutRepository();
  Future<bool> hasDraft() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    return prefs.getString(WorkoutRepository.draftKey) != null ||
        prefs.getString('pro_workout_draft') != null;
  }

  Future<String> repeat(
    WorkoutSession original, {
    bool replaceDraft = false,
  }) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final oldRich = prefs.getString(WorkoutRepository.draftKey);
    final oldPro = prefs.getString('pro_workout_draft');
    if ((oldRich != null || oldPro != null) && !replaceDraft) {
      throw StateError('Hay una sesión en curso.');
    }
    for (final raw in [oldRich, oldPro]) {
      if (raw == null) continue;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['completionPending'] == true ||
          json['pendingCompletedSessionId'] != null) {
        throw StateError('Primero recuperá el guardado de la sesión anterior.');
      }
    }
    final id = const Uuid().v4();
    final start = DateTime.now();
    if (original.type == WorkoutType.strength ||
        original.exercises.isNotEmpty) {
      final exercises = [
        for (final e in original.exercises)
          ExerciseInSession(
            id: const Uuid().v4(),
            exerciseId: e.id,
            plan: e.copyWith(sets: [], clearSportResult: true),
            name: e.name,
            notes: e.notes,
            restEnabled: e.restEnabled ?? e.restSeconds != null,
            restSeconds: e.restSeconds,
            isTimed: WorkoutAnalytics.isTimed(e),
            isAssisted: e.targetLoadType == RoutineExerciseLoadType.assistedKg,
            sets: [
              for (var i = 0; i < e.sets.length; i++)
                SetInSession(
                  id: const Uuid().v4(),
                  index: i + 1,
                  kg: e.sets[i].loadIsAmbiguous
                      ? null
                      : e.sets[i].externalLoadKg,
                  reps: e.sets[i].reps,
                  durationSeconds: e.sportPlan == null
                      ? e.sets[i].durationSeconds
                      : null,
                  assistanceKg: e.sets[i].assistanceKg,
                  done: false,
                ),
            ],
          ),
      ];
      await _repository.persistDraftWithStartTime(
        exercises,
        startTime: start,
        workoutId: id,
        routineId: original.templateId,
        routineName: original.templateName ?? original.activityName,
        sourceSessionId: original.id,
        workoutType: original.type,
        clearRest: true,
      );
      if (oldPro != null) await prefs.remove('pro_workout_draft');
    } else {
      await prefs.setString(
        'pro_workout_draft',
        jsonEncode({
          'workoutId': id,
          'sourceSessionId': original.id,
          'sessionStart': start.toIso8601String(),
          'lastUpdated': start.toIso8601String(),
          'type': original.type.name,
          'customTypeName': original.customTypeName,
          'activityName': original.activityName,
          'templateId': original.templateId,
          'notes': original.notes,
          'exercises': <Object>[],
        }),
      );
      if (oldRich != null) await prefs.remove(WorkoutRepository.draftKey);
    }
    if (_scope == AccountStorageScope.current) {
      await WorkoutInProgressController.instance.refresh();
    }
    return id;
  }
}
