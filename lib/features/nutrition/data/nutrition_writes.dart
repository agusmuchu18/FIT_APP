import 'dart:async';

/// Orders read/modify/write operations across instances without mixing owners.
abstract final class NutritionWrites {
  static final _queues = <String, Future<void>>{};
  static Future<T> run<T>(String key, Future<T> Function() action) async {
    final previous = _queues[key];
    final gate = Completer<void>();
    _queues[key] = gate.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      if (identical(_queues[key], gate.future)) _queues.remove(key);
      gate.complete();
    }
  }
}
