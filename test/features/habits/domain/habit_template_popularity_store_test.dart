import 'dart:convert';

import 'package:fit_app/features/habits/data/habit_template_popularity_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements StringKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> get(String key) async => data[key];

  @override
  Future<void> put(String key, String value) async {
    data[key] = value;
  }
}

void main() {
  test('incrementa y persiste popularity score', () async {
    final memory = _MemoryStore();
    final store = HabitTemplatePopularityStore(memory);

    await store.incrementMany(['a', 'a', 'b']);

    final decoded = jsonDecode(memory.data[HabitTemplatePopularityStore.storageKey]!) as Map;
    expect(decoded['a'], 2);
    expect(decoded['b'], 1);

    final loaded = await store.loadScores();
    expect(loaded['a'], 2);
    expect(loaded['b'], 1);
  });
}
