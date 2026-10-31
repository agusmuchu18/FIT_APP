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
double? nutrientAmount(Map<String, dynamic> food, int nutrientNumber) {
  final nutrients = food['foodNutrients'];
  if (nutrients is! List) return null;

  for (final nutrientEntry in nutrients) {
    if (nutrientEntry is! Map) continue;
    final entry = nutrientEntry.cast<String, dynamic>();

    final nestedNumber = entry['nutrient'] is Map
        ? (entry['nutrient'] as Map)
              .cast<String, dynamic>()['number']
              ?.toString()
        : null;
    final flatNumber = entry['nutrientNumber']?.toString();
    final expected = nutrientNumber.toString();
    if (nestedNumber != expected && flatNumber != expected) continue;
    final rawUnit = entry['nutrient'] is Map
        ? (entry['nutrient'] as Map)['unitName']
        : entry['unitName'];
    if (rawUnit != null) {
      final unit = rawUnit
          .toString()
          .trim()
          .toLowerCase()
          .replaceAll('µ', 'u')
          .replaceAll('μ', 'u')
          .replaceAll('mcg', 'ug');
      final expectedUnit = const [208, 957, 958].contains(nutrientNumber)
          ? 'kcal'
          : const [203, 204, 205, 291, 269, 606].contains(nutrientNumber)
          ? 'g'
          : nutrientNumber == 328
          ? 'ug'
          : 'mg';
      if (unit != expectedUnit) return null;
    }

    final amount = entry.containsKey('amount')
        ? entry['amount']
        : entry['value'];
    if (amount is num) {
      return amount.isFinite && amount >= 0 ? amount.toDouble() : null;
    }

    final parsed = double.tryParse(amount?.toString() ?? '');
    if (parsed != null && parsed.isFinite && parsed >= 0) return parsed;
  }

  return null;
}

MacroValues macrosFromFdcDetails(Map<String, dynamic> food) {
  return MacroValues(
    kcal:
        nutrientAmount(food, 958) ??
        nutrientAmount(food, 957) ??
        nutrientAmount(food, _kcalNutrientNumber),
    protein: nutrientAmount(food, _proteinNutrientNumber),
    carbs: nutrientAmount(food, _carbsNutrientNumber),
    fat: nutrientAmount(food, _fatNutrientNumber),
  );
}

Map<String, double?> microsFromFdc(Map<String, dynamic> food) => {
  for (final e in const {
    'fiber_g': 291,
    'sugar_g': 269,
    'saturatedFat_g': 606,
    'sodium_mg': 307,
    'potassium_mg': 306,
    'calcium_mg': 301,
    'iron_mg': 303,
    'magnesium_mg': 304,
    'vitaminC_mg': 401,
    'vitaminD_ug': 328,
  }.entries)
    e.key: nutrientAmount(food, e.value),
};

String? energyMethodFromFdc(Map<String, dynamic> food) {
  if (nutrientAmount(food, 958) != null) return 'USDA · Atwater específico';
  if (nutrientAmount(food, 957) != null) return 'USDA · Atwater general';
  if (nutrientAmount(food, 208) != null) return 'USDA · energía reportada';
  return null;
}
