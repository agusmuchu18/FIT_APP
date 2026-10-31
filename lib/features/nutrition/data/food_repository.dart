import 'dart:convert';

import '../../../core/data/account_storage_scope.dart';
import 'nutrition_writes.dart';
import '../domain/models.dart';
import 'nutrition_day_repository.dart';
import 'offline_food_catalog.dart';
import 'templates_repository.dart';
import 'fdc_client.dart';
import 'fdc_mapper.dart';
import 'food_cache.dart';

class FoodRepository {
  FoodRepository({
    required this._fdc,
    FoodCache? cache,
    NutritionDayRepository? days,
    String? scope,
  }) : _cache = cache ?? FoodCache(),
       _scope = scope ?? AccountStorageScope.current,
       _templates = TemplatesRepository(scope: scope),
       _days = days ?? NutritionDayRepository(scope: scope);
  final String _scope;
  String get storageScope => _scope;
  bool get projectionPending => _days.projectionPending;

  final FdcClient _fdc;
  final FoodCache _cache;
  final List<FoodItem> _foods = [..._seedFoods];
  static const customFoodsKey = 'nutrition.custom_foods.v1';
  static const learnedUsdaFoodsKey = 'nutrition.usda_foods.v1';
  final TemplatesRepository _templates;
  final NutritionDayRepository _days;
  Future<void>? _loaded;

  Future<void> _ensureLoaded() => _loaded ??= _loadCustomFoods();

  Future<void> _loadCustomFoods() async {
    final bundled = await OfflineFoodCatalog.load();
    _foods.addAll(
      bundled.where((item) => !_foods.any((food) => food.id == item.id)),
    );
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final learnedRaw = prefs.getString(learnedUsdaFoodsKey);
    if (learnedRaw != null) {
      final learned = (jsonDecode(learnedRaw) as List).map(
        (item) => FoodItem.fromJson(Map<String, dynamic>.from(item as Map)),
      );
      for (var food in learned) {
        if (food.source == 'legacy' && food.id.startsWith('fdc:')) {
          food = FoodItem.fromJson({...food.toJson(), 'detailsLoaded': false});
        }
        if (food.source == 'legacy' &&
            _foods.any(
              (f) => f.id == food.id && f.source.startsWith('USDA Foundation'),
            )) {
          continue;
        }
        _foods.removeWhere((existing) => existing.id == food.id);
        _foods.insert(0, food);
      }
    }
    final raw = prefs.getString(customFoodsKey);
    if (raw == null) return;
    final foods = (jsonDecode(raw) as List).map(
      (item) => FoodItem.fromJson(Map<String, dynamic>.from(item as Map)),
    );
    _foods.insertAll(0, foods);
  }

  bool get hasRemoteSource => _fdc.isConfigured;

  Future<List<FoodItem>> loadLocalCatalog() async {
    await _ensureLoaded();
    return List.unmodifiable(_foods);
  }

  Future<List<FoodItem>> syncWithPublicCatalog() async => loadLocalCatalog();

  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];

    final local = await searchLocalFoods(query);
    if (!hasRemoteSource) return local;

    final remoteQuery = expandSpanishSearch(query).last;

    final cached = _cache.getSearch(query);
    if (cached != null) {
      return _mergeFoods(local, cached.map(_mapSearchItemToFood)).toList();
    }

    final fdcResults = await _fdc.searchFoods(
      remoteQuery,
      dataTypes: const ['Foundation', 'SR Legacy', 'Branded', 'Survey (FNDDS)'],
      pageSize: 60,
    );
    _cache.putSearch(query, fdcResults);

    return _mergeFoods(local, fdcResults.map(_mapSearchItemToFood)).toList();
  }

  Future<List<FoodItem>> searchLocalFoods(String query) async {
    await _ensureLoaded();
    if (query.trim().isEmpty) return [];
    final queries = expandSpanishSearch(query);
    final matches = _foods.where((food) {
      final searchable = [
        food.name,
        food.categoryLabel,
        ...food.searchKeywords,
      ].join(' ');
      final normalized = normalizeFoodSearch(searchable);
      return queries.any((q) => q.split(' ').every(normalized.contains));
    }).toList();
    matches.sort((a, b) {
      int score(FoodItem food) {
        final name = normalizeFoodSearch(food.name);
        if (queries.any((term) => name == term)) return 0;
        if (queries.any(name.startsWith)) return 1;
        if (queries.any(name.contains)) return 2;
        return 3;
      }

      final comparison = score(a).compareTo(score(b));
      return comparison != 0 ? comparison : a.name.compareTo(b.name);
    });
    return matches.take(80).toList();
  }

  Future<FoodItem> getFoodItemFromFdc(int fdcId) async {
    final cached = _cache.getDetails(fdcId);
    if (cached != null) {
      return _mapDetailsToFood(cached);
    }

    final details = await _fdc.getFoodDetails(fdcId);
    _cache.putDetails(fdcId, details);
    final food = _mapDetailsToFood(details);
    await _saveLearnedUsdaFood(food);
    return food;
  }

  Future<void> _saveLearnedUsdaFood(FoodItem food) => NutritionWrites.run(
    'learned:$_scope',
    () async {
      final prefs = await ScopedPreferences.getInstance(scope: _scope);
      final raw = prefs.getString(learnedUsdaFoodsKey);
      final current = raw == null
          ? <FoodItem>[]
          : (jsonDecode(raw) as List)
                .map(
                  (item) =>
                      FoodItem.fromJson(Map<String, dynamic>.from(item as Map)),
                )
                .toList();
      current.removeWhere((item) => item.id == food.id);
      current.insert(0, food);
      await prefs.setString(
        learnedUsdaFoodsKey,
        jsonEncode(current.take(500).map((item) => item.toJson()).toList()),
      );
      _foods.removeWhere((f) => f.id == food.id);
      _foods.insert(0, food);
    },
  );

  Future<List<FoodItem>> getSuggestedFoods(MealType mealType) async {
    await _ensureLoaded();
    final mealKeyword = mealType.name.toLowerCase();
    final prioritized = <FoodItem>[];
    final rest = <FoodItem>[];

    for (final food in _foods) {
      final matchesMeal = food.searchKeywords.any(
        (keyword) => keyword.toLowerCase() == mealKeyword,
      );
      if (matchesMeal) {
        prioritized.add(food);
      } else {
        rest.add(food);
      }
    }

    return [...prioritized, ...rest].take(60).toList();
  }

  Future<void> createCustomFood(FoodItem item, {bool onlyIfMissing = false}) =>
      NutritionWrites.run('foods:$_scope', () async {
        await _ensureLoaded();
        final prefs = await ScopedPreferences.getInstance(scope: _scope);
        final raw = prefs.getString(customFoodsKey);
        final saved = raw == null
            ? <FoodItem>[]
            : (jsonDecode(raw) as List)
                  .map(
                    (e) =>
                        FoodItem.fromJson(Map<String, dynamic>.from(e as Map)),
                  )
                  .toList();
        validateNutritionFood(item);
        final old =
            saved.where((f) => f.id == item.id).firstOrNull ??
            _foods.where((f) => f.id == item.id).firstOrNull;
        if (onlyIfMissing && old != null) {
          if (nutritionDataEqual(old.toJson(), item.toJson())) return;
          throw StateError('El alimento ya existe con otros datos.');
        }
        saved.removeWhere((f) => f.id == item.id);
        saved.insert(0, item);
        await prefs.setString(
          customFoodsKey,
          jsonEncode(saved.map((f) => f.toJson()).toList()),
        );
        _foods.removeWhere((f) => f.id == item.id);
        _foods.insert(0, item);
      });

  Future<
    List<({String query, num quantity, FoodUnit unit, List<FoodItem> matches})>
  >
  parseStructuredText(String text) async {
    if (text.length > 5000) {
      throw const FormatException('El texto es demasiado largo.');
    }
    final lines = text
        .split(RegExp(r'[\n;]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isEmpty || lines.length > 20) {
      throw const FormatException('Ingresá entre 1 y 20 líneas.');
    }
    final result =
        <
          ({String query, num quantity, FoodUnit unit, List<FoodItem> matches})
        >[];
    final pattern = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*(kg|g|ml|porci[oó]n(?:es)?)\s+(?:de\s+)?(.+)$',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match == null) {
        throw FormatException('Falta cantidad o unidad en: $line');
      }
      final number = double.parse(match[1]!.replaceAll(',', '.'));
      final symbol = match[2]!.toLowerCase();
      final query = match[3]!.trim();
      if (!number.isFinite || number <= 0) {
        throw const FormatException('Usá cantidades mayores que cero.');
      }
      final unit = symbol == 'ml'
          ? FoodUnit.ml
          : symbol.startsWith('porci')
          ? FoodUnit.serving
          : FoodUnit.grams;
      final matches = await searchLocalFoods(query);
      result.add((
        query: query,
        quantity: symbol == 'kg' ? number * 1000 : number,
        unit: unit,
        matches: matches.take(8).toList(),
      ));
    }
    return result;
  }

  Future<FoodItem?> findByBarcode(String input) async {
    final normalized = normalizeNutritionBarcode(input);
    await _ensureLoaded();
    for (final f in _foods) {
      if (f.barcode == null) continue;
      try {
        if (normalizeNutritionBarcode(f.barcode!) == normalized) return f;
      } on FormatException {
        continue;
      }
    }
    if (!hasRemoteSource) return null;
    final results = await _fdc.searchFoods(
      input.trim(),
      dataTypes: const ['Branded'],
      pageSize: 5,
    );
    for (final match in results.take(5)) {
      final details = await _fdc.getFoodDetails(match.fdcId);
      final code = details['gtinUpc']?.toString();
      if (code == null) continue;
      String candidate;
      try {
        candidate = normalizeNutritionBarcode(code);
      } on FormatException {
        continue;
      }
      if (candidate != normalized) continue;
      final food = _mapDetailsToFood(details);
      await _saveLearnedUsdaFood(food);
      return food;
    }
    return null;
  }

  Future<Set<String>> favoriteFoodIds() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    return ((jsonDecode(
      prefs.getString('nutrition.favorite_foods.v1') ?? '[]',
    )) as List).cast<String>().toSet();
  }

  Future<void> toggleFavoriteFood(String id) => _writeFavorite(id, null);
  Future<void> setFavoriteFood(String id, bool selected) =>
      _writeFavorite(id, selected);
  Future<void> _writeFavorite(String id, bool? selected) =>
      NutritionWrites.run('favorite-foods:$_scope', () async {
        final ids = await favoriteFoodIds();
        if (selected == true) {
          ids.add(id);
        } else if (selected == false) {
          ids.remove(id);
        } else if (!ids.add(id)) {
          ids.remove(id);
        }
        final prefs = await ScopedPreferences.getInstance(scope: _scope);
        await prefs.setString(
          'nutrition.favorite_foods.v1',
          jsonEncode(ids.toList()),
        );
      });
  Future<List<FoodItem>> frequentFoods() async {
    final meals = await _days.listMeals();
    final count = <String, int>{}, snapshots = <String, FoodItem>{};
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    for (final m in meals.where((m) => !m.date.isBefore(cutoff))) {
      for (final e in m.entries) {
        count[e.food.id] = (count[e.food.id] ?? 0) + 1;
        snapshots.putIfAbsent(e.food.id, () => e.food);
      }
    }
    final sorted = snapshots.values.toList()
      ..sort((a, b) {
        final diff = count[b.id]!.compareTo(count[a.id]!);
        return diff == 0 ? a.name.compareTo(b.name) : diff;
      });
    return sorted.take(30).toList();
  }

  Future<List<MealTemplate>> getTemplates() => _templates.getTemplates();

  Future<void> saveTemplate(MealTemplate template) async {
    await _templates.add(template);
  }

  Future<void> deleteTemplate(String id) async {
    await _templates.delete(id);
  }

  Future<LoggedMeal?> getLastLoggedMeal(MealType mealType) async {
    return _days.getLastLoggedMeal(mealType);
  }

  Future<void> logMeal(LoggedMeal meal) async {
    await _days.logMeal(meal);
  }

  void dispose() => _fdc.dispose();

  Iterable<FoodItem> _mergeFoods(
    List<FoodItem> local,
    Iterable<FoodItem> remote,
  ) {
    final merged = <String, FoodItem>{for (final item in local) item.id: item};
    for (final item in remote) {
      merged[item.id] = merged[item.id] ?? item;
    }
    return merged.values;
  }

  FoodItem _mapSearchItemToFood(FdcSearchItem item) {
    return FoodItem(
      id: 'fdc:${item.fdcId}',
      name: item.description,
      source: 'USDA FoodData Central',
      externalId: item.fdcId.toString(),
      originalName: item.description,
      brand: item.brandOwner,
      categoryLabel:
          '${item.dataType?.trim().isNotEmpty == true ? item.dataType!.trim() : 'Alimento'} · USDA',
      macrosPer100: MacroValues.unknown,
      detailsLoaded: false,
      defaultServingGrams: 100,
      unitSupport: FoodUnitSupport.gramsAndServing,
      searchKeywords: [
        item.description,
        if (item.dataType != null && item.dataType!.trim().isNotEmpty)
          item.dataType!,
        if (item.brandOwner != null && item.brandOwner!.trim().isNotEmpty)
          item.brandOwner!,
      ],
    );
  }

  FoodItem _mapDetailsToFood(Map<String, dynamic> details) {
    final fdcId = (details['fdcId'] as num?)?.toInt();
    if (fdcId == null || fdcId <= 0) {
      throw const FormatException('Identificador USDA no válido.');
    }
    final volume =
        (details['servingSizeUnit'] ?? '').toString().toLowerCase() == 'ml';
    final rawServing = details['servingSize'];
    final servingSize =
        rawServing is num && rawServing.isFinite && rawServing > 0
        ? rawServing.toDouble()
        : null;
    final portions = (details['foodPortions'] as List? ?? [])
        .whereType<Map>()
        .where(
          (p) =>
              p['gramWeight'] is num &&
              (p['gramWeight'] as num).isFinite &&
              (p['gramWeight'] as num) > 0,
        )
        .toList();
    final gramServing = volume
        ? null
        : portions.isNotEmpty
        ? (portions.first['gramWeight'] as num)
        : const ['g', 'grm'].contains(
            (details['servingSizeUnit'] ?? '').toString().toLowerCase(),
          )
        ? servingSize
        : null;
    final labels = details['labelNutrients'] as Map?;
    double? fromLabel(String key) {
      final raw = labels?[key];
      final amount = raw is Map ? raw['value'] : null;
      return servingSize == null ||
              amount is! num ||
              !amount.isFinite ||
              amount < 0
          ? null
          : amount / servingSize * 100;
    }

    final volumeBase = MacroValues(
      kcal: fromLabel('calories'),
      protein: fromLabel('protein'),
      carbs: fromLabel('carbohydrates'),
      fat: fromLabel('fat'),
    );
    return FoodItem(
      id: 'fdc:$fdcId',
      barcode: details['gtinUpc']?.toString(),
      name: (details['description'] ?? 'USDA food').toString(),
      categoryLabel: details['dataType']?.toString() ?? 'USDA',
      macrosPer100: volume
          ? MacroValues.unknown
          : macrosFromFdcDetails(details),
      macrosPer100ml: volume ? volumeBase : null,
      micronutrients: volume ? const {} : microsFromFdc(details),
      energyMethod: volume
          ? 'USDA · etiqueta por porción en ml'
          : energyMethodFromFdc(details),
      sourceDate: details['publicationDate']?.toString(),
      servingVerified: gramServing != null,
      servingLabel: details['householdServingFullText']?.toString(),
      source: 'USDA FoodData Central',
      externalId: fdcId.toString(),
      originalName: details['description']?.toString(),
      brand: details['brandOwner']?.toString(),
      defaultServingGrams: volume ? 0 : gramServing ?? 100,
      unitSupport: volume
          ? FoodUnitSupport.mlOnly
          : gramServing == null
          ? FoodUnitSupport.gramsOnly
          : FoodUnitSupport.gramsAndServing,
      searchKeywords: [
        (details['description'] ?? '').toString(),
        if ((details['dataType'] ?? '').toString().trim().isNotEmpty)
          details['dataType'].toString(),
        if ((details['brandOwner'] ?? '').toString().trim().isNotEmpty)
          details['brandOwner'].toString(),
      ],
    );
  }
}

const List<FoodItem> _seedFoods = [
  FoodItem(
    id: 'banana',
    name: 'Banana',
    categoryLabel: 'Fruta',
    macrosPer100: MacroValues(kcal: 89, protein: 1.1, carbs: 23, fat: 0.3),
    defaultServingGrams: 120,
    unitSupport: FoodUnitSupport.gramsAndServing,
    searchKeywords: [
      'banana',
      'fruta',
      'desayuno',
      'snack',
      'breakfast',
      'dinner',
    ],
  ),
  FoodItem(
    id: 'licuado_banana',
    name: 'Licuado de banana',
    categoryLabel: 'Bebida',
    macrosPer100: MacroValues(kcal: 60, protein: 2, carbs: 12, fat: 1),
    macrosPer100ml: MacroValues(kcal: 55, protein: 2.2, carbs: 11, fat: 1),
    defaultServingGrams: 250,
    unitSupport: FoodUnitSupport.mlAndServing,
    searchKeywords: ['banana', 'licuado', 'bebida', 'merienda', 'snack'],
  ),
  FoodItem(
    id: 'chips_banana',
    name: 'Chips de banana',
    categoryLabel: 'Snack',
    macrosPer100: MacroValues(kcal: 519, protein: 2.3, carbs: 58, fat: 33),
    defaultServingGrams: 30,
    unitSupport: FoodUnitSupport.gramsAndServing,
    searchKeywords: ['banana', 'chips', 'snack', 'dinner', 'lunch'],
  ),
  FoodItem(
    id: 'pollo',
    name: 'Pollo a la plancha',
    categoryLabel: 'Proteína',
    macrosPer100: MacroValues(kcal: 165, protein: 31, carbs: 0, fat: 4),
    defaultServingGrams: 150,
    unitSupport: FoodUnitSupport.gramsAndServing,
    searchKeywords: ['pollo', 'almuerzo', 'cena', 'lunch', 'dinner'],
  ),
];
