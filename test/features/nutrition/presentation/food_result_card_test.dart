import 'package:fit_app/features/nutrition/domain/models.dart';
import 'package:fit_app/features/nutrition/presentation/widgets/food_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const food = FoodItem(
    id: 'rice',
    name: 'Arroz',
    categoryLabel: 'Cereal',
    macrosPer100: MacroValues(kcal: 130, protein: 2.7, carbs: 28, fat: 0.3),
    defaultServingGrams: 150,
    unitSupport: FoodUnitSupport.gramsAndServing,
  );

  testWidgets('grams are editable without a paywall and use clear increments', (
    tester,
  ) async {
    DraftEntry? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodResultCard(
            food: food,
            expanded: true,
            draftEntry: null,
            loading: false,
            onTap: () {},
            onSave: (entry) => saved = entry,
          ),
        ),
      ),
    );

    expect(find.textContaining('PRO'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'g'));
    await tester.pump();
    expect(find.text('150'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar cantidad'));
    await tester.tap(find.text('Agregar al borrador'));
    expect(saved?.unit, FoodUnit.grams);
    expect(saved?.quantity, 160);
  });
}
