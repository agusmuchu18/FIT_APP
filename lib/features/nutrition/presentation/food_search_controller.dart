import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../nutrition/data/fdc_client.dart';

class FoodSearchController extends ChangeNotifier {
  FoodSearchController({
    required FdcClient client,
    required FoodCache cache,
  })  : _client = client,
        _cache = cache;

  final FdcClient _client;
  final FoodCache _cache;

  List<FdcSearchItem> results = const [];
  bool isLoading = false;
  String? error;

  Timer? _debounce;
  String _lastQuery = '';

  /// Llamalo en onChanged del TextField.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();

    // Si está vacío, limpiamos.
    if (q.isEmpty) {
      _lastQuery = '';
      results = const [];
      error = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    // Debounce: espera 300ms después de que deje de tipear.
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      await search(q);
    });
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    // Evitá repetir la misma query.
    if (q == _lastQuery && results.isNotEmpty) return;
    _lastQuery = q;

    // 1) Cache de búsqueda (Paso 5)
    final cached = _cache.getSearch(q);
    if (cached != null) {
      results = cached;
      error = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final items = await _client.searchFoods(q, pageSize: 25, pageNumber: 1);
      results = items;
      _cache.putSearch(q, items); // cachear búsqueda
    } catch (e) {
      error = e.toString();
      results = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Se llama cuando el usuario toca un item.
  Future<Map<String, dynamic>> getDetails(int fdcId) async {
    // 1) Cache details
    final cached = _cache.getDetails(fdcId);
    if (cached != null) return cached;

    // 2) Si no está cacheado, pedir al API
    final json = await _client.getFoodDetails(fdcId);
    _cache.putDetails(fdcId, json);
    return json;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
