import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart';
import '../data/workout_repository.dart';

/// The rich session is authoritative. Repair its Home projection idempotently.
Future<void> recoverCompletedWorkouts(
  WorkoutRepository sessions,
  FitnessRepository fitness,
) async {
  final completed = await sessions.listAllSessions();
  final projectedIds = (await fitness.getWorkouts())
      .map((entry) => entry.id)
      .toSet();
  for (final session in completed) {
    if (projectedIds.contains(session.id)) continue;
    await fitness.saveWorkout(
      WorkoutEntry(
        id: session.id,
        name: session.templateName ?? 'Entrenamiento libre',
        durationMinutes: session.durationMinutes ?? 0,
        intensity: 'No registrada',
        template: session.templateId,
        meta: EntityMeta(
          createdAt: session.date.toUtc(),
          updatedAt: session.date.toUtc(),
          deleted: false,
          revision: 1,
        ),
      ),
    );
  }
  final pending = await sessions.pendingCompletionId();
  if (pending != null && completed.any((session) => session.id == pending)) {
    await sessions.clearDraft();
  }
  final legacyPending = await sessions.pendingLegacyCompletionId();
  if (legacyPending != null && completed.any((s) => s.id == legacyPending)) {
    await sessions.clearCompletedLegacyDraft(legacyPending);
  }
}
