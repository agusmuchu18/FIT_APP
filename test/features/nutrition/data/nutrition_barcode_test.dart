import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:fit_app/features/nutrition/data/fdc_mapper.dart';
import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_repository.dart';

import '../../../support/nutrition_test_storage.dart';

void main() {
  test('a zero-filled code never identifies a product', () {
    expect(
      () => normalizeNutritionBarcode('0000000000000'),
      throwsFormatException,
    );
  });
  test(
    'a branded liquid uses the declared volume, not an assumed density',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/foods/search')) {
          return http.Response(
            jsonEncode({
              'foods': [
                {
                  'fdcId': 303,
                  'description': 'Liquid QA',
                  'dataType': 'Branded',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'fdcId': 303,
            'description': 'Liquid QA',
            'gtinUpc': '3017624010701',
            'servingSize': 250,
            'servingSizeUnit': 'ml',
            'labelNutrients': {
              'calories': {'value': 125},
              'protein': {'value': 5},
              'carbohydrates': {'value': 20},
            },
            'foodNutrients': [
              {
                'nutrient': {'number': '208', 'unitName': 'KCAL'},
                'amount': 999,
              },
            ],
          }),
          200,
        );
      });
      final foods = FoodRepository(
        fdc: FdcClient(apiKey: 'test-only-key', client: client),
      );
      addTearDown(foods.dispose);
      final liquid = (await foods.findByBarcode('3017624010701'))!;
      expect(liquid.macrosPer100.kcal, isNull);
      expect(liquid.macrosPer100ml!.kcal, 50);
      expect(liquid.supportsUnit(FoodUnit.grams), isFalse);
      expect(liquid.supportsUnit(FoodUnit.serving), isFalse);
      final e = DraftEntry(food: liquid, quantity: 125.5, unit: FoodUnit.ml);
      expect(e.computedMacros.kcal, closeTo(62.75, 0.000001));
      expect(e.computedMacros.fat, isNull);
    },
  );

  setUp(nutritionTestStorage);
  test('GTIN checksum and padding preserve identity', () {
    expect(normalizeNutritionBarcode('3017624010701'), '03017624010701');
    expect(normalizeNutritionBarcode('012345678905'), '00012345678905');
    expect(
      () => normalizeNutritionBarcode('3017624010702'),
      throwsFormatException,
    );
    expect(() => normalizeNutritionBarcode('abc'), throwsFormatException);
  });
  test(
    'a nutrient with conflicting units is unavailable, never mislabeled',
    () {
      expect(
        nutrientAmount({
          'foodNutrients': [
            {'nutrientNumber': '208', 'value': 150, 'unitName': 'kJ'},
          ],
        }, 208),
        isNull,
      );
      expect(
        nutrientAmount({
          'foodNutrients': [
            {'nutrientNumber': '203', 'value': 5, 'unitName': 'G'},
          ],
        }, 203),
        5,
      );
      expect(
        nutrientAmount({
          'foodNutrients': [
            {'nutrientNumber': '203', 'value': 500, 'unitName': 'MG'},
          ],
        }, 203),
        isNull,
      );
    },
  );
  test(
    'barcode lookup rejects wrong products and caches only the exact match',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/foods/search')) {
          return http.Response(
            jsonEncode({
              'foods': [
                {'fdcId': 101, 'description': 'Wrong', 'dataType': 'Branded'},
                {
                  'fdcId': 202,
                  'description': 'Matching',
                  'dataType': 'Branded',
                },
              ],
            }),
            200,
          );
        }
        final wrong = request.url.path.endsWith('/101');
        return http.Response(
          jsonEncode({
            'fdcId': wrong ? 101 : 202,
            'description': wrong ? 'Wrong' : 'Matching',
            'gtinUpc': wrong ? '012345678905' : '03017624010701',
            'foodNutrients': [
              {
                'nutrient': {'number': '208', 'unitName': 'KCAL'},
                'amount': 100,
              },
              {
                'nutrient': {'number': '203', 'unitName': 'G'},
                'amount': 0,
              },
            ],
          }),
          200,
        );
      });
      final foods = FoodRepository(
        fdc: FdcClient(apiKey: 'test-only-key', client: client),
      );
      addTearDown(foods.dispose);
      final match = await foods.findByBarcode('3017624010701');
      expect(match!.id, 'fdc:202');
      expect(match.macrosPer100.protein, 0);
      expect(match.macrosPer100.fat, isNull);
      expect(match.detailsLoaded, isTrue);
      expect(calls, 3);
      final offline = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(offline.dispose);
      expect((await offline.findByBarcode('3017624010701'))!.id, 'fdc:202');
      expect(calls, 3);
    },
  );
  test(
    'manual products can be found offline without remote credentials',
    () async {
      final foods = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(foods.dispose);
      await foods.createCustomFood(
        const FoodItem(
          id: 'own-gtin',
          name: 'Etiqueta QA',
          categoryLabel: 'Propio',
          macrosPer100: MacroValues.unknown,
          defaultServingGrams: 100,
          unitSupport: FoodUnitSupport.gramsAndServing,
          isCustom: true,
          barcode: '3017624010701',
        ),
      );
      expect((await foods.findByBarcode('3017624010701'))!.id, 'own-gtin');
      expect(await foods.findByBarcode('012345678905'), isNull);
    },
  );
}
