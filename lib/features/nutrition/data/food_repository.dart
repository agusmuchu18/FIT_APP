import '../domain/models.dart';
import 'fdc_client.dart';
import 'fdc_mapper.dart';
import 'food_cache.dart';

class FoodRepository {
  FoodRepository({required FdcClient fdc, FoodCache? cache})
      : _fdc = fdc,
        _cache = cache ?? FoodCache();

  final FdcClient _fdc;
  final FoodCache _cache;
  final List<FoodItem> _foods = [..._seedFoods];
  final List<MealTemplate> _templates = [];
  final List<LoggedMeal> _loggedMeals = [];

  bool get hasUsdaApiKey => _fdc.apiKey.trim().isNotEmpty;

  Future<List<FoodItem>> loadLocalCatalog() async => List.unmodifiable(_foods);
  Future<List<FoodItem>> syncWithPublicCatalog() async => loadLocalCatalog();

  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];

    final local = await searchLocalFoods(query);
    if (!hasUsdaApiKey) return local;

    final cached = _cache.getSearch(query);
    if (cached != null) {
      return _mergeFoods(local, cached.map(_mapSearchItemToFood)).toList();
    }

    final fdcResults = await _fdc.searchFoods(
      query,
      dataTypes: const ['Foundation', 'SR Legacy', 'Branded', 'Survey (FNDDS)'],
      pageSize: 60,
    );
    _cache.putSearch(query, fdcResults);

    return _mergeFoods(local, fdcResults.map(_mapSearchItemToFood)).toList();
  }

  Future<List<FoodItem>> searchLocalFoods(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return _foods.where((food) {
      return food.name.toLowerCase().contains(q) ||
          food.searchKeywords.any((keyword) => keyword.toLowerCase().contains(q));
    }).toList();
  }

  Future<FoodItem> getFoodItemFromFdc(int fdcId) async {
    final cached = _cache.getDetails(fdcId);
    if (cached != null) {
      return _mapDetailsToFood(cached);
    }

    final details = await _fdc.getFoodDetails(fdcId);
    _cache.putDetails(fdcId, details);
    return _mapDetailsToFood(details);
  }

  Future<List<FoodItem>> getSuggestedFoods(MealType mealType) async {
    final mealKeyword = mealType.name.toLowerCase();
    final prioritized = <FoodItem>[];
    final rest = <FoodItem>[];

    for (final food in _foods) {
      final matchesMeal = food.searchKeywords.any((keyword) => keyword.toLowerCase() == mealKeyword);
      if (matchesMeal) {
        prioritized.add(food);
      } else {
        rest.add(food);
      }
    }

    return [...prioritized, ...rest];
  }

  Future<void> createCustomFood(FoodItem item) async {
    _foods.insert(0, item);
  }

  Future<List<MealTemplate>> getTemplates() async => List.unmodifiable(_templates);

  Future<void> saveTemplate(MealTemplate template) async {
    _templates.removeWhere((t) => t.id == template.id);
    _templates.add(template);
  }

  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
  }

  Future<LoggedMeal?> getLastLoggedMeal(MealType mealType) async {
    for (final item in _loggedMeals.reversed) {
      if (item.mealType == mealType) return item;
    }
    return null;
  }

  Future<void> logMeal(LoggedMeal meal) async {
    _loggedMeals.add(meal);
  }

  void dispose() => _fdc.dispose();

  Iterable<FoodItem> _mergeFoods(List<FoodItem> local, Iterable<FoodItem> remote) {
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
      categoryLabel: item.dataType?.trim().isNotEmpty == true ? item.dataType!.trim() : 'USDA',
      macrosPer100: MacroValues.zero,
      defaultServingGrams: 100,
      unitSupport: FoodUnitSupport.gramsAndServing,
      searchKeywords: [
        item.description,
        if (item.dataType != null && item.dataType!.trim().isNotEmpty) item.dataType!,
        if (item.brandOwner != null && item.brandOwner!.trim().isNotEmpty) item.brandOwner!,
      ],
    );
  }

  FoodItem _mapDetailsToFood(Map<String, dynamic> details) {
    final fdcId = (details['fdcId'] as num?)?.toInt();
    return FoodItem(
      id: 'fdc:${fdcId ?? 0}',
      name: (details['description'] ?? 'USDA food').toString(),
      categoryLabel: details['dataType']?.toString() ?? 'USDA',
      macrosPer100: macrosFromFdcDetails(details),
      defaultServingGrams: 100,
      unitSupport: FoodUnitSupport.gramsAndServing,
      searchKeywords: [
        (details['description'] ?? '').toString(),
        if ((details['dataType'] ?? '').toString().trim().isNotEmpty) details['dataType'].toString(),
        if ((details['brandOwner'] ?? '').toString().trim().isNotEmpty) details['brandOwner'].toString(),
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
    searchKeywords: ['banana', 'fruta', 'desayuno', 'snack', 'breakfast', 'dinner'],
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
