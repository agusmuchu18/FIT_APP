import '../../../core/domain/entities.dart';

enum MealType { breakfast, lunch, snack, dinner, supper }

enum FoodUnit { serving, grams, ml }

enum FoodUnitSupport { servingOnly, gramsOnly, mlOnly, gramsAndServing, mlAndServing, gramsAndMlAndServing }

class MacroValues {
  const MacroValues({required this.kcal, required this.protein, required this.carbs, required this.fat});

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  static const zero = MacroValues(kcal: 0, protein: 0, carbs: 0, fat: 0);

  MacroValues operator +(MacroValues other) => MacroValues(
        kcal: kcal + other.kcal,
        protein: protein + other.protein,
        carbs: carbs + other.carbs,
        fat: fat + other.fat,
      );

  MacroValues scale(double factor) => MacroValues(
        kcal: kcal * factor,
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
      );

  Macros toCoreMacros() => Macros(carbs: carbs.round(), protein: protein.round(), fat: fat.round());
}

class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.categoryLabel,
    required this.macrosPer100,
    required this.defaultServingGrams,
    required this.unitSupport,
    this.macrosPer100ml,
    this.searchKeywords = const [],
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String categoryLabel;
  final MacroValues macrosPer100;
  final MacroValues? macrosPer100ml;
  final int defaultServingGrams;
  final FoodUnitSupport unitSupport;
  final List<String> searchKeywords;
  final bool isCustom;

  int get caloriesPer100g => macrosPer100.kcal.round();
  Macros get macros => macrosPer100.toCoreMacros();

  bool supportsUnit(FoodUnit unit) {
    switch (unitSupport) {
      case FoodUnitSupport.servingOnly:
        return unit == FoodUnit.serving;
      case FoodUnitSupport.gramsOnly:
        return unit == FoodUnit.grams;
      case FoodUnitSupport.mlOnly:
        return unit == FoodUnit.ml;
      case FoodUnitSupport.gramsAndServing:
        return unit == FoodUnit.grams || unit == FoodUnit.serving;
      case FoodUnitSupport.mlAndServing:
        return unit == FoodUnit.ml || unit == FoodUnit.serving;
      case FoodUnitSupport.gramsAndMlAndServing:
        return true;
    }
  }
}

class DraftEntry {
  const DraftEntry({required this.food, required this.quantity, required this.unit, this.gramsOverride});

  final FoodItem food;
  final int quantity;
  final FoodUnit unit;
  final int? gramsOverride;

  int get effectiveGrams {
    if (gramsOverride != null) return gramsOverride!;
    if (unit == FoodUnit.serving) return food.defaultServingGrams * quantity;
    if (unit == FoodUnit.grams) return quantity;
    return quantity;
  }

  MacroValues get computedMacros {
    if (unit == FoodUnit.ml) {
      final baseMl = food.macrosPer100ml;
      if (baseMl == null) return MacroValues.zero;
      return baseMl.scale(quantity / 100);
    }
    return food.macrosPer100.scale(effectiveGrams / 100);
  }

  DraftEntry copyWith({FoodItem? food, int? quantity, FoodUnit? unit, int? gramsOverride}) {
    return DraftEntry(
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      gramsOverride: gramsOverride,
    );
  }
}

class MealDraft {
  const MealDraft({required this.mealType, required this.entries});

  final MealType mealType;
  final List<DraftEntry> entries;

  int get itemCount => entries.length;
  MacroValues get totals => entries.fold(MacroValues.zero, (a, b) => a + b.computedMacros);
}

class MealTemplate {
  const MealTemplate({required this.id, required this.name, required this.entries, this.mealType});

  final String id;
  final String name;
  final MealType? mealType;
  final List<DraftEntry> entries;
}

class LoggedMeal {
  const LoggedMeal({required this.date, required this.mealType, required this.entries});

  final DateTime date;
  final MealType mealType;
  final List<DraftEntry> entries;

  MacroValues get totals => entries.fold(MacroValues.zero, (a, b) => a + b.computedMacros);
}

String mealTypeLabel(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return 'Desayuno';
    case MealType.lunch:
      return 'Almuerzo';
    case MealType.snack:
      return 'Merienda';
    case MealType.dinner:
      return 'Cena';
    case MealType.supper:
      return 'Snack';
  }
}
