import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_repository.dart';
import 'package:fit_app/features/nutrition/data/offline_food_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'reported energy and missing nutrients retain official provenance',
    () async {
      final foods = await OfflineFoodCatalog.load();
      final melon = foods.firstWhere((f) => f.id == 'fdc:2747675');
      expect(melon.macrosPer100.kcal, isNull);
      expect(melon.macrosPer100.protein, closeTo(0.871, 0.000001));
      expect(foods.where((f) => f.macrosPer100.kcal == null), hasLength(50));
      final specific = foods.firstWhere((f) => f.id == 'fdc:1750339');
      expect(specific.macrosPer100.kcal, 55.6);
      expect(specific.energyMethod, contains('específico'));
      final negative = foods.firstWhere((f) => f.id == 'fdc:2727566');
      expect(negative.macrosPer100.carbs, isNull);
      expect(negative.dataNotes, isNotEmpty);
      expect(negative.sourceDate, isNotEmpty);
    },
  );
  test(
    'a published fractional gram weight is not rounded or clamped',
    () async {
      final foods = await OfflineFoodCatalog.load();
      final hummus = foods.firstWhere((f) => f.id == 'fdc:321358');
      expect(hummus.defaultServingGrams, 33.9);
      expect(hummus.macrosPer100.kcal, 229);
      expect(hummus.servingVerified, isTrue);
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bundles the complete USDA Foundation release', () async {
    final foods = await OfflineFoodCatalog.load();
    expect(foods, hasLength(424));
    expect(foods.every((food) => food.id.startsWith('fdc:')), isTrue);
    expect(
      foods.where((food) => (food.macrosPer100.kcal ?? 0) > 0).length,
      greaterThan(350),
    );
  });

  test('Spanish aliases find official offline foods', () async {
    final repository = FoodRepository(fdc: FdcClient(apiKey: ''));
    final chicken = await repository.searchLocalFoods('pollo');
    final apple = await repository.searchLocalFoods('manzana');
    expect(
      chicken.any((food) => food.name.toLowerCase().contains('chicken')),
      isTrue,
    );
    expect(
      apple.any((food) => food.name.toLowerCase().contains('apple')),
      isTrue,
    );
    repository.dispose();
  });
}
