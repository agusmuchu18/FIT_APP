import 'fdc_client.dart';

class FoodCache {
  FoodCache({this.maxSearchEntries = 50, this.maxDetailsEntries = 200})
    : assert(maxSearchEntries > 0),
      assert(maxDetailsEntries > 0);

  final int maxSearchEntries;
  final int maxDetailsEntries;

  // --- Details cache ---
  final _details = <int, _Cached<Map<String, dynamic>>>{};

  Map<String, dynamic>? getDetails(int fdcId) {
    final c = _details[fdcId];
    if (c == null) return null;
    if (c.isExpired) {
      _details.remove(fdcId);
      return null;
    }
    _details
      ..remove(fdcId)
      ..[fdcId] = c;
    return c.value;
  }

  void putDetails(
    int fdcId,
    Map<String, dynamic> json, {
    Duration ttl = const Duration(days: 180),
  }) {
    _details
      ..remove(fdcId)
      ..[fdcId] = _Cached(Map<String, dynamic>.unmodifiable(json), ttl);
    _trimToSize(_details, maxDetailsEntries);
  }

  // --- Search cache (por query) ---
  final _search = <String, _Cached<List<FdcSearchItem>>>{};

  List<FdcSearchItem>? getSearch(String query) {
    final key = _normalizeQuery(query);
    final c = _search[key];
    if (c == null) return null;
    if (c.isExpired) {
      _search.remove(key);
      return null;
    }
    _search
      ..remove(key)
      ..[key] = c;
    return c.value;
  }

  void putSearch(
    String query,
    List<FdcSearchItem> items, {
    Duration ttl = const Duration(days: 3),
  }) {
    final key = _normalizeQuery(query);
    _search
      ..remove(key)
      ..[key] = _Cached(List<FdcSearchItem>.unmodifiable(items), ttl);
    _trimToSize(_search, maxSearchEntries);
  }

  void clear() {
    _details.clear();
    _search.clear();
  }

  String _normalizeQuery(String q) =>
      q.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  void _trimToSize<K, V>(Map<K, V> cache, int maxEntries) {
    while (cache.length > maxEntries) {
      cache.remove(cache.keys.first);
    }
  }
}

class _Cached<T> {
  _Cached(this.value, Duration ttl) : expiresAt = DateTime.now().add(ttl);

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
