import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/core/data/remote_sync_service.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/data/statistics_service.dart';
import 'package:fit_app/core/domain/entities.dart' as core;
import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_repository.dart';
import 'package:fit_app/features/nutrition/data/nutrition_day_repository.dart';
import 'package:fit_app/features/nutrition/data/templates_repository.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:fit_app/features/nutrition/application/food_log_controller.dart';

import '../../../support/nutrition_test_storage.dart';

class ProjectionFixture implements FitnessRepository {
  final meals = <String, core.MealEntry>{};
  bool fail = false;
  core.UserPreferences? preferences;
  @override
  final mealsRevision = ValueNotifier(0);
  @override
  Future<void> saveMeal(core.MealEntry m, {bool sync = false}) async {
    if (fail) throw StateError('test-only projection failure');
    meals[m.id] = m;
    mealsRevision.value++;
  }

  @override
  Future<List<core.MealEntry>> getMealProjections() async =>
      meals.values.toList();
  @override
  Future<List<core.MealEntry>> getMeals() async => meals.values.toList();
  @override
  Future<core.UserPreferences?> getPreferences() async => preferences;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class UnusedRemote implements RemoteSyncService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class UncertainAcknowledgement extends FoodRepository {
  UncertainAcknowledgement() : super(fdc: FdcClient(apiKey: ''));
  bool first = true;
  @override
  Future<void> logMeal(LoggedMeal m) async {
    await super.logMeal(m);
    if (first) {
      first = false;
      throw StateError('test-only lost acknowledgement');
    }
  }
}

const food = FoodItem(
  id: 'test-yogurt',
  name: 'Yogur de prueba',
  categoryLabel: 'Propio',
  macrosPer100: MacroValues(kcal: 72, protein: 4, carbs: 6, fat: 3),
  defaultServingGrams: 180,
  unitSupport: FoodUnitSupport.gramsAndServing,
  isCustom: true,
);
LoggedMeal sample({String? id, DateTime? date}) => LoggedMeal(
  id: id,
  date: date ?? DateTime.now(),
  mealType: MealType.breakfast,
  entries: [const DraftEntry(food: food, quantity: 150, unit: FoodUnit.grams)],
);
void main() {
  setUp(nutritionTestStorage);
  test(
    'fractional nutrients survive projection and are rounded after aggregation',
    () async {
      final coreRepo = FitnessRepository(
        local: await LocalStorageService.create(),
        remote: UnusedRemote(),
        statistics: StatisticsService(),
      );
      final r = NutritionDayRepository(fitness: coreRepo);
      await r.logMeal(sample(id: 'fraction-1'));
      await r.logMeal(sample(id: 'fraction-2'));
      final projected = (await coreRepo.getMeals()).first;
      expect(projected.fatGrams, 4.5);
      expect(core.MealEntry.fromJson(projected.toJson()).fatGrams, 4.5);
      expect(projected.copyWith(title: 'Rename').fatGrams, 4.5);
      expect(
        projected
            .copyWith(macros: const core.Macros(carbs: 1, protein: 2, fat: 3))
            .fatGrams,
        3,
      );
      expect((await r.getTodaySummary()).consumed.fat, 9);
      expect((await coreRepo.getWeeklyNutritionStats()).single.macros.fat, 9);
      expect((await coreRepo.getMacroDistribution()).fat, 9);
    },
  );
  test(
    'retry after uncertain acknowledgement reuses operation ID and timestamp',
    () async {
      final r = UncertainAcknowledgement();
      addTearDown(r.dispose);
      final c = FoodLogController(repository: r);
      addTearDown(c.dispose);
      await c.refreshSuggestions();
      c.addOrUpdateDraft(
        const DraftEntry(food: food, quantity: 150, unit: FoodUnit.grams),
      );
      await expectLater(c.registerCurrentDraft(), throwsStateError);
      expect(c.currentDraft.entries, isNotEmpty);
      await c.registerCurrentDraft();
      expect(c.currentDraft.entries, isEmpty);
      expect((await NutritionDayRepository().listMeals()).length, 1);
    },
  );
  test('a future journal version is preserved and never downgraded', () async {
    final box = await Hive.openBox<String>(NutritionDayRepository.boxName);
    await box.put('__legacy_v1_complete', '3');
    await expectLater(
      NutritionDayRepository().listMeals(),
      throwsFormatException,
    );
    expect(box.get('__legacy_v1_complete'), '3');
  });
  test('a projection ID conflict preserves both original payloads', () async {
    final p = ProjectionFixture();
    addTearDown(p.mealsRevision.dispose);
    p.meals['conflict'] = core.MealEntry(
      id: 'conflict',
      title: 'Original',
      calories: 50,
      macros: const core.Macros(carbs: 5, protein: 2, fat: 1),
    );
    final r = NutritionDayRepository(fitness: p);
    await r.logMeal(sample(id: 'conflict'));
    expect(r.projectionPending, true);
    expect(p.meals['conflict']!.calories, 50);
    expect((await r.listMeals()).single.totals.kcal, 108);
  });
  test(
    'projection detects decimal conflicts hidden by legacy rounding',
    () async {
      final p = ProjectionFixture();
      addTearDown(p.mealsRevision.dispose);
      final original = sample(id: 'fractional-conflict');
      p.meals[original.id] = core.MealEntry(
        id: original.id,
        title: mealTypeLabel(original.mealType),
        consumedAt: original.date,
        calories: original.totals.kcal!.round(),
        macros: original.totals.toCoreMacros(),
        nutritionSnapshot: {
          ...original.totals.toJson().cast<String, num>(),
          'fat': 4.6,
        },
      );
      final r = NutritionDayRepository(fitness: p);
      await r.logMeal(original);
      expect(r.projectionPending, true);
      expect(p.meals[original.id]!.fatGrams, 4.6);
      expect((await r.listMeals()).single.totals.fat, 4.5);
      expect(r.projectionPending, true);
    },
  );
  test(
    'disk reopen preserves ID, quantity, date and exact nutrient snapshot',
    () async {
      final m = sample(id: 'stable-id', date: DateTime(2026, 9, 12, 8, 15));
      await NutritionDayRepository().logMeal(m);
      await Hive.close();
      final reopened = (await NutritionDayRepository().listMeals()).single;
      expect(reopened.id, m.id);
      expect(reopened.date, m.date);
      expect(reopened.entries.single.toJson(), m.entries.single.toJson());
      expect(reopened.totals.toJson(), m.totals.toJson());
    },
  );
  test('repeating preserves all macros and creates a distinct ID', () async {
    final r = NutritionDayRepository();
    await r.logMeal(sample());
    await r.duplicateRecent((await r.getRecents()).single);
    final rows = await r.listMeals();
    expect(rows.length, 2);
    expect(rows.map((m) => m.id).toSet().length, 2);
    expect(rows[0].totals.toJson(), rows[1].totals.toJson());
    expect(rows[0].totals.protein, 6);
    expect(rows[0].totals.carbs, 9);
    expect(rows[0].totals.fat, 4.5);
  });
  test(
    'template repetition uses original snapshot after template changes',
    () async {
      final r = NutritionDayRepository(), templates = TemplatesRepository();
      final t = MealTemplate(
        id: 't',
        name: 'Desayuno',
        entries: [
          const DraftEntry(food: food, quantity: 100, unit: FoodUnit.grams),
        ],
        createdAt: DateTime.now(),
      );
      await templates.add(t);
      await r.addTemplateToToday(t);
      await templates.update(
        t.copyWith(
          totals: const MacroValues(
            kcal: 900,
            protein: 20,
            carbs: 100,
            fat: 40,
          ),
        ),
      );
      await r.duplicateRecent((await r.getRecents()).single);
      expect((await r.listMeals()).map((m) => m.totals.kcal), everyElement(72));
    },
  );
  test(
    'legacy migration is repeatable and retains original preference bytes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode({
        '2026-09-12': [
          {
            'createdAt': '2026-09-12T08:00:00',
            'mealType': 'breakfast',
            'macros': {'kcal': 108, 'protein': 6, 'carbs': 9, 'fat': 4.5},
            'entries': [
              const DraftEntry(
                food: food,
                quantity: 150,
                unit: FoodUnit.grams,
              ).toJson(),
            ],
          },
        ],
      });
      await prefs.setString(NutritionDayRepository.legacyDayKey, raw);
      final r = NutritionDayRepository();
      expect((await r.listMeals()).single.id, 'nutrition-v1-2026-09-12-0');
      await Hive.close();
      expect((await NutritionDayRepository().listMeals()).length, 1);
      expect(prefs.getString(NutritionDayRepository.legacyDayKey), raw);
    },
  );
  test('incomplete legacy nutrients block migration without deleting original', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw =
        '{"2026-09-12":[{"createdAt":"2026-09-12T08:00:00","mealType":"breakfast","macros":{"kcal":100}}]}';
    await prefs.setString(NutritionDayRepository.legacyDayKey, raw);
    await expectLater(
      NutritionDayRepository().listMeals(),
      throwsFormatException,
    );
    expect(prefs.getString(NutritionDayRepository.legacyDayKey), raw);
    expect(
      Hive.box<String>(NutritionDayRepository.boxName)
          .containsKey('__legacy_v1_complete'),
      false,
    );
  });
  test(
    'calorie-only legacy recent never duplicates with invented zero macros',
    () async {
      final r = NutritionDayRepository();
      await expectLater(
        r.duplicateRecent(
          RecentNutritionItem(
            id: 'missing',
            title: 'Antigua',
            mealType: MealType.lunch,
            kcal: 200,
            at: DateTime.now(),
          ),
        ),
        throwsStateError,
      );
      expect(await r.listMeals(), isEmpty);
    },
  );
  test(
    'same operation ID is idempotent; conflicting payload is rejected',
    () async {
      final r = NutritionDayRepository(), m = sample(id: 'once');
      await r.logMeal(m);
      await r.logMeal(m);
      await expectLater(
        r.logMeal(
          LoggedMeal(
            id: 'once',
            date: m.date,
            mealType: m.mealType,
            entries: [],
            snapshot: const MacroValues(
              kcal: 999,
              protein: 1,
              carbs: 2,
              fat: 3,
            ),
          ),
        ),
        throwsStateError,
      );
      expect((await r.listMeals()).single.totals.kcal, 108);
    },
  );
  test(
    'concurrent repository instances preserve every journal entry',
    () async {
      await Future.wait([
        for (var i = 0; i < 12; i++)
          NutritionDayRepository().logMeal(sample(id: 'entry-$i')),
      ]);
      expect((await NutritionDayRepository().listMeals()).length, 12);
    },
  );
  test('guest, account A and account B have separate journals including late writes', () async {
    final guest = NutritionDayRepository();
    await guest.logMeal(sample(id: 'guest'));
    AccountStorageScope.current = 'alice';
    final a = NutritionDayRepository();
    AccountStorageScope.current = 'bob';
    await a.logMeal(sample(id: 'alice'));
    expect(await NutritionDayRepository().listMeals(), isEmpty);
    expect((await guest.listMeals()).single.id, 'guest');
    expect((await a.listMeals()).single.id, 'alice');
  });
  test('projection failure remains visible and recovers by the same ID after reopen', () async {
    final p = ProjectionFixture()..fail = true;
    addTearDown(p.mealsRevision.dispose);
    final r = NutritionDayRepository(fitness: p);
    await r.logMeal(sample(id: 'retry'));
    expect(r.projectionPending, true);
    expect((await r.getTodaySummary()).consumed.kcal, 108);
    await Hive.close();
    p.fail = false;
    await NutritionDayRepository(fitness: p).recover();
    expect(p.meals.keys, ['retry']);
    await NutritionDayRepository(fitness: p).recover();
    expect(p.meals.length, 1);
  });
  test(
    'core-only meals are adopted by ID without changing macros or dates',
    () async {
      final p = ProjectionFixture();
      addTearDown(p.mealsRevision.dispose);
      final date = DateTime(2026, 9, 12);
      p.meals['legacy-id'] = core.MealEntry(
        id: 'legacy-id',
        title: 'Original',
        consumedAt: date,
        calories: 220,
        macros: const core.Macros(carbs: 20, protein: 15, fat: 8),
      );
      final r = NutritionDayRepository(fitness: p),
          m = (await NutritionDayRepository(fitness: p).listMeals()).single;
      expect(m.id, 'legacy-id');
      expect(m.date, date);
      expect((await r.getSummary(date)).consumed.protein, 15);
    },
  );
  test(
    'actual calorie preference is reused; missing goals remain unknown',
    () async {
      final p = ProjectionFixture();
      addTearDown(p.mealsRevision.dispose);
      final r = NutritionDayRepository(fitness: p);
      expect((await r.getTodaySummary()).goal.kcal, isNull);
      p.preferences = core.UserPreferences(
        id: 'p',
        primaryGoal: 'Personal',
        experienceLevel: 'beginner',
        targetSessionsPerWeek: 3,
        modePreference: 'full',
        targetCalories: 2150,
      );
      final s = await r.getTodaySummary();
      expect(s.goal.kcal, 2150);
      expect(s.goal.protein, isNull);
      expect(s.remainingKcal, 2150);
    },
  );
  test(
    'custom foods and favorite templates are scoped and survive reopen',
    () async {
      final guest = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(guest.dispose);
      await guest.createCustomFood(food);
      final t = MealTemplate(
        id: 'favorite',
        name: 'Guardada',
        isFavorite: true,
        createdAt: DateTime.now(),
      );
      await TemplatesRepository().add(t);
      AccountStorageScope.current = 'alice';
      final a = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(a.dispose);
      expect(
        (await a.searchLocalFoods('Yogur de prueba'))
            .any((f) => f.id == food.id),
        false,
      );
      expect(await TemplatesRepository().getTemplates(), isEmpty);
      expect(
        (await TemplatesRepository(scope: '').getTemplates()).single.isFavorite,
        true,
      );
    },
  );
  test(
    'concurrent custom food and template mutations do not overwrite peers',
    () async {
      final a = FoodRepository(fdc: FdcClient(apiKey: '')),
          b = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      final other = FoodItem(
        id: 'other-food',
        name: 'Segundo propio',
        categoryLabel: 'Prueba',
        macrosPer100: food.macrosPer100,
        defaultServingGrams: 100,
        unitSupport: FoodUnitSupport.gramsOnly,
        isCustom: true,
      );
      await Future.wait([a.createCustomFood(food), b.createCustomFood(other)]);
      final c = FoodRepository(fdc: FdcClient(apiKey: ''));
      addTearDown(c.dispose);
      expect(
        (await c.loadLocalCatalog()).where((f) => f.isCustom).map((f) => f.id),
        containsAll([food.id, other.id]),
      );
      await Future.wait([
        for (var i = 0; i < 8; i++)
          TemplatesRepository().add(
            MealTemplate(
              id: 't$i',
              name: 'Template $i',
              createdAt: DateTime.now(),
            ),
          ),
      ]);
      expect((await TemplatesRepository().getTemplates()).length, 8);
    },
  );
  test(
    'unsupported ml and negative quantities cannot create zero-valued entries',
    () async {
      final r = NutritionDayRepository();
      for (final quantity in [-1, 100]) {
        await expectLater(
          r.logMeal(
            LoggedMeal(
              date: DateTime.now(),
              mealType: MealType.lunch,
              entries: [
                DraftEntry(food: food, quantity: quantity, unit: FoodUnit.ml),
              ],
            ),
          ),
          throwsFormatException,
        );
      }
      expect(await r.listMeals(), isEmpty);
    },
  );
  test(
    'Home and Analytics derive durable projections after recreation',
    () async {
      Future<FitnessRepository> open() async => FitnessRepository(
        local: await LocalStorageService.create(),
        remote: UnusedRemote(),
        statistics: StatisticsService(),
      );
      final coreRepo = await open();
      await NutritionDayRepository(fitness: coreRepo)
          .logMeal(sample(id: 'analytics'));
      await Hive.close();
      final reopened = await open();
      expect((await reopened.getMeals()).single.id, 'analytics');
      expect(
        (await reopened.getWeeklyNutritionStats()).single.totalCalories,
        108,
      );
      expect((await reopened.getMacroDistribution()).protein, 6);
      final legacy = core.MealEntry(
        id: '2026-01-01',
        title: 'Old',
        calories: 0,
        macros: const core.Macros(carbs: 0, protein: 0, fat: 0),
      );
      expect(
        core.MealEntry.fromJson(legacy.toJson()).recordedAt,
        DateTime(2026, 1, 1),
      );
    },
  );
}
