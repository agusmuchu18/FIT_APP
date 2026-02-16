import '../domain/models.dart';

const _kcalNutrientNumber = 208;
const _proteinNutrientNumber = 203;
const _fatNutrientNumber = 204;
const _carbsNutrientNumber = 205;

/// Read nutrient amount from USDA FDC payloads.
///
/// Supports:
/// - food details format: `foodNutrients[{ nutrient:{number}, amount }]`
/// - food search format: `foodNutrients[{ nutrientNumber, value }]`
double nutrientAmount(Map<String, dynamic> food, int nutrientNumber) {
  final nutrients = food['foodNutrients'];
  if (nutrients is! List) return 0;

  for (final nutrientEntry in nutrients) {
    if (nutrientEntry is! Map) continue;
    final entry = nutrientEntry.cast<String, dynamic>();

    final nestedNumber = entry['nutrient'] is Map
        ? (entry['nutrient'] as Map).cast<String, dynamic>()['number']?.toString()
        : null;
    final flatNumber = entry['nutrientNumber']?.toString();
    final expected = nutrientNumber.toString();
    if (nestedNumber != expected && flatNumber != expected) continue;

    final amount = entry.containsKey('amount') ? entry['amount'] : entry['value'];
    if (amount is num) return amount.toDouble();

    final parsed = double.tryParse(amount?.toString() ?? '');
    if (parsed != null) return parsed;
  }

  return 0;
}

MacroValues macrosFromFdcDetails(Map<String, dynamic> food) {
  return MacroValues(
    kcal: nutrientAmount(food, _kcalNutrientNumber),
    protein: nutrientAmount(food, _proteinNutrientNumber),
    carbs: nutrientAmount(food, _carbsNutrientNumber),
    fat: nutrientAmount(food, _fatNutrientNumber),
  );
}
