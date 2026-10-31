import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_repository.dart';
import 'package:fit_app/features/nutrition/data/nutrition_backup_service.dart';
import 'package:fit_app/features/nutrition/data/nutrition_day_repository.dart';
import 'package:fit_app/features/nutrition/data/templates_repository.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';

import '../../../support/nutrition_test_storage.dart';

const custom = FoodItem(
  id: 'personal-food',
  name: 'Alimento QA',
  categoryLabel: 'Propio',
  macrosPer100: MacroValues(kcal: 100, protein: 5, carbs: null, fat: 2),
  defaultServingGrams: 50,
  unitSupport: FoodUnitSupport.gramsAndServing,
  isCustom: true,
  source: 'user',
);
NutritionBackupService backup() {
  final foods = FoodRepository(fdc: FdcClient(apiKey: ''));
  addTearDown(foods.dispose);
  return NutritionBackupService(
    days: NutritionDayRepository(),
    foods: foods,
    templates: TemplatesRepository(),
  );
}

Future<String> packet() async {
  final source = backup();
  await source.foods.createCustomFood(custom);
  await source.foods.toggleFavoriteFood(custom.id);
  final recipe = MealTemplate(
    id: 'r',
    name: 'Receta QA',
    entries: [
      const DraftEntry(food: custom, quantity: 0.5, unit: FoodUnit.serving),
    ],
    totals: const MacroValues(kcal: 25, protein: 1.25, carbs: null, fat: 0.5),
    createdAt: DateTime(2026, 10, 1),
  );
  await source.templates.add(recipe);
  await source.days.logMeal(
    LoggedMeal(
      id: 'meal',
      date: DateTime(2026, 10, 30),
      mealType: MealType.lunch,
      entries: recipe.entries,
    ),
  );
  await source.days.saveGoal(
    DateTime(2026, 10, 1),
    const MacroValues(kcal: 2000, protein: 100, carbs: null, fat: null),
  );
  await source.days.plan(
    PlannedNutritionMeal(
      id: 'plan',
      date: DateTime(2026, 10, 31),
      mealType: MealType.dinner,
      template: recipe,
    ),
  );
  await source.days.saveDailyNote(
    DateTime(2026, 10, 30),
    note: 'QA privado',
    supplements: 'Declarado',
  );
  return source.exportData();
}

void main() {
  setUp(nutritionTestStorage);
  test('complete backup restores owned data without overwriting or duplicate intake', () async {
    final text = await packet();
    AccountStorageScope.current = 'target';
    final target = backup();
    final preview = await target.inspect(text);
    expect(preview.conflicts, 0);
    expect(preview.added, greaterThan(0));
    await target.importData(text);
    expect((await target.days.listMeals()).single.totals.carbs, isNull);
    expect((await target.templates.getTemplates()).single.name, 'Receta QA');
    expect(
      (await target.foods.loadLocalCatalog())
          .where((f) => f.isCustom)
          .single
          .id,
      custom.id,
    );
    expect(await target.foods.favoriteFoodIds(), {custom.id});
    expect((await target.days.plans()).single.consumed, isFalse);
    expect(
      (await target.days.dailyNote(DateTime(2026, 10, 30)))['note'],
      'QA privado',
    );
    expect(
      (await target.days.getSummary(DateTime(2026, 10, 30))).goal.kcal,
      2000,
    );
    expect((await target.inspect(text)).added, 0);
    expect(await target.importData(text), 0);
    expect((await target.days.listMeals()).length, 1);
  });
  test(
    'conflicting food prevents all new backup records from being written',
    () async {
      final text = await packet();
      AccountStorageScope.current = 'target';
      final target = backup();
      await target.foods.createCustomFood(
        FoodItem.fromJson({...custom.toJson(), 'name': 'Original del destino'}),
      );
      expect((await target.inspect(text)).conflicts, 1);
      await expectLater(target.importData(text), throwsStateError);
      expect(await target.days.listMeals(), isEmpty);
      expect(await target.templates.getTemplates(), isEmpty);
    },
  );
  test(
    'malformed future version and later metadata are rejected before writes',
    () async {
      final raw = jsonDecode(await packet()) as Map<String, dynamic>;
      AccountStorageScope.current = 'target';
      final target = backup();
      raw['version'] = 99;
      await expectLater(
        target.importData(jsonEncode(raw)),
        throwsFormatException,
      );
      raw['version'] = 1;
      (raw['journal'] as Map)['notes'] = [
        {'date': 'not-a-date', 'note': 'x', 'supplements': ''},
      ];
      await expectLater(target.importData(jsonEncode(raw)), throwsA(anything));
      expect(
        (await target.foods.loadLocalCatalog()).where((f) => f.isCustom),
        isEmpty,
      );
    },
  );
  test('backup coordinator rejects cross-account dependencies', () {
    final foods = FoodRepository(
      fdc: FdcClient(apiKey: ''),
      scope: 'another',
    );
    addTearDown(foods.dispose);
    expect(
      () => NutritionBackupService(
        days: NutritionDayRepository(scope: 'one'),
        foods: foods,
        templates: TemplatesRepository(scope: 'one'),
      ),
      throwsArgumentError,
    );
  });
  test('fasting is disabled by default, durable and does not duplicate active windows', () async {
    final days = NutritionDayRepository();
    expect(await days.fastingEnabled(), isFalse);
    await expectLater(days.startFast(), throwsStateError);
    await days.setFastingEnabled(true);
    final start = DateTime.utc(2026, 10, 30, 7);
    await Future.wait([days.startFast(now: start), days.startFast(now: start)]);
    await Hive.close();
    final reopened = NutritionDayRepository();
    expect((await reopened.fastingHistory()).length, 1);
    await expectLater(
      reopened.finishFast(now: start.subtract(const Duration(minutes: 1))),
      throwsFormatException,
    );
    await reopened.finishFast(now: start.add(const Duration(hours: 12)));
    expect(
      DateTime.parse((await reopened.fastingHistory()).single['end'] as String)
          .difference(start)
          .inHours,
      12,
    );
  });
  test(
    'structured text uses explicit amounts and never invents a food',
    () async {
      final foods = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(foods.dispose);
      await foods.createCustomFood(custom);
      final result = await foods.parseStructuredText(
        '0,5 porciones Alimento QA\n0.125 kg Alimento QA\n100 g noexisteestealimento',
      );
      expect(result[0].quantity, 0.5);
      expect(result[1].quantity, 125);
      expect(result[2].matches, isEmpty);
      await expectLater(
        foods.parseStructuredText('Una comida normal'),
        throwsFormatException,
      );
      await expectLater(
        foods.parseStructuredText('0 g arroz'),
        throwsFormatException,
      );
    },
  );
}
