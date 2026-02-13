import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

abstract class StringKeyValueStore {
  Future<String?> get(String key);
  Future<void> put(String key, String value);
}

class HiveStringKeyValueStore implements StringKeyValueStore {
  HiveStringKeyValueStore(this._box);

  final Box<String> _box;

  @override
  Future<String?> get(String key) async => _box.get(key);

  @override
  Future<void> put(String key, String value) => _box.put(key, value);
}

class HabitTemplatePopularityStore {
  HabitTemplatePopularityStore(this._store);

  static const String boxName = 'fit_prefs';
  static const String storageKey = 'habit_template_popularity';

  final StringKeyValueStore _store;

  static Future<HabitTemplatePopularityStore> create() async {
    final box = await Hive.openBox<String>(boxName);
    return HabitTemplatePopularityStore(HiveStringKeyValueStore(box));
  }

  Future<Map<String, int>> loadScores() async {
    final raw = await _store.get(storageKey);
    if (raw == null || raw.isEmpty) return <String, int>{};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', _toInt(value)));
      }
    } catch (_) {}
    return <String, int>{};
  }

  Future<void> incrementMany(Iterable<String> templateIds) async {
    final ids = templateIds.where((id) => id.isNotEmpty).toList(growable: false);
    if (ids.isEmpty) return;

    final scores = await loadScores();
    for (final id in ids) {
      scores[id] = (scores[id] ?? 0) + 1;
    }
    await _store.put(storageKey, jsonEncode(scores));
  }

  int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
