import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:fit_app/features/nutrition/data/nutrition_day_repository.dart';
import 'package:fit_app/features/nutrition/data/templates_repository.dart';
import 'package:fit_app/features/nutrition/presentation/nutrition_home_screen.dart';
import 'package:fit_app/features/nutrition/presentation/widgets/food_result_card.dart';

import '../../../support/nutrition_test_storage.dart';

const partial = FoodItem(
  id: 'qa-layout',
  name: 'Alimento con nombre largo para comprobar legibilidad y detalle nutricional',
  categoryLabel: 'Declarado por el usuario',
  macrosPer100: MacroValues(kcal: 100, protein: null, carbs: 0, fat: 2),
  defaultServingGrams: 100,
  unitSupport: FoodUnitSupport.gramsAndServing,
  isCustom: true,
);
void main() {
  setUp(() async {
    await nutritionTestStorage();
    await initializeDateFormatting('es');
  });
  for (final dark in [false, true]) {
    testWidgets(
      'partial food and fractional input at 320px, 200% text, ${dark ? 'dark' : 'light'}',
      (t) async {
        t.view.physicalSize = const Size(320, 760);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        DraftEntry? saved;
        await t.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 760),
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: FoodResultCard(
                    food: partial,
                    expanded: true,
                    draftEntry: null,
                    loading: false,
                    onTap: () {},
                    onSave: (e) => saved = e,
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.ensureVisible(find.widgetWithText(ChoiceChip, 'g'));
        await t.tap(find.widgetWithText(ChoiceChip, 'g'));
        await t.pump();
        await t.enterText(find.byType(TextField), '125,5');
        await t.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        await t.ensureVisible(find.text('Agregar al borrador'));
        await t.pumpAndSettle();
        await t.tap(find.text('Agregar al borrador'));
        await t.pump();
        expect(saved?.quantity, 125.5);
        expect(saved?.computedMacros.protein, isNull);
        expect(saved?.computedMacros.carbs, 0);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'populated diary, recipes and plan remain usable on a compact screen',
    (t) async {
      final days = NutritionDayRepository(), templates = TemplatesRepository();
      await t.runAsync(() async {
        await days.logMeal(
          LoggedMeal(
            id: 'layout-meal',
            date: DateTime.now(),
            mealType: MealType.lunch,
            title: 'Almuerzo de prueba',
            entries: [
              const DraftEntry(
                food: partial,
                quantity: 125.5,
                unit: FoodUnit.grams,
              ),
            ],
          ),
        );
        await templates.add(
          MealTemplate(
            id: 'layout-recipe',
            name: 'Receta de prueba con nombre largo',
            entries: [
              const DraftEntry(
                food: partial,
                quantity: 100,
                unit: FoodUnit.grams,
              ),
            ],
            totals: partial.macrosPer100,
            servings: 2,
            createdAt: DateTime.now(),
          ),
        );
      });
      t.view.physicalSize = const Size(320, 760);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const NutritionHomeScreen()),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Almuerzo de prueba'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(RefreshIndicator),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Almuerzo de prueba'), findsOneWidget);
      await t.tap(find.text('Recetas'));
      await t.pumpAndSettle();
      expect(find.text('Crear receta'), findsOneWidget);
      expect(find.textContaining('Receta de prueba'), findsOneWidget);
      await t.ensureVisible(find.text('Plan'));
      await t.tap(find.text('Plan'));
      await t.pumpAndSettle();
      expect(find.text('Planificar sin registrar'), findsOneWidget);
      await t.tap(find.text('Elegir una receta'));
      await t.pumpAndSettle();
      expect(find.text('Crear receta'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
