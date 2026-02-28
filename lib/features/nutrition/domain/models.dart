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

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };

  factory MacroValues.fromJson(Map<String, dynamic> json) => MacroValues(
        kcal: (json['kcal'] as num? ?? 0).toDouble(),
        protein: (json['protein'] as num? ?? 0).toDouble(),
        carbs: (json['carbs'] as num? ?? 0).toDouble(),
        fat: (json['fat'] as num? ?? 0).toDouble(),
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

class TemplateItem {
  const TemplateItem({
    required this.name,
    this.serving = '1 porción',
    this.macros,
  });

  final String name;
  final String serving;
  final MacroValues? macros;

  Map<String, dynamic> toJson() => {
        'name': name,
        'serving': serving,
        'macros': macros?.toJson(),
      };

  factory TemplateItem.fromJson(Map<String, dynamic> json) => TemplateItem(
        name: (json['name'] ?? '').toString(),
        serving: (json['serving'] ?? '1 porción').toString(),
        macros: json['macros'] is Map<String, dynamic> ? MacroValues.fromJson(json['macros'] as Map<String, dynamic>) : null,
      );
}

class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.name,
    this.mealType,
    this.folderId,
    this.isFavorite = false,
    this.entries = const [],
    this.items = const [],
    this.totals = MacroValues.zero,
    required this.createdAt,
    this.lastUsedAt,
  });

  final String id;
  final String name;
  final MealType? mealType;
  final String? folderId;
  final bool isFavorite;
  final List<DraftEntry> entries;
  final List<TemplateItem> items;
  final MacroValues totals;
  final DateTime createdAt;
  final DateTime? lastUsedAt;

  List<TemplateItem> get effectiveItems {
    if (items.isNotEmpty) return items;
    if (entries.isEmpty) return const [];
    return entries
        .map((entry) => TemplateItem(
              name: entry.food.name,
              serving: '${entry.quantity} ${entry.unit.name}',
              macros: entry.computedMacros,
            ))
        .toList(growable: false);
  }

  MacroValues get effectiveTotals {
    if (totals != MacroValues.zero || items.isNotEmpty) return totals;
    if (entries.isEmpty) return MacroValues.zero;
    return entries.fold(MacroValues.zero, (sum, entry) => sum + entry.computedMacros);
  }

  MealTemplate copyWith({
    String? id,
    String? name,
    MealType? mealType,
    bool clearMealType = false,
    String? folderId,
    bool clearFolderId = false,
    bool? isFavorite,
    List<TemplateItem>? items,
    MacroValues? totals,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return MealTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: clearMealType ? null : (mealType ?? this.mealType),
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      isFavorite: isFavorite ?? this.isFavorite,
      entries: entries,
      items: items ?? this.items,
      totals: totals ?? this.totals,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mealType': mealType?.name,
        'folderId': folderId,
        'isFavorite': isFavorite,
        'items': effectiveItems.map((i) => i.toJson()).toList(),
        'totals': effectiveTotals.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory MealTemplate.fromJson(Map<String, dynamic> json) {
    final mealTypeName = json['mealType']?.toString();
    return MealTemplate(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      mealType: MealType.values.where((t) => t.name == mealTypeName).isEmpty ? null : MealType.values.firstWhere((t) => t.name == mealTypeName),
      folderId: json['folderId']?.toString(),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) => TemplateItem.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false),
      totals: json['totals'] is Map<String, dynamic> ? MacroValues.fromJson(json['totals'] as Map<String, dynamic>) : MacroValues.zero,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      lastUsedAt: json['lastUsedAt'] == null ? null : DateTime.tryParse(json['lastUsedAt'].toString()),
    );
  }
}

class TemplateFolder {
  const TemplateFolder({
    required this.id,
    required this.name,
    this.icon,
    this.isDefault = false,
    this.order = 0,
  });

  final String id;
  final String name;
  final String? icon;
  final bool isDefault;
  final int order;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'isDefault': isDefault,
        'order': order,
      };

  factory TemplateFolder.fromJson(Map<String, dynamic> json) => TemplateFolder(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        icon: json['icon']?.toString(),
        isDefault: (json['isDefault'] as bool?) ?? false,
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
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
