import '../data/fdc_client.dart';

class FoodCache {
  // --- Details cache ---
  final _details = <int, _Cached<Map<String, dynamic>>>{};

  Map<String, dynamic>? getDetails(int fdcId) {
    final c = _details[fdcId];
    if (c == null) return null;
    if (c.isExpired) {
      _details.remove(fdcId);
      return null;
    }
    return c.value;
  }

  void putDetails(int fdcId, Map<String, dynamic> json,
      {Duration ttl = const Duration(days: 180)}) {
    _details[fdcId] = _Cached(json, ttl);
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
    return c.value;
  }

  void putSearch(String query, List<FdcSearchItem> items,
      {Duration ttl = const Duration(days: 3)}) {
    final key = _normalizeQuery(query);
    _search[key] = _Cached(items, ttl);
  }

  void clear() {
    _details.clear();
    _search.clear();
  }

  String _normalizeQuery(String q) => q.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _Cached<T> {
  _Cached(this.value, Duration ttl) : expiresAt = DateTime.now().add(ttl);

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
