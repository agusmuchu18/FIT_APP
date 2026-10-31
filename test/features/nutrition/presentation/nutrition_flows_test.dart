import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/data/statistics_service.dart';
import 'package:fit_app/core/domain/entities.dart' as core;
import 'package:fit_app/main.dart';
import 'package:fit_app/features/analytics/analytics_overview_screen.dart';
import 'package:fit_app/features/nutrition/application/food_log_controller.dart';
import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_repository.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:fit_app/features/nutrition/presentation/meal_draft_sheet.dart';

import '../../../support/nutrition_test_storage.dart';

class _NutritionStats extends Fake implements FitnessRepository {
  int requestedDays = 0;
  @override
  Future<List<NutritionMetrics>> getWeeklyNutritionStats({int days = 7}) async {
    requestedDays = days;
    return [
      NutritionMetrics(
        date: DateTime.now(),
        totalCalories: 0,
        macros: const core.Macros(carbs: 0, protein: 0, fat: 0),
        unknownNutrients: {'kcal', 'protein'},
      ),
      NutritionMetrics(
        date: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day - 1,
        ),
        totalCalories: 0,
        macros: const core.Macros(carbs: 0, protein: 0, fat: 0),
      ),
    ];
  }

  @override
  Future<core.Macros> getMacroDistribution({int days = 7}) async =>
      const core.Macros(carbs: 0, protein: 0, fat: 0);
  // Other modules deliberately are not implemented. Nutrition must not read them.
}

void main() {
  setUp(nutritionTestStorage);
  testWidgets('clearing a draft updates its sheet and disables registration', (
    t,
  ) async {
    final foods = FoodRepository(fdc: FdcClient(apiKey: ''));
    final controller = FoodLogController(repository: foods);
    addTearDown(controller.dispose);
    addTearDown(foods.dispose);
    const food = FoodItem(
      id: 'ui-draft',
      name: 'Producto QA',
      categoryLabel: 'QA',
      macrosPer100: MacroValues.unknown,
      defaultServingGrams: 100,
      unitSupport: FoodUnitSupport.gramsOnly,
    );
    controller.addOrUpdateDraft(
      const DraftEntry(food: food, quantity: 125.5, unit: FoodUnit.grams),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: MealDraftSheet(controller: controller)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('125,5 g'), findsOneWidget);
    await t.tap(find.text('Vaciar borrador'));
    await t.pumpAndSettle();
    expect(find.text('Producto QA'), findsNothing);
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Registrar en el día'),
          )
          .onPressed,
      isNull,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'nutrition statistics preserve missing days and switch periods at 320px',
    (t) async {
      t.view.physicalSize = const Size(320, 760);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final repository = _NutritionStats();
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: RepositoryScope(
            repository: repository,
            child: const AnalyticsOverviewScreen(nutritionOnly: true),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(repository.requestedDays, 7);
      final todayLabel = find.text('${DateTime.now().day}');
      expect(todayLabel, findsOneWidget);
      expect(t.getRect(todayLabel).right, lessThanOrEqualTo(320));

      await t.ensureVisible(find.text('Valores exactos y días sin registro'));
      await t.pumpAndSettle();
      await t.tap(find.text('Valores exactos y días sin registro'));
      await t.pumpAndSettle();
      expect(find.text('— kcal'), findsOneWidget);
      expect(find.text('Sin registro'), findsNWidgets(5));
      expect(find.text('0 kcal'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byType(DropdownButtonFormField<int>),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Últimos 7 días').last);
      await t.pumpAndSettle();
      await t.tap(find.text('Últimos 30 días').last);
      await t.pumpAndSettle();
      expect(repository.requestedDays, 30);
      expect(find.textContaining('Últimos 30 días de energía'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
