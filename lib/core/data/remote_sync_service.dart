import 'dart:async';
import '../domain/entities.dart';

/// RemoteSyncService (versión pro)
/// - Offline-first (cola)
/// - Reintentos con backoff
/// - Idempotencia (evita duplicados)
/// - Resultado tipado (success/queued/failure/conflict)
/// - Observabilidad (Stream de eventos)
///
/// NOTA: Este archivo define interfaces pequeñas (transport/queue/network/adapters)
/// para que puedas enchufar Firebase o REST sin acoplarte a una librería concreta.

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

  /// Escritura forzada: se usa sólo si decidís que "gana local" (si tu backend lo soporta).
  force,
}

class SyncCursor {
  const SyncCursor(this.value);
  final String value;

  static const zero = SyncCursor('0');

  @override
  String toString() => value;
}

/// Eventos para UI/Logs/Debug.
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
  const SyncFlushCompleted({required this.syncedCount, required this.failedCount});

  final int syncedCount;
  final int failedCount;

  @override
  String toString() => 'SyncFlushCompleted(synced=$syncedCount, failed=$failedCount)';
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

/// Resultado de una operación de sync (para el caller).
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

  static const manual = SyncConflictResolution(SyncConflictResolutionDecision.manual);
  static const acceptRemote = SyncConflictResolution(SyncConflictResolutionDecision.acceptRemote);
  static const keepLocalForceWrite =
      SyncConflictResolution(SyncConflictResolutionDecision.keepLocalForceWrite);
}

/// Config de política: reintentos y backoff.
class SyncPolicy {
  const SyncPolicy({
    this.maxAttempts = 8,
    this.baseBackoff = const Duration(seconds: 2),
    this.maxBackoff = const Duration(minutes: 2),
    this.flushOnEnqueueIfOnline = true,
  });

  final int maxAttempts;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final bool flushOnEnqueueIfOnline;
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
/// (No asumo que tus entities tengan id/updatedAt/toJson, por eso es inyectable)
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
  }) : createdAt = createdAt ?? DateTime.now();

  final SyncEntityKind kind;
  final String entityId;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
  final bool deleted;
  final String idempotencyKey;

  final DateTime createdAt;
  int attempts;
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
    // Dedupe simple por kind+entityId: si hay uno viejo, lo reemplazo por el más nuevo.
    final idx = _q.indexWhere((t) => t.kind == task.kind && t.entityId == task.entityId);
    if (idx >= 0) {
      _q[idx] = task;
    } else {
      _q.add(task);
    }
  }

  @override
  Future<List<SyncTask>> peek({int limit = 50}) async {
    if (_q.isEmpty) return const [];
    return List<SyncTask>.unmodifiable(_q.take(limit));
  }

  @override
  Future<void> remove(SyncTask task) async {
    _q.remove(task);
  }

  @override
  Future<void> update(SyncTask task) async {
    // en memoria, ya está referenciado; no hace falta.
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

  /// Wrappers con tu API vieja (si querés mantener nombres):
  Future<SyncOutcome> syncWorkout(WorkoutEntry entry) => upsertWorkout(entry);
  Future<SyncOutcome> syncMeal(MealEntry entry) => upsertMeal(entry);
  Future<SyncOutcome> syncSleep(SleepEntry entry) => upsertSleep(entry);
  Future<SyncOutcome> syncPreferences(UserPreferences preferences) => upsertPreferences(preferences);

  /// API recomendada (upsert = create/update; delete se infiere por adapter.deletedOf)
  Future<SyncOutcome> upsertWorkout(WorkoutEntry entry) async =>
      _enqueueAndMaybeFlush(_workoutAdapter, entry);

  Future<SyncOutcome> upsertMeal(MealEntry entry) async => _enqueueAndMaybeFlush(_mealAdapter, entry);

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
      if (!online) {
        // No hacemos nada si no hay conectividad.
        return;
      }

      final totalPending = await _queue.count();
      if (totalPending == 0) return;

      _events.add(SyncFlushStarted(pendingCount: totalPending));

      int synced = 0;
      int failed = 0;

      // Procesa FIFO en batches.
      while (true) {
        final batch = await _queue.peek(limit: 50);
        if (batch.isEmpty) break;

        int doneInBatch = 0;
        for (final task in batch) {
          final outcome = await _sendTask(task);

          doneInBatch++;
          _events.add(
            SyncFlushProgress(
              done: synced + failed + doneInBatch,
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
            // Conflicto: lo quitamos de la cola para no quedar en loop.
            // El caller debería resolver vía retorno de upsertX o escuchando eventos.
            await _queue.remove(task);
            _events.add(SyncConflictEvent(kind: task.kind, entityId: task.entityId));
            continue;
          }

          if (outcome is TransportWritePermanentFailure) {
            failed++;
            // Permanent: lo sacamos para evitar retries infinitos.
            await _queue.remove(task);
            continue;
          }

          // Transient: se queda en cola con attempts incrementados y backoff.
          if (outcome is TransportWriteTransientFailure) {
            failed++;
            task.attempts += 1;
            await _queue.update(task);
            // Seguimos con el resto (no bloqueamos toda la cola por un ítem).
            continue;
          }
        }

        // Para evitar loops muy pesados, si todavía quedan items y algunos fallaron
        // transitoriamente, cortamos y dejamos el resto para el próximo flush.
        // (Esto mejora UX/batería y evita hacer “spin”.)
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

  Future<SyncOutcome> _enqueueAndMaybeFlush<T>(SyncAdapter<T> adapter, T entity) async {
    final entityId = adapter.idOf(entity);
    final updatedAt = adapter.updatedAtOf(entity);
    final deleted = adapter.deletedOf(entity);
    final payload = adapter.toJson(entity);

    // Idempotency: estable, determinístico. Si el backend la soporta, evita duplicados
    // ante retries. (Formato simple y portable)
    final idempotencyKey = _buildIdempotencyKey(
      userId: _session.userId,
      kind: adapter.kind,
      entityId: entityId,
      updatedAt: updatedAt,
      deleted: deleted,
    );

    await _queue.enqueue(
      SyncTask(
        kind: adapter.kind,
        entityId: entityId,
        payload: payload,
        updatedAt: updatedAt,
        deleted: deleted,
        idempotencyKey: idempotencyKey,
      ),
    );

    final online = await _network.isOnline;
    _events.add(SyncEnqueued(kind: adapter.kind, entityId: entityId, reason: online ? 'online' : 'offline'));

    // Si hay red, intentamos flush “optimista” para que se sincronice rápido.
    if (online && _policy.flushOnEnqueueIfOnline) {
      // Intento corto: enviar sólo el task más reciente (dedupe ya aplicado).
      final single = SyncTask(
        kind: adapter.kind,
        entityId: entityId,
        payload: payload,
        updatedAt: updatedAt,
        deleted: deleted,
        idempotencyKey: idempotencyKey,
      );

      final outcome = await _sendTask(single);
      if (outcome is TransportWriteSuccess) {
        // Si se sincronizó, removemos de la cola (por si estaba).
        final pending = await _queue.peek(limit: 200);
        for (final t in pending) {
          if (t.kind == adapter.kind && t.entityId == entityId) {
            await _queue.remove(t);
          }
        }
        return const SyncSuccess();
      }

      if (outcome is TransportWriteConflict) {
        final conflict = SyncConflict(
          kind: adapter.kind,
          entityId: entityId,
          local: entity as Object,
          remotePayload: outcome.remotePayload,
          remoteUpdatedAt: outcome.remoteUpdatedAt,
        );

        _events.add(SyncConflictEvent(kind: adapter.kind, entityId: entityId));

        // Si hay handler, intentamos resolver automáticamente.
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
        return SyncQueued(reason: 'transient_failure_queued');
      }
    }

    // Sin red o sin flush inmediato: queda en cola.
    return SyncQueued(reason: online ? 'queued' : 'offline');
  }

  Future<SyncOutcome> _handleConflictResolution(
    SyncConflict conflict,
    SyncConflictResolution resolution,
  ) async {
    switch (resolution.decision) {
      case SyncConflictResolutionDecision.manual:
        return conflict;

      case SyncConflictResolutionDecision.acceptRemote:
        // El repo debe aplicar remotePayload localmente.
        return conflict;

      case SyncConflictResolutionDecision.keepLocalForceWrite:
        // Intentamos re-escritura forzada (si tu backend lo soporta).
        final req = TransportWriteRequest(
          userId: _session.userId,
          kind: conflict.kind,
          entityId: conflict.entityId,
          payload: _safeMapCopy(conflict.local), // best-effort
          updatedAt: DateTime.now(),
          deleted: false,
          idempotencyKey: _buildIdempotencyKey(
            userId: _session.userId,
            kind: conflict.kind,
            entityId: conflict.entityId,
            updatedAt: DateTime.now(),
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
          return SyncQueued(reason: 'force_write_transient_queued');
        }
        // Si vuelve a conflicto, lo dejamos manual.
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

    if (task.attempts > 0) {
      final delay = _computeBackoff(task.attempts, _policy.baseBackoff, _policy.maxBackoff);
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

  Duration _computeBackoff(int attempts, Duration base, Duration cap) {
    // Exponencial simple con cap.
    // attempts: 1 => base * 2, 2 => base * 4, etc.
    final factor = 1 << attempts; // 2^attempts
    final ms = base.inMilliseconds * factor;
    final capped = ms > cap.inMilliseconds ? cap.inMilliseconds : ms;
    return Duration(milliseconds: capped);
  }

  String _buildIdempotencyKey({
    required String userId,
    required SyncEntityKind kind,
    required String entityId,
    required DateTime updatedAt,
    required bool deleted,
  }) {
    // Formato determinístico y “human debuggable”.
    final ts = updatedAt.toUtc().millisecondsSinceEpoch;
    return '$userId|${kind.name}|$entityId|$ts|${deleted ? 1 : 0}';
  }

  Map<String, Object?> _safeMapCopy(Object local) {
    // Best-effort: si local es Map ya, lo copia.
    if (local is Map<String, Object?>) {
      return Map<String, Object?>.from(local);
    }
    // Si no, devolvemos mapa vacío y dejamos que el caller implemente la ruta real (merge/rewrite).
    return <String, Object?>{};
  }
}
