import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/core/data/remote_sync_service.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/data/statistics_service.dart';
import 'package:fit_app/features/nutrition/data/nutrition_day_repository.dart';
import 'package:fit_app/features/nutrition/data/templates_repository.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';

import '../../../support/nutrition_test_storage.dart';

class _Offline implements RemoteSyncService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const food = FoodItem(
  id: 'qa-food',
  name: 'Ingrediente QA',
  categoryLabel: 'Prueba',
  macrosPer100: MacroValues(kcal: 200, protein: 10, carbs: 20, fat: 8),
  defaultServingGrams: 100,
  unitSupport: FoodUnitSupport.gramsAndServing,
);
const entry = DraftEntry(food: food, quantity: 200, unit: FoodUnit.grams);
MealTemplate recipe() => MealTemplate(
  id: 'recipe',
  name: 'Receta QA',
  entries: [entry],
  totals: entry.computedMacros,
  servings: 4,
  createdAt: DateTime(2026, 10, 1),
);
Future<FitnessRepository> fitness() async => FitnessRepository(
  local: await LocalStorageService.create(),
  remote: _Offline(),
  statistics: StatisticsService(),
);
void main() {
  test(
    'week copying keeps snapshots and is idempotent even after consumption',
    () async {
      final days = NutritionDayRepository();
      final start = DateTime(2026, 10, 1), target = DateTime(2026, 10, 8);
      await days.plan(
        PlannedNutritionMeal(
          id: 'week',
          date: start,
          mealType: MealType.lunch,
          template: recipe().portion(1),
        ),
      );
      await expectLater(
        days.copyPlanWeek(start, start.add(const Duration(days: 3))),
        throwsFormatException,
      );
      expect(await days.copyPlanWeek(start, target), 1);
      final copied = (await days.plans()).firstWhere((p) => p.date == target);
      expect(copied.template.effectiveTotals.kcal, 100);
      expect(await days.listMeals(), isEmpty);
      await days.consumePlan(copied.id);
      expect(await days.copyPlanWeek(start, target), 0);
      expect((await days.plans()).length, 2);
      expect((await days.listMeals()).length, 1);
    },
  );
  test(
    'moving a meal preserves its identity, totals and core projection',
    () async {
      final core = await fitness(), date = DateTime(2026, 10, 30);
      final days = NutritionDayRepository(fitness: core);
      await days.logMeal(
        LoggedMeal(
          id: 'move',
          date: date,
          mealType: MealType.lunch,
          entries: [entry],
        ),
      );
      await days.editMeal(
        'move',
        title: 'Movida',
        entries: [entry],
        mealType: MealType.dinner,
      );
      final meal = (await days.listMeals()).single;
      expect(meal.id, 'move');
      expect(meal.mealType, MealType.dinner);
      expect(meal.totals.kcal, 400);
      expect((await core.getMeals()).single.id, 'move');
      expect((await core.getDailyNutritionStats(date))!.totalCalories, 400);
    },
  );
  test(
    'same-day goal correction retains the prior revision and exports it',
    () async {
      final days = NutritionDayRepository(), date = DateTime(2026, 10, 30);
      const first = MacroValues(
            kcal: 2000,
            protein: null,
            carbs: null,
            fat: null,
          ),
          revised = MacroValues(
            kcal: 2200,
            protein: 120,
            carbs: null,
            fat: null,
          );
      await days.saveGoal(date, first);
      await days.saveGoal(date, revised);
      await days.saveGoal(date, revised);
      expect((await days.goalHistory()).length, 2);
      expect((await days.getSummary(date)).goal.kcal, 2200);
      final packet = Map<String, dynamic>.from(
        jsonDecode(await days.exportJournal()) as Map,
      );
      expect(packet['goalRevisions'], hasLength(1));
      AccountStorageScope.current = 'goal-target';
      final target = NutritionDayRepository();
      expect(await target.importMetadata(packet), 2);
      expect((await target.goalHistory()).length, 2);
      expect((await target.getSummary(date)).goal.kcal, 2200);
    },
  );

  setUp(nutritionTestStorage);
  test('recipe portions scale ingredients and preserve unknowns without a cooking factor', () {
    final portion = recipe().portion(0.5);
    expect(portion.entries.single.quantity, 25);
    expect(portion.effectiveTotals.kcal, 50);
    expect(portion.cookedWeightGrams, isNull);
    final saved = MealTemplate.fromJson(recipe().toJson());
    expect(saved.servings, 4);
    expect(saved.portion(1).effectiveTotals.kcal, 100);
  });
  test(
    'planning is separate from consumption and confirmation is idempotent',
    () async {
      final repo = NutritionDayRepository();
      final date = DateTime(2026, 10, 30);
      await repo.plan(
        PlannedNutritionMeal(
          id: 'p',
          date: date,
          mealType: MealType.lunch,
          template: recipe().portion(1),
        ),
      );
      expect((await repo.getSummary(date)).consumed.kcal, 0);
      await Future.wait([repo.consumePlan('p'), repo.consumePlan('p')]);
      expect((await repo.listMeals()).length, 1);
      expect((await repo.getSummary(date)).consumed.kcal, 100);
      expect((await repo.plans()).single.consumed, isTrue);
    },
  );
  test(
    'planned composition survives editing and removing its original recipe',
    () async {
      final recipes = TemplatesRepository(), days = NutritionDayRepository();
      final original = recipe();
      await recipes.add(original);
      await days.plan(
        PlannedNutritionMeal(
          id: 'snapshot',
          date: DateTime.now(),
          mealType: MealType.dinner,
          template: original.portion(1),
        ),
      );
      await recipes.update(
        original.copyWith(
          name: 'Otro nombre',
          totals: const MacroValues(kcal: 999, protein: 0, carbs: 0, fat: 0),
        ),
      );
      await recipes.delete(original.id);
      await days.consumePlan('snapshot');
      expect((await days.listMeals()).single.totals.kcal, 100);
    },
  );
  test('shopping sums mass equivalences and excludes consumed plans', () async {
    final days = NutritionDayRepository();
    await days.plan(
      PlannedNutritionMeal(
        id: 'one',
        date: DateTime.now(),
        mealType: MealType.lunch,
        template: recipe().portion(1),
      ),
    );
    await days.plan(
      PlannedNutritionMeal(
        id: 'two',
        date: DateTime.now(),
        mealType: MealType.dinner,
        template: recipe().portion(2),
      ),
    );
    expect((await days.shoppingList()).values.single, 150);
    await days.consumePlan('one');
    expect((await days.shoppingList()).values.single, 100);
  });
  test('dated goals preserve earlier targets and incomplete goals', () async {
    final days = NutritionDayRepository();
    await days.saveGoal(
      DateTime(2026, 10, 1),
      const MacroValues(kcal: 2000, protein: 100, carbs: null, fat: null),
    );
    await days.saveGoal(
      DateTime(2026, 10, 20),
      const MacroValues(kcal: 2200, protein: 120, carbs: 200, fat: 70),
    );
    expect((await days.getSummary(DateTime(2026, 10, 15))).goal.kcal, 2000);
    expect((await days.getSummary(DateTime(2026, 10, 15))).goal.carbs, isNull);
    expect((await days.getSummary(DateTime(2026, 10, 25))).goal.kcal, 2200);
    expect((await days.goalHistory()).length, 2);
  });
  test(
    'edit, delete, reopen and undo preserve IDs and match core totals',
    () async {
      final core = await fitness(), days = NutritionDayRepository();
      final projected = NutritionDayRepository(fitness: core);
      final date = DateTime.now();
      await projected.logMeal(
        LoggedMeal(
          id: 'stable',
          date: date,
          mealType: MealType.lunch,
          entries: [entry],
        ),
      );
      await projected.editMeal(
        'stable',
        title: 'Corregida',
        entries: [entry.copyWith(quantity: 100)],
      );
      expect((await core.getMeals()).single.calories, 200);
      expect((await projected.listMeals()).single.id, 'stable');
      await projected.deleteMeal('stable');
      expect(await core.getMeals(), isEmpty);
      expect(await projected.listMeals(), isEmpty);
      await Hive.close();
      final restoredCore = await fitness();
      final reopened = NutritionDayRepository(fitness: restoredCore);
      await reopened.recover();
      expect(await reopened.listMeals(), isEmpty);
      await reopened.restoreMeal('stable');
      expect((await reopened.listMeals()).single.totals.kcal, 200);
      expect((await restoredCore.getMeals()).single.id, 'stable');
      expect((await days.listMeals()).single.title, 'Corregida');
    },
  );
  test('notes and professional mode are private, scoped and durable', () async {
    final days = NutritionDayRepository(), date = DateTime.now();
    await days.saveDailyNote(date, note: 'QA note', supplements: 'Declarado');
    await days.setProfessionalMode(true);
    await Hive.close();
    expect((await NutritionDayRepository().dailyNote(date))['note'], 'QA note');
    expect(await NutritionDayRepository().professionalMode(), isTrue);
    AccountStorageScope.current = 'other-user';
    expect(await NutritionDayRepository().dailyNote(date), isEmpty);
    expect(await NutritionDayRepository().professionalMode(), isFalse);
  });
  test(
    'journal import previews duplicates and never overwrites conflicting IDs',
    () async {
      final a = NutritionDayRepository();
      await a.logMeal(
        LoggedMeal(
          id: 'a',
          date: DateTime.now(),
          mealType: MealType.lunch,
          entries: [entry],
        ),
      );
      final exported = await a.exportJournal();
      AccountStorageScope.current = 'import-target';
      final target = NutritionDayRepository();
      expect((await target.inspectImport(exported)).added, 1);
      expect(await target.importJournal(exported), 1);
      expect(await target.importJournal(exported), 0);
      final packet = jsonDecode(exported) as Map<String, dynamic>;
      (packet['rows'] as List).first['title'] = 'Changed';
      final conflict = jsonEncode(packet);
      expect((await target.inspectImport(conflict)).conflicts, 1);
      await expectLater(target.importJournal(conflict), throwsStateError);
      expect((await target.listMeals()).single.title, isNot('Changed'));
    },
  );
  test('a corrupt later import row prevents the first write', () async {
    final days = NutritionDayRepository();
    await days.logMeal(
      LoggedMeal(
        id: 'source',
        date: DateTime.now(),
        mealType: MealType.snack,
        entries: [entry],
      ),
    );
    final packet =
        jsonDecode(await days.exportJournal()) as Map<String, dynamic>;
    packet['rows'] = [
      ...(packet['rows'] as List),
      {'schemaVersion': 3, 'id': 'broken'},
    ];
    AccountStorageScope.current = 'clean';
    final target = NutritionDayRepository();
    await expectLater(
      target.importJournal(jsonEncode(packet)),
      throwsA(anything),
    );
    expect(await target.listMeals(), isEmpty);
  });
}
