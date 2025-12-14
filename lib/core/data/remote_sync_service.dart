import 'dart:async';

import '../domain/entities.dart';

/// RemoteSyncService (versión pro)
/// - Offline-first (cola)
/// - Reintentos con backoff
/// - Idempotencia (evita duplicados)
/// - Resultado tipado (success/queued/failure/conflict)
/// - Observabilidad (Stream de eventos)
///
/// Diseñado para enchufar Firebase o REST sin acoplarte a una librería.
/// Este archivo también incluye implementaciones DEV (Noop/AlwaysOnline/StaticSession)
/// para que compile y funcione sin backend real.

/// ------------------------------
/// Tipos base de Sync
/// ------------------------------

enum SyncEntityKind {
  workout,
  meal,
  sleep,
  preferences,
}

enum SyncWriteMode {
  /// Escritura normal: el backend puede rechazar por conflicto.
  normal,

  /// Escritura forzada: se usa sólo si decidís que "gana local" (si el backend lo soporta).
  force,
}

class SyncCursor {
  const SyncCursor(this.value);
  final String value;

  static const zero = SyncCursor('0');

  @override
  String toString() => value;
}

/// ------------------------------
/// Eventos para UI/Logs/Debug.
/// ------------------------------

sealed class SyncEvent {
  const SyncEvent();
}

class SyncEnqueued extends SyncEvent {
  const SyncEnqueued({
    required this.kind,
    required this.entityId,
    required this.reason,
  });

  final SyncEntityKind kind;
  final String entityId;
  final String reason; // ej: "offline", "retry", "manual"

  @override
  String toString() => 'SyncEnqueued($kind:$entityId, reason=$reason)';
}

class SyncFlushStarted extends SyncEvent {
  const SyncFlushStarted({required this.pendingCount});
  final int pendingCount;

  @override
  String toString() => 'SyncFlushStarted(pending=$pendingCount)';
}

class SyncFlushProgress extends SyncEvent {
  const SyncFlushProgress({
    required this.done,
    required this.total,
    required this.kind,
    required this.entityId,
  });

  final int done;
  final int total;
  final SyncEntityKind kind;
  final String entityId;

  @override
  String toString() => 'SyncFlushProgress($done/$total, $kind:$entityId)';
}

class SyncFlushCompleted extends SyncEvent {
  const SyncFlushCompleted({
    required this.syncedCount,
    required this.failedCount,
  });

  final int syncedCount;
  final int failedCount;

  @override
  String toString() =>
      'SyncFlushCompleted(synced=$syncedCount, failed=$failedCount)';
}

class SyncConflictEvent extends SyncEvent {
  const SyncConflictEvent({
    required this.kind,
    required this.entityId,
  });

  final SyncEntityKind kind;
  final String entityId;

  @override
  String toString() => 'SyncConflictEvent($kind:$entityId)';
}

class SyncPullStarted extends SyncEvent {
  const SyncPullStarted({required this.since});
  final SyncCursor since;

  @override
  String toString() => 'SyncPullStarted(since=$since)';
}

class SyncPullCompleted extends SyncEvent {
  const SyncPullCompleted({required this.nextCursor});
  final SyncCursor nextCursor;

  @override
  String toString() => 'SyncPullCompleted(next=$nextCursor)';
}

/// ------------------------------
/// Resultado de una operación de sync (para el caller).
/// ------------------------------

sealed class SyncOutcome {
  const SyncOutcome();
}

class SyncSuccess extends SyncOutcome {
  const SyncSuccess();
}

class SyncQueued extends SyncOutcome {
  const SyncQueued({required this.reason});
  final String reason; // ej: "offline", "rate_limited"
}

class SyncFailure extends SyncOutcome {
  const SyncFailure({
    required this.error,
    this.isRetryable = true,
  });

  final Object error;
  final bool isRetryable;
}

/// Conflicto (ej: edición en dos dispositivos).
class SyncConflict extends SyncOutcome {
  const SyncConflict({
    required this.kind,
    required this.entityId,
    required this.local,
    required this.remotePayload,
    required this.remoteUpdatedAt,
  });

  final SyncEntityKind kind;
  final String entityId;

  /// Entidad local original (útil para merge).
  final Object local;

  /// Snapshot remoto (en JSON) que devolvió el backend.
  final Map<String, Object?> remotePayload;

  final DateTime remoteUpdatedAt;
}

/// Qué hacer frente a un conflicto.
enum SyncConflictResolutionDecision {
  /// El caller decide mergear y reintentar.
  manual,

  /// Aceptar remoto: el caller debería aplicar remotePayload al storage local.
  acceptRemote,

  /// Forzar local: reintentar escritura en modo force (si el backend lo permite).
  keepLocalForceWrite,
}

class SyncConflictResolution {
  const SyncConflictResolution(this.decision);

  final SyncConflictResolutionDecision decision;

  static const manual =
      SyncConflictResolution(SyncConflictResolutionDecision.manual);
  static const acceptRemote =
      SyncConflictResolution(SyncConflictResolutionDecision.acceptRemote);
  static const keepLocalForceWrite = SyncConflictResolution(
    SyncConflictResolutionDecision.keepLocalForceWrite,
  );
}

/// Config de política: reintentos y backoff.
class SyncPolicy {
  const SyncPolicy({
    this.maxAttempts = 8,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 2),
    this.flushOnEnqueueIfOnline = true,

    /// Evita que flush() se quede “trabado” por un ítem con backoff grande.
    /// Si un task falla transitoriamente, cortamos el loop y dejamos para próximo flush.
    this.stopBatchOnTransientFailure = true,
  });

  final int maxAttempts;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final bool flushOnEnqueueIfOnline;
  final bool stopBatchOnTransientFailure;
}

/// Sesión/auth: mínimo para scopear datos por usuario.
abstract interface class SyncSession {
  String get userId;
}

/// Info de conectividad.
abstract interface class NetworkStatus {
  Future<bool> get isOnline;
}

/// Transporte remoto (Firebase/REST/WebSocket...).
abstract interface class RemoteSyncTransport {
  /// Escribe (upsert o delete) una entidad en remoto.
  Future<TransportWriteOutcome> write(TransportWriteRequest request);

  /// Baja cambios desde un cursor.
  Future<TransportPullResponse> pull(TransportPullRequest request);
}

class TransportWriteRequest {
  TransportWriteRequest({
    required this.userId,
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.deleted,
    required this.idempotencyKey,
    this.mode = SyncWriteMode.normal,
  });

  final String userId;
  final SyncEntityKind kind;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
  final bool deleted;
  final String idempotencyKey;
  final SyncWriteMode mode;
}

sealed class TransportWriteOutcome {
  const TransportWriteOutcome();
}

class TransportWriteSuccess extends TransportWriteOutcome {
  const TransportWriteSuccess();
}

class TransportWriteTransientFailure extends TransportWriteOutcome {
  const TransportWriteTransientFailure(this.error);
  final Object error;
}

class TransportWritePermanentFailure extends TransportWriteOutcome {
  const TransportWritePermanentFailure(this.error);
  final Object error;
}

/// Conflicto: el backend devuelve snapshot remoto.
class TransportWriteConflict extends TransportWriteOutcome {
  const TransportWriteConflict({
    required this.remotePayload,
    required this.remoteUpdatedAt,
  });

  final Map<String, Object?> remotePayload;
  final DateTime remoteUpdatedAt;
}

class TransportPullRequest {
  TransportPullRequest({
    required this.userId,
    required this.since,
  });

  final String userId;
  final SyncCursor since;
}

class TransportPullResponse {
  TransportPullResponse({
    required this.nextCursor,
    required this.items,
  });

  final SyncCursor nextCursor;

  /// Items genéricos: cada item trae kind + payload.
  final List<TransportPullItem> items;
}

class TransportPullItem {
  TransportPullItem({
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.deleted,
  });

  final SyncEntityKind kind;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
  final bool deleted;
}

/// Adaptador para convertir tus entities a JSON + metadata.
/// (Lo mantenemos inyectable para poder migrar entidades sin romper.)
class SyncAdapter<T> {
  const SyncAdapter({
    required this.kind,
    required this.idOf,
    required this.updatedAtOf,
    required this.deletedOf,
    required this.toJson,
  });

  final SyncEntityKind kind;
  final String Function(T entity) idOf;
  final DateTime Function(T entity) updatedAtOf;
  final bool Function(T entity) deletedOf;
  final Map<String, Object?> Function(T entity) toJson;
}

/// ------------------------------
/// Cola de sync (persistible)
/// ------------------------------

class SyncTask {
  SyncTask({
    required this.kind,
    required this.entityId,
    required this.payload,
    required this.updatedAt,
    required this.deleted,
    required this.idempotencyKey,
    this.attempts = 0,
    DateTime? createdAt,
  }) : createdAt = (createdAt ?? DateTime.now().toUtc());

  final SyncEntityKind kind;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
  final bool deleted;
  final String idempotencyKey;

  final DateTime createdAt;

  /// Cantidad de intentos ya realizados (incrementa cuando hay fallo transitorio).
  int attempts;

  SyncTask copyWith({
    int? attempts,
    DateTime? updatedAt,
    bool? deleted,
    Map<String, Object?>? payload,
  }) {
    return SyncTask(
      kind: kind,
      entityId: entityId,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      idempotencyKey: idempotencyKey,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt,
    );
  }
}

abstract interface class SyncQueueStore {
  Future<void> enqueue(SyncTask task);

  /// Devuelve tasks en orden (FIFO).
  Future<List<SyncTask>> peek({int limit = 50});

  Future<void> remove(SyncTask task);

  Future<void> update(SyncTask task);

  Future<int> count();
}

/// Default: memoria (para dev/tests). En producción: implementá Hive/Sqflite/Isar.
class MemorySyncQueueStore implements SyncQueueStore {
  final List<SyncTask> _q = <SyncTask>[];

  @override
  Future<void> enqueue(SyncTask task) async {
    // Dedupe por kind+entityId: mantenemos la versión más reciente (updatedAt mayor).
    final idx = _q.indexWhere((t) => t.kind == task.kind && t.entityId == task.entityId);
    if (idx >= 0) {
      final existing = _q[idx];
      if (task.updatedAt.isAfter(existing.updatedAt)) {
        _q[idx] = task;
      } else {
        // Si por alguna razón llegó “más viejo”, ignoramos.
      }
    } else {
      _q.add(task);
    }
  }

  @override
  Future<List<SyncTask>> peek({int limit = 50}) async {
    if (_q.isEmpty) return const [];
    // FIFO por createdAt (más estable que el orden de lista si hicimos reemplazos).
    final sorted = List<SyncTask>.from(_q)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List<SyncTask>.unmodifiable(sorted.take(limit));
  }

  @override
  Future<void> remove(SyncTask task) async {
    _q.removeWhere((t) =>
        t.kind == task.kind &&
        t.entityId == task.entityId &&
        t.idempotencyKey == task.idempotencyKey);
  }

  @override
  Future<void> update(SyncTask task) async {
    final idx = _q.indexWhere((t) =>
        t.kind == task.kind &&
        t.entityId == task.entityId &&
        t.idempotencyKey == task.idempotencyKey);
    if (idx >= 0) _q[idx] = task;
  }

  @override
  Future<int> count() async => _q.length;
}

/// ------------------------------
/// Resultado de Pull (para repo/local store)
/// ------------------------------

class PullResult {
  PullResult({
    required this.nextCursor,
    required this.items,
  });

  final SyncCursor nextCursor;
  final List<TransportPullItem> items;
}

/// ------------------------------
/// Servicio principal
/// ------------------------------

class RemoteSyncService {
  RemoteSyncService({
    required RemoteSyncTransport transport,
    required SyncSession session,
    required NetworkStatus network,
    required SyncQueueStore queue,
    required SyncPolicy policy,
    required SyncAdapter<WorkoutEntry> workoutAdapter,
    required SyncAdapter<MealEntry> mealAdapter,
    required SyncAdapter<SleepEntry> sleepAdapter,
    required SyncAdapter<UserPreferences> preferencesAdapter,
    Future<SyncConflictResolution> Function(SyncConflict conflict)? onConflict,
  })  : _transport = transport,
        _session = session,
        _network = network,
        _queue = queue,
        _policy = policy,
        _workoutAdapter = workoutAdapter,
        _mealAdapter = mealAdapter,
        _sleepAdapter = sleepAdapter,
        _preferencesAdapter = preferencesAdapter,
        _onConflict = onConflict,
        _events = StreamController<SyncEvent>.broadcast();

  final RemoteSyncTransport _transport;
  final SyncSession _session;
  final NetworkStatus _network;
  final SyncQueueStore _queue;
  final SyncPolicy _policy;

  final SyncAdapter<WorkoutEntry> _workoutAdapter;
  final SyncAdapter<MealEntry> _mealAdapter;
  final SyncAdapter<SleepEntry> _sleepAdapter;
  final SyncAdapter<UserPreferences> _preferencesAdapter;

  final Future<SyncConflictResolution> Function(SyncConflict conflict)? _onConflict;

  final StreamController<SyncEvent> _events;
  Stream<SyncEvent> get events => _events.stream;

  bool _flushing = false;

  void dispose() {
    _events.close();
  }

  /// Wrappers con tu API vieja (por compatibilidad):
  Future<SyncOutcome> syncWorkout(WorkoutEntry entry) => upsertWorkout(entry);
  Future<SyncOutcome> syncMeal(MealEntry entry) => upsertMeal(entry);
  Future<SyncOutcome> syncSleep(SleepEntry entry) => upsertSleep(entry);
  Future<SyncOutcome> syncPreferences(UserPreferences preferences) =>
      upsertPreferences(preferences);

  /// API recomendada (upsert = create/update; delete se infiere por adapter.deletedOf)
  Future<SyncOutcome> upsertWorkout(WorkoutEntry entry) async =>
      _enqueueAndMaybeFlush(_workoutAdapter, entry);

  Future<SyncOutcome> upsertMeal(MealEntry entry) async =>
      _enqueueAndMaybeFlush(_mealAdapter, entry);

  Future<SyncOutcome> upsertSleep(SleepEntry entry) async =>
      _enqueueAndMaybeFlush(_sleepAdapter, entry);

  Future<SyncOutcome> upsertPreferences(UserPreferences prefs) async =>
      _enqueueAndMaybeFlush(_preferencesAdapter, prefs);

  /// Pull incremental: baja cambios desde cursor. El repo aplica merge al storage local.
  Future<PullResult> pullChanges({required SyncCursor since}) async {
    _events.add(SyncPullStarted(since: since));

    final res = await _transport.pull(
      TransportPullRequest(userId: _session.userId, since: since),
    );

    _events.add(SyncPullCompleted(nextCursor: res.nextCursor));

    return PullResult(nextCursor: res.nextCursor, items: res.items);
  }

  /// Intenta vaciar la cola. Ideal: llamarlo al abrir la app, al volver a foreground,
  /// al recuperar conectividad, o cada X minutos.
  Future<void> flushQueue() async {
    if (_flushing) return;
    _flushing = true;

    try {
      final online = await _network.isOnline;
      if (!online) return;

      final totalPending = await _queue.count();
      if (totalPending == 0) return;

      _events.add(SyncFlushStarted(pendingCount: totalPending));

      int synced = 0;
      int failed = 0;

      // Procesa FIFO por batches.
      while (true) {
        final batch = await _queue.peek(limit: 50);
        if (batch.isEmpty) break;

        bool sawTransientFailure = false;

        for (final task in batch) {
          final outcome = await _sendTask(task);

          _events.add(
            SyncFlushProgress(
              done: synced + failed + 1,
              total: totalPending,
              kind: task.kind,
              entityId: task.entityId,
            ),
          );

          if (outcome is TransportWriteSuccess) {
            synced++;
            await _queue.remove(task);
            continue;
          }

          if (outcome is TransportWriteConflict) {
            failed++;
            await _queue.remove(task);
            _events.add(SyncConflictEvent(kind: task.kind, entityId: task.entityId));
            continue;
          }

          if (outcome is TransportWritePermanentFailure) {
            failed++;
            await _queue.remove(task);
            continue;
          }

          if (outcome is TransportWriteTransientFailure) {
            failed++;
            sawTransientFailure = true;

            final updated = task.copyWith(attempts: task.attempts + 1);
            await _queue.update(updated);

            // Para UX/batería: si hubo transitorio, cortamos acá.
            if (_policy.stopBatchOnTransientFailure) break;
          }
        }

        if (!sawTransientFailure) {
          // Si se procesó todo sin transitorios, seguimos viendo si queda algo.
          continue;
        }

        // Si hubo transitorio (y policy lo indica), salimos para reintentar en el próximo flush.
        break;
      }

      _events.add(SyncFlushCompleted(syncedCount: synced, failedCount: failed));
    } finally {
      _flushing = false;
    }
  }

  /// ------------------------------
  /// Internals
  /// ------------------------------

  Future<SyncOutcome> _enqueueAndMaybeFlush<T>(
    SyncAdapter<T> adapter,
    T entity,
  ) async {
    final entityId = adapter.idOf(entity);
    final updatedAt = adapter.updatedAtOf(entity).toUtc();
    final deleted = adapter.deletedOf(entity);
    final payload = adapter.toJson(entity);

    final idempotencyKey = _buildIdempotencyKey(
      userId: _session.userId,
      kind: adapter.kind,
      entityId: entityId,
      updatedAt: updatedAt,
      deleted: deleted,
    );

    final task = SyncTask(
      kind: adapter.kind,
      entityId: entityId,
      payload: payload,
      updatedAt: updatedAt,
      deleted: deleted,
      idempotencyKey: idempotencyKey,
    );

    await _queue.enqueue(task);

    final online = await _network.isOnline;
    _events.add(
      SyncEnqueued(
        kind: adapter.kind,
        entityId: entityId,
        reason: online ? 'online' : 'offline',
      ),
    );

    if (!online || !_policy.flushOnEnqueueIfOnline) {
      return SyncQueued(reason: online ? 'queued' : 'offline');
    }

    // Fast-path: intentamos enviar este task ya mismo
    final outcome = await _sendTask(task);

    if (outcome is TransportWriteSuccess) {
      // Removemos todos los tasks pendientes para este entity (si los hubiera)
      await _removeAllForEntity(adapter.kind, entityId);
      return const SyncSuccess();
    }

    if (outcome is TransportWriteConflict) {
      await _removeAllForEntity(adapter.kind, entityId);

      final conflict = SyncConflict(
        kind: adapter.kind,
        entityId: entityId,
        local: entity as Object,
        remotePayload: outcome.remotePayload,
        remoteUpdatedAt: outcome.remoteUpdatedAt,
      );

      _events.add(SyncConflictEvent(kind: adapter.kind, entityId: entityId));

      if (_onConflict != null) {
        final res = await _onConflict!(conflict);
        return _handleConflictResolution(conflict, res);
      }

      return conflict;
    }

    if (outcome is TransportWritePermanentFailure) {
      return SyncFailure(error: outcome.error, isRetryable: false);
    }

    if (outcome is TransportWriteTransientFailure) {
      // Queda en cola (ya está).
      return SyncQueued(reason: 'transient_failure_queued');
    }

    return SyncQueued(reason: 'queued');
  }

  Future<void> _removeAllForEntity(SyncEntityKind kind, String entityId) async {
    final pending = await _queue.peek(limit: 500);
    for (final t in pending) {
      if (t.kind == kind && t.entityId == entityId) {
        await _queue.remove(t);
      }
    }
  }

  Future<SyncOutcome> _handleConflictResolution(
    SyncConflict conflict,
    SyncConflictResolution resolution,
  ) async {
    switch (resolution.decision) {
      case SyncConflictResolutionDecision.manual:
        return conflict;

      case SyncConflictResolutionDecision.acceptRemote:
        // El repo debe aplicar remotePayload al storage local.
        return conflict;

      case SyncConflictResolutionDecision.keepLocalForceWrite:
        final now = DateTime.now().toUtc();

        // Intentamos re-escritura forzada (si tu backend lo soporta).
        final req = TransportWriteRequest(
          userId: _session.userId,
          kind: conflict.kind,
          entityId: conflict.entityId,
          payload: _safeMapCopy(conflict.local),
          updatedAt: now,
          deleted: false,
          idempotencyKey: _buildIdempotencyKey(
            userId: _session.userId,
            kind: conflict.kind,
            entityId: conflict.entityId,
            updatedAt: now,
            deleted: false,
          ),
          mode: SyncWriteMode.force,
        );

        final out = await _transport.write(req);
        if (out is TransportWriteSuccess) return const SyncSuccess();
        if (out is TransportWritePermanentFailure) {
          return SyncFailure(error: out.error, isRetryable: false);
        }
        if (out is TransportWriteTransientFailure) {
          // Dejamos en cola un task “force” no lo soporta la cola hoy (por simplicidad).
          // El caller puede reintentar luego con keepLocalForceWrite.
          return SyncQueued(reason: 'force_write_transient_queued');
        }
        return conflict;
    }
  }

  Future<TransportWriteOutcome> _sendTask(SyncTask task) async {
    // Control de attempts + backoff.
    if (task.attempts >= _policy.maxAttempts) {
      return TransportWritePermanentFailure(
        StateError('Max attempts reached for ${task.kind}:${task.entityId}'),
      );
    }

    // Backoff antes del intento (si ya falló antes).
    if (task.attempts > 0) {
      final delay = _computeBackoff(
        attempts: task.attempts,
        base: _policy.baseBackoff,
        cap: _policy.maxBackoff,
      );
      await Future<void>.delayed(delay);
    }

    return _transport.write(
      TransportWriteRequest(
        userId: _session.userId,
        kind: task.kind,
        entityId: task.entityId,
        payload: task.payload,
        updatedAt: task.updatedAt,
        deleted: task.deleted,
        idempotencyKey: task.idempotencyKey,
        mode: SyncWriteMode.normal,
      ),
    );
  }

  Duration _computeBackoff({
    required int attempts,
    required Duration base,
    required Duration cap,
  }) {
    // Exponencial con cap.
    // attempts: 1 => base*2, 2 => base*4, etc.
    final factor = 1 << attempts; // 2^attempts
    final ms = base.inMilliseconds * factor;
    final cappedMs = ms > cap.inMilliseconds ? cap.inMilliseconds : ms;
    return Duration(milliseconds: cappedMs);
  }

  String _buildIdempotencyKey({
    required String userId,
    required SyncEntityKind kind,
    required String entityId,
    required DateTime updatedAt,
    required bool deleted,
  }) {
    final ts = updatedAt.toUtc().millisecondsSinceEpoch;
    return '$userId|${kind.name}|$entityId|$ts|${deleted ? 1 : 0}';
  }

  Map<String, Object?> _safeMapCopy(Object local) {
    // Best-effort: si local ya es Map, lo copia.
    if (local is Map<String, Object?>) return Map<String, Object?>.from(local);

    // Si local es una entidad del dominio con toJson(), intentamos usarlo.
    // (No usamos `dynamic` en público; esto es interno y controlado.)
    try {
      final dyn = local as dynamic;
      final Map<String, Object?> json = (dyn.toJson() as Map).cast<String, Object?>();
      return Map<String, Object?>.from(json);
    } catch (_) {
      return <String, Object?>{};
    }
  }
}

/// ------------------------------------------------------------------
/// Implementaciones DEV (para que compile y funcione sin backend real)
/// ------------------------------------------------------------------

class NoopRemoteSyncTransport implements RemoteSyncTransport {
  @override
  Future<TransportWriteOutcome> write(TransportWriteRequest request) async {
    // Simula OK.
    return const TransportWriteSuccess();
  }

  @override
  Future<TransportPullResponse> pull(TransportPullRequest request) async {
    // No trae cambios.
    return TransportPullResponse(nextCursor: request.since, items: const []);
  }
}

class AlwaysOnlineNetworkStatus implements NetworkStatus {
  const AlwaysOnlineNetworkStatus();

  @override
  Future<bool> get isOnline async => true;
}

class StaticSyncSession implements SyncSession {
  const StaticSyncSession({required this.userId});

  @override
  final String userId;
}
