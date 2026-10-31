import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_repository.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/nutrition_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const customFood = FoodItem(
    id: 'custom-yogurt',
    name: 'Yogur casero',
    categoryLabel: 'Lácteos',
    macrosPer100: MacroValues(kcal: 72, protein: 4, carbs: 6, fat: 3),
    defaultServingGrams: 180,
    unitSupport: FoodUnitSupport.gramsAndServing,
    searchKeywords: ['yogur', 'casero'],
    isCustom: true,
  );

  setUp(nutritionTestStorage);

  test('custom foods survive repository recreation', () async {
    final first = FoodRepository(fdc: FdcClient(apiKey: ''));
    await first.createCustomFood(customFood);
    first.dispose();

    final reopened = FoodRepository(fdc: FdcClient(apiKey: ''));
    final results = await reopened.searchLocalFoods('yogur');
    expect(results.any((food) => food.id == customFood.id), isTrue);
    expect(
      results.firstWhere((food) => food.id == customFood.id).toJson(),
      customFood.toJson(),
    );
    reopened.dispose();
  });

  test('logged meal survives recreation and can be copied', () async {
    final first = FoodRepository(fdc: FdcClient(apiKey: ''));
    await first.logMeal(
      LoggedMeal(
        date: DateTime(2026, 9, 10, 20),
        mealType: MealType.dinner,
        entries: const [
          DraftEntry(food: customFood, quantity: 2, unit: FoodUnit.serving),
        ],
      ),
    );
    first.dispose();

    final reopened = FoodRepository(fdc: FdcClient(apiKey: ''));
    final meal = await reopened.getLastLoggedMeal(MealType.dinner);
    expect(meal, isNotNull);
    expect(meal!.entries.single.food.name, 'Yogur casero');
    expect(meal.entries.single.quantity, 2);
    reopened.dispose();
  });
}
