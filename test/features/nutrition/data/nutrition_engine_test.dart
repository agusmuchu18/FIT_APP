import 'package:flutter_test/flutter_test.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:fit_app/features/nutrition/data/fdc_mapper.dart';
import 'package:fit_app/features/nutrition/data/nutrition_day_repository.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/core/data/statistics_service.dart';
import 'package:fit_app/core/data/remote_sync_service.dart';
import 'package:fit_app/core/domain/entities.dart' as core;

import '../../../support/nutrition_test_storage.dart';

class _OfflineRemote implements RemoteSyncService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const partialFood = FoodItem(
  id: 'test:partial',
  name: 'Producto de prueba',
  categoryLabel: 'Prueba',
  macrosPer100: MacroValues(kcal: 100, protein: null, carbs: 0, fat: 2),
  defaultServingGrams: 25,
  unitSupport: FoodUnitSupport.gramsAndServing,
  source: 'user',
  servingVerified: true,
);
void main() {
  test(
    'unresolved remote search results cannot be saved as confirmed intake',
    () async {
      final unresolved = FoodItem.fromJson({
        ...partialFood.toJson(),
        'detailsLoaded': false,
      });
      final days = NutritionDayRepository();
      await expectLater(
        days.logMeal(
          LoggedMeal(
            id: 'unresolved',
            date: DateTime.now(),
            mealType: MealType.lunch,
            entries: [
              DraftEntry(food: unresolved, quantity: 100, unit: FoodUnit.grams),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(await days.listMeals(), isEmpty);
    },
  );

  setUp(nutritionTestStorage);
  test('USDA missing, invalid and genuine zero remain distinct', () {
    expect(nutrientAmount({}, 203), isNull);
    expect(
      nutrientAmount({
        'foodNutrients': [
          {'nutrientNumber': '203', 'value': -1},
        ],
      }, 203),
      isNull,
    );
    expect(
      nutrientAmount({
        'foodNutrients': [
          {
            'nutrient': {'number': '203'},
            'amount': 0,
          },
        ],
      }, 203),
      0,
    );
    expect(macrosFromFdcDetails({}).isComplete, isFalse);
  });
  test('partial sums and JSON never turn unknown into zero', () {
    final result = MacroValues.zero + partialFood.macrosPer100;
    expect(result.protein, isNull);
    expect(result.carbs, 0);
    expect(MacroValues.fromJson(result.toJson()).protein, isNull);
    expect(MacroValues.display(result.protein), '—');
  });
  test('fractional servings preserve their mass and nutrient basis', () {
    const e = DraftEntry(
      food: partialFood,
      quantity: 0.5,
      unit: FoodUnit.serving,
    );
    expect(e.effectiveGrams, 12.5);
    expect(e.computedMacros.kcal, 12.5);
    expect(e.computedMacros.protein, isNull);
    expect(DraftEntry.fromJson(e.toJson()).quantity, 0.5);
  });
  test('milliliters require an actual milliliter basis', () {
    expect(partialFood.supportsUnit(FoodUnit.ml), isFalse);
    expect(
      const DraftEntry(
        food: partialFood,
        quantity: 200,
        unit: FoodUnit.ml,
      ).computedMacros.kcal,
      isNull,
    );
  });
  test('partial snapshots survive storage, projection and Analytics', () async {
    final fitness = FitnessRepository(
      local: await LocalStorageService.create(),
      remote: _OfflineRemote(),
      statistics: StatisticsService(),
    );
    final days = NutritionDayRepository(fitness: fitness);
    await days.logMeal(
      LoggedMeal(
        date: DateTime.now(),
        mealType: MealType.lunch,
        entries: [
          const DraftEntry(
            food: partialFood,
            quantity: 125.5,
            unit: FoodUnit.grams,
          ),
        ],
      ),
    );
    expect((await days.getTodaySummary()).consumed.protein, isNull);
    final projected = (await fitness.getMeals()).single;
    expect(projected.unknownNutrients, {'protein'});
    expect(core.MealEntry.fromJson(projected.toJson()).unknownNutrients, {
      'protein',
    });
    expect(
      (await fitness.getDailyNutritionStats(DateTime.now()))!.unknownNutrients,
      {'protein'},
    );
    expect(
      (await days.listMeals()).single.totals.kcal,
      closeTo(125.5, 0.00001),
    );
    expect(days.projectionPending, isFalse);
  });
  test('food source, fractional equivalence and micros persist', () {
    final source = FoodItem.fromJson({
      ...partialFood.toJson(),
      'micronutrients': {'sodium_mg': null, 'fiber_g': 0},
      'defaultServingGrams': 25.5,
    });
    expect(source.source, 'user');
    expect(source.servingVerified, isTrue);
    expect(source.defaultServingGrams, 25.5);
    expect(source.micronutrients['sodium_mg'], isNull);
    expect(source.micronutrients['fiber_g'], 0);
  });
}
