part of 'workout_repository.dart';

class WorkoutHistoryChange {
  const WorkoutHistoryChange({
    required this.session,
    required this.revision,
    required this.deleted,
    required this.projectionPending,
  });
  final WorkoutSession session;
  final int revision;
  final bool deleted, projectionPending;
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'session': session.toJson(),
    'revision': revision,
    'deleted': deleted,
    'projectionPending': projectionPending,
  };
  factory WorkoutHistoryChange.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['revision'] is! int ||
        json['deleted'] is! bool ||
        json['projectionPending'] is! bool) {
      throw const FormatException(
        'Cambio histórico ilegible; se conserva el original.',
      );
    }
    return WorkoutHistoryChange(
      session: WorkoutSession.fromJson(
        Map<String, dynamic>.from(json['session'] as Map),
      ),
      revision: json['revision'] as int,
      deleted: json['deleted'] as bool,
      projectionPending: json['projectionPending'] as bool,
    );
  }
}

/// An additive overlay over original rows, retained even after projection repair.
/// Tombstones prevent a deleted rich/legacy duplicate from reappearing. The
/// pending flag is a durable local reconciliation journal, not another history.
extension WorkoutHistoryChanges on WorkoutRepository {
  static const storageKey = 'workout_history_changes_v1';
  static final _writes = <String, Future<void>>{};
  Future<T> _serializeChange<T>(Future<T> Function() operation) async {
    final previous = _writes[_scope], gate = Completer<void>();
    _writes[_scope] = gate.future;
    try {
      if (previous != null) await previous;
      return await operation();
    } finally {
      if (identical(_writes[_scope], gate.future)) _writes.remove(_scope);
      gate.complete();
    }
  }

  Future<Map<String, WorkoutHistoryChange>> historyChanges() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope),
        box = _sessionsBox;
    var raw = box?.get(storageKey);
    raw ??= prefs.getString(storageKey);
    if (raw == null) return {};
    final envelope = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (envelope['schemaVersion'] != 1) {
      throw const FormatException(
        'Versión de cambios históricos no soportada.',
      );
    }
    final rows = Map<String, dynamic>.from(envelope['changes'] as Map);
    final result = <String, WorkoutHistoryChange>{};
    for (final entry in rows.entries) {
      final change = WorkoutHistoryChange.fromJson(
        Map<String, dynamic>.from(entry.value as Map),
      );
      if (change.session.id != entry.key || change.revision < 1) {
        throw const FormatException('Identidad histórica inconsistente.');
      }
      result[entry.key] = change;
    }
    // Preserve the preference copy while upgrading to the already-open rich box.
    if (box != null && !box.containsKey(storageKey)) {
      await box.put(storageKey, raw);
    }
    return result;
  }

  Future<void> _writeChanges(Map<String, WorkoutHistoryChange> rows) async {
    final raw = jsonEncode({
      'schemaVersion': 1,
      'changes': {for (final e in rows.entries) e.key: e.value.toJson()},
    });
    final box = _sessionsBox;
    if (box != null) {
      await box.put(storageKey, raw);
    } else {
      await (await ScopedPreferences.getInstance(scope: _scope))
          .setString(storageKey, raw);
    }
  }

  Future<List<WorkoutSession>> applyHistoryChanges(
    List<WorkoutSession> source,
  ) async {
    final rows = await historyChanges();
    final byId = {for (final s in source) s.id: s};
    for (final entry in rows.entries) {
      if (entry.value.deleted) {
        byId.remove(entry.key);
      } else {
        byId[entry.key] = entry.value.session;
      }
    }
    return byId.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<int> historyChangeRevision(String id) async =>
      (await historyChanges())[id]?.revision ?? 0;
  Future<(WorkoutSession?, int)> editableSessionSnapshot(String id) =>
      _serializeChange(() async {
        final rows = await historyChanges();
        return (await findSession(id), rows[id]?.revision ?? 0);
      });
  Future<WorkoutHistoryChange> stageHistoryCorrection(
    WorkoutSession updated, {
    required int expectedRevision,
  }) => _serializeChange(() async {
    final rows = await historyChanges(), previous = rows[updated.id];
    if ((previous?.revision ?? 0) != expectedRevision) {
      throw StateError(
        'La sesión cambió mientras la editabas. Volvé a abrirla.',
      );
    }
    final original = await findSession(updated.id);
    if (original == null) throw StateError('La sesión ya no está disponible.');
    if (original.programExecution?.occurrenceKey !=
        updated.programExecution?.occurrenceKey) {
      throw ArgumentError('No se cambia el vínculo histórico del programa.');
    }
    if (updated.exercises.every(
      (e) => !e.sets.any((s) => WorkoutAnalytics.isRecordedSet(e, s)),
    )) {
      throw ArgumentError('Conservá un resultado válido o eliminá la sesión.');
    }
    for (final e in updated.exercises) {
      if (e.sportPlan != null && !e.sportPlan!.resultValid(e.sportResult)) {
        throw ArgumentError('Revisá los resultados deportivos de ${e.name}.');
      }
      for (final s in e.sets.where((s) => s.done == true)) {
        if (!WorkoutAnalytics.isRecordedSet(e, s)) {
          throw ArgumentError('Revisá los resultados de ${e.name}.');
        }
      }
    }
    final change = WorkoutHistoryChange(
      session: updated,
      revision: expectedRevision + 1,
      deleted: false,
      projectionPending: true,
    );
    rows[updated.id] = change;
    await _writeChanges(rows);
    invalidateHistory();
    return change;
  });
  Future<WorkoutHistoryChange> stageHistoryDeletion(
    String id, {
    required int expectedRevision,
  }) => _serializeChange(() async {
    final rows = await historyChanges(), previous = rows[id];
    if ((previous?.revision ?? 0) != expectedRevision) {
      throw StateError('La sesión cambió. Volvé a abrirla.');
    }
    if (previous?.deleted == true) return previous!;
    final original = await findSession(id);
    if (original == null) throw StateError('La sesión ya no está disponible.');
    final change = WorkoutHistoryChange(
      session: original,
      revision: expectedRevision + 1,
      deleted: true,
      projectionPending: true,
    );
    rows[id] = change;
    await _writeChanges(rows);
    invalidateHistory();
    return change;
  });
  Future<void> acknowledgeHistoryProjection(String id, int revision) =>
      _serializeChange(() async {
        final rows = await historyChanges(), current = rows[id];
        if (current == null ||
            current.revision != revision ||
            !current.projectionPending) {
          return;
        }
        rows[id] = WorkoutHistoryChange(
          session: current.session,
          revision: current.revision,
          deleted: current.deleted,
          projectionPending: false,
        );
        await _writeChanges(rows);
      });
}
