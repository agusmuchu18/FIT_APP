import '../domain/models.dart';

class FoodRepository {
  final List<FoodItem> _foods = [..._seedFoods];
  final List<MealTemplate> _templates = [];
  final List<LoggedMeal> _loggedMeals = [];

  Future<List<FoodItem>> loadLocalCatalog() async => List.unmodifiable(_foods);
  Future<List<FoodItem>> syncWithPublicCatalog() async => loadLocalCatalog();

  Future<List<FoodItem>> searchFoods(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    return _foods.where((food) {
      return food.name.toLowerCase().contains(q) ||
          food.searchKeywords.any((keyword) => keyword.toLowerCase().contains(q));
    }).toList();
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
