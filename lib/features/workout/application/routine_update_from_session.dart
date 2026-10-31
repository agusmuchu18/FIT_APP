import '../domain/routine_plan_validation.dart';
import '../domain/session_models.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
import '../training_home/routines_repository.dart';

/// A routine rewritten with the values the user actually completed today.
///
/// Only exercises with completed sets change. Planned exercises that were not
/// performed (or were removed from the session) keep their original plan, so
/// accepting the proposal never deletes anything from the routine.
class RoutineUpdateProposal {
  const RoutineUpdateProposal({required this.routine, required this.exercises});

  final WorkoutTemplate routine;
  final List<WorkoutExercise> exercises;

  Future<WorkoutTemplate> apply({RoutinesRepository? repository}) =>
      (repository ?? RoutinesRepository()).saveRoutine(
        name: routine.name,
        workoutType: routine.type,
        exercises: exercises,
        activityName: routine.activityName,
        folderId: routine.folderId,
        routineId: routine.id,
        notes: routine.notes,
        footballMode: routine.footballMode,
      );
}

class RoutineUpdateFromSession {
  const RoutineUpdateFromSession._();

  /// Returns the updated exercise list, or `null` when today's completed
  /// values are equivalent to the plan (nothing worth proposing) or the
  /// result would not pass the routine validation.
  static List<WorkoutExercise>? build(
    WorkoutTemplate routine,
    List<ExerciseInSession> session,
  ) {
    final updated = [...routine.exercises];
    final used = <int>{};
    var changed = false;
    for (final live in session) {
      if (live.sportPlan != null || live.isDistance) continue;
      final done = live.sets
          .where(
            (s) =>
                s.done &&
                !s.loadIsAmbiguous &&
                s.kind != SetKind.warmup &&
                s.hasValidResult(
                  isTimed: live.isTimed,
                  isDistance: live.isDistance,
                ),
          )
          .toList();
      if (done.isEmpty) continue;
      final plan = live.plan;
      final index = plan == null ? -1 : _indexOf(updated, plan, used);
      if (index >= 0) used.add(index);
      final base = index >= 0
          ? updated[index]
          : plan ??
                WorkoutAnalytics.fromLive([live]).single
                    .copyWith(sets: const [], setTargets: const []);
      final next = _apply(base, live, done, fixedReps: plan == null).copyWith(
        supersetId: live.supersetId,
        clearSuperset: live.supersetId == null,
      );
      if (index >= 0) {
        if (!_equivalent(updated[index], next)) {
          updated[index] = next;
          changed = true;
        }
      } else {
        updated.add(next);
        changed = true;
      }
    }
    if (!changed) return null;
    for (final exercise in updated) {
      if (RoutinePlanValidation.error(exercise) != null) return null;
    }
    return updated;
  }

  static int _indexOf(
    List<WorkoutExercise> routine,
    WorkoutExercise plan,
    Set<int> used,
  ) {
    if (plan.instanceId != null) {
      for (var i = 0; i < routine.length; i++) {
        if (!used.contains(i) && routine[i].instanceId == plan.instanceId) {
          return i;
        }
      }
      // A session duplicate gets a new instance id: it is a new exercise.
      if (routine.any((e) => e.instanceId != null)) return -1;
    }
    for (var i = 0; i < routine.length; i++) {
      if (!used.contains(i) && routine[i].id == plan.id) return i;
    }
    return -1;
  }

  static WorkoutExercise _apply(
    WorkoutExercise base,
    ExerciseInSession live,
    List<SetInSession> done, {
    required bool fixedReps,
  }) {
    final timed = base.isTimed || live.isTimed;
    final old = base.setTargets;
    final planUsesFixedReps = old.isNotEmpty
        ? old.every((t) => t.reps != null)
        : base.targetReps != null;
    final targets = <RoutineSetTarget>[];
    for (var i = 0; i < done.length; i++) {
      final set = done[i];
      final previous = i < old.length ? old[i] : null;
      final min = previous?.repsMin ?? base.targetRepsMin;
      final max = previous?.repsMax ?? base.targetRepsMax;
      final keepRange =
          !timed &&
          !fixedReps &&
          !planUsesFixedReps &&
          min != null &&
          max != null &&
          min > 0 &&
          max >= min;
      targets.add(
        RoutineSetTarget(
          reps: timed || keepRange ? null : set.reps,
          repsMin: keepRange ? min : null,
          repsMax: keepRange ? max : null,
          loadType: live.modeFor(set),
          weightKg: set.kg,
          assistanceKg: set.assistanceKg,
          durationSeconds: timed ? set.durationSeconds : null,
        ),
      );
    }
    final firstLoad = targets.first.weightKg;
    final firstReps = targets.first.reps;
    return base.copyWith(
      targetSets: done.length,
      setTargets: targets,
      targetLoadType: live.defaultMode,
      loadSchemaVersion: 1,
      targetWeightKg: firstLoad ?? base.targetWeightKg,
      targetAssistanceKg: targets.first.assistanceKg ?? base.targetAssistanceKg,
      targetReps: firstReps,
      targetDurationSeconds: timed ? done.first.durationSeconds : null,
      sets: const [],
    );
  }

  /// Compares what a future session would actually prefill, not raw JSON:
  /// a plan with generic targets and one with equal per-set targets match.
  static bool _equivalent(WorkoutExercise a, WorkoutExercise b) {
    if (a.targetSets != b.targetSets) return false;
    if ((a.supersetId == null) != (b.supersetId == null)) return false;
    for (var i = 0; i < a.targetSets; i++) {
      if (_effective(a, i) != _effective(b, i)) return false;
    }
    return true;
  }

  static (RoutineExerciseLoadType, num?, num?, num?) _effective(
    WorkoutExercise e,
    int index,
  ) {
    final target = index < e.setTargets.length ? e.setTargets[index] : null;
    final timed = e.isTimed;
    final mode = target?.loadType ?? e.targetLoadType;
    final load = mode == RoutineExerciseLoadType.bodyweight
        ? null
        : target?.loadFor(e.targetLoadType) ?? e.plannedLoad;
    return (
      mode,
      load,
      timed
          ? null
          : target?.reps ?? target?.repsMin ?? e.targetReps ?? e.targetRepsMin,
      timed ? target?.durationSeconds ?? e.targetDurationSeconds : null,
    );
  }
}
