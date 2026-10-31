import 'dart:async';

import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart';
import '../data/workout_repository.dart';
import '../pro/models/workout_models.dart';

class HistoryProjectionPending implements Exception {
  const HistoryProjectionPending();
}

/// A saved correction/deletion is authoritative immediately. Its Home projection
/// is acknowledged only after writing; process death or disk failure leaves a
/// durable pending operation that startup recovery retries without new IDs.
class WorkoutHistoryMutationService {
  WorkoutHistoryMutationService(this.sessions, this.fitness);
  final WorkoutRepository sessions;
  final FitnessRepository fitness;
  static final _operations = <String, Future<void>>{};
  Future<void> _serialize(Future<void> Function() operation) async {
    final key = sessions.storageScope,
        previous = _operations[sessions.storageScope],
        gate = Completer<void>();
    _operations[key] = gate.future;
    try {
      if (previous != null) await previous;
      await operation();
    } finally {
      if (identical(_operations[key], gate.future)) _operations.remove(key);
      gate.complete();
    }
  }

  Future<void> correct(
    WorkoutSession session, {
    required int expectedRevision,
  }) => _serialize(() async {
    await sessions.stageHistoryCorrection(
      session,
      expectedRevision: expectedRevision,
    );
    try {
      await _recover();
    } catch (_) {
      throw const HistoryProjectionPending();
    }
  });
  Future<void> delete(String id, {required int expectedRevision}) =>
      _serialize(() async {
        await sessions.stageHistoryDeletion(
          id,
          expectedRevision: expectedRevision,
        );
        try {
          await _recover();
        } catch (_) {
          throw const HistoryProjectionPending();
        }
      });
  Future<void> recover() => _serialize(_recover);
  Future<void> _recover() async {
    final pending = (await sessions.historyChanges()).values
        .where((c) => c.projectionPending)
        .toList();
    if (pending.isEmpty) return;
    final existing = {
      for (final e in await fitness.getWorkoutProjections()) e.id: e,
    };
    for (final change in pending) {
      final session = change.session, prior = existing[change.session.id];
      final projection = WorkoutEntry(
        id: session.id,
        name:
            session.templateName ??
            session.activityName ??
            'Entrenamiento libre',
        durationMinutes:
            session.durationMinutes ?? ((session.durationSeconds ?? 0) ~/ 60),
        intensity: prior?.intensity ?? 'No registrada',
        notes: prior?.notes,
        template: session.templateId,
        meta: EntityMeta(
          createdAt: session.date.toUtc(),
          updatedAt: DateTime.now().toUtc(),
          deleted: change.deleted,
          revision: (prior?.meta.revision ?? 0) + 1,
        ),
      );
      await fitness.saveWorkout(projection);
      await sessions.acknowledgeHistoryProjection(session.id, change.revision);
    }
  }
}
