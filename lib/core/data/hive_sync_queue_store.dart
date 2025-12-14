import 'package:hive/hive.dart';

import 'remote_sync_service.dart';

class HiveSyncQueueStore implements SyncQueueStore {
  HiveSyncQueueStore._(this._box);

  static const _boxName = 'sync_queue';

  final Box<Map> _box;

  static Future<HiveSyncQueueStore> create() async {
    final box = await Hive.openBox<Map>(_boxName);
    return HiveSyncQueueStore._(box);
  }

  @override
  Future<void> enqueue(SyncTask task) async {
    final key = _dedupeKey(task.kind, task.entityId);
    final serialized = _serialize(task);
    await _box.put(key, serialized);
  }

  @override
  Future<List<SyncTask>> peek({int limit = 50}) async {
    if (_box.isEmpty) return const [];

    final tasks = _box.values.map(_deserialize).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return List<SyncTask>.unmodifiable(tasks.take(limit));
  }

  @override
  Future<void> remove(SyncTask task) async {
    final key = _dedupeKey(task.kind, task.entityId);
    final raw = _box.get(key);
    if (raw == null) return;

    final stored = _deserialize(raw);
    if (stored.idempotencyKey == task.idempotencyKey) {
      await _box.delete(key);
    }
  }

  @override
  Future<void> update(SyncTask task) async {
    final key = _dedupeKey(task.kind, task.entityId);
    if (_box.containsKey(key)) {
      await _box.put(key, _serialize(task));
    }
  }

  @override
  Future<int> count() async => _box.length;

  static String _dedupeKey(SyncEntityKind kind, String entityId) {
    return '${kind.name}:$entityId';
  }

  Map<String, Object?> _serialize(SyncTask task) {
    return <String, Object?>{
      'kind': task.kind.name,
      'entityId': task.entityId,
      'payload': task.payload,
      'updatedAt': task.updatedAt.toIso8601String(),
      'deleted': task.deleted,
      'idempotencyKey': task.idempotencyKey,
      'attempts': task.attempts,
      'createdAt': task.createdAt.toIso8601String(),
    };
  }

  SyncTask _deserialize(Map<dynamic, dynamic> raw) {
    final kindName = raw['kind'] as String;
    final kind = SyncEntityKind.values.firstWhere((k) => k.name == kindName);

    return SyncTask(
      kind: kind,
      entityId: raw['entityId'] as String,
      payload: Map<String, Object?>.from(raw['payload'] as Map),
      updatedAt: DateTime.parse(raw['updatedAt'] as String),
      deleted: raw['deleted'] as bool,
      idempotencyKey: raw['idempotencyKey'] as String,
      attempts: (raw['attempts'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(raw['createdAt'] as String),
    );
  }
}
