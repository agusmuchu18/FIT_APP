import '../../../core/domain/entities.dart';

import 'package:uuid/uuid.dart';

enum MealType { breakfast, lunch, snack, dinner, supper }

enum FoodUnit { serving, grams, ml }

enum FoodUnitSupport {
  servingOnly,
  gramsOnly,
  mlOnly,
  gramsAndServing,
  mlAndServing,
  gramsAndMlAndServing,
}

class MacroValues {
  const MacroValues({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  static const unknown = MacroValues(
    kcal: null,
    protein: null,
    carbs: null,
    fat: null,
  );
  bool get isComplete => [kcal, protein, carbs, fat].every((v) => v != null);
  static double? _add(double? a, double? b) =>
      a == null || b == null ? null : a + b;
  static String display(double? value, {int decimals = 1}) => value == null
      ? '—'
      : value.toStringAsFixed(decimals).replaceAll('.', ',');
  static const zero = MacroValues(kcal: 0, protein: 0, carbs: 0, fat: 0);

  MacroValues operator +(MacroValues other) => MacroValues(
    kcal: _add(kcal, other.kcal),
    protein: _add(protein, other.protein),
    carbs: _add(carbs, other.carbs),
    fat: _add(fat, other.fat),
  );

  MacroValues scale(double factor) => MacroValues(
    kcal: kcal == null ? null : kcal! * factor,
    protein: protein == null ? null : protein! * factor,
    carbs: carbs == null ? null : carbs! * factor,
    fat: fat == null ? null : fat! * factor,
  );

  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory MacroValues.fromJson(Map<String, dynamic> json) => MacroValues(
    kcal: (json['kcal'] as num?)?.toDouble(),
    protein: (json['protein'] as num?)?.toDouble(),
    carbs: (json['carbs'] as num?)?.toDouble(),
    fat: (json['fat'] as num?)?.toDouble(),
  );

  Macros toCoreMacros() => Macros(
    carbs: carbs?.round() ?? 0,
    protein: protein?.round() ?? 0,
    fat: fat?.round() ?? 0,
  );
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
    this.source = 'legacy',
    this.barcode,
    this.detailsLoaded = true,
    this.energyMethod,
    this.servingLabel,
    this.sourceDate,
    this.dataNotes = const [],
    this.externalId,
    this.originalName,
    this.brand,
    this.preparation,
    this.micronutrients = const {},
    this.servingVerified = false,
  });

  final String id;
  final String name;
  final String categoryLabel;
  final MacroValues macrosPer100;
  final MacroValues? macrosPer100ml;
  final num defaultServingGrams;
  final FoodUnitSupport unitSupport;
  final List<String> searchKeywords;
  final bool isCustom;
  final String source;
  final String? barcode;
  final bool detailsLoaded;
  final String? energyMethod, servingLabel, sourceDate;
  final List<String> dataNotes;
  final String? externalId, originalName, brand, preparation;
  final Map<String, double?> micronutrients;
  final bool servingVerified;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryLabel': categoryLabel,
    'macrosPer100': macrosPer100.toJson(),
    'macrosPer100ml': macrosPer100ml?.toJson(),
    'defaultServingGrams': defaultServingGrams,
    'unitSupport': unitSupport.name,
    'searchKeywords': searchKeywords,
    'isCustom': isCustom,
    'source': source,
    'barcode': barcode,
    'detailsLoaded': detailsLoaded,
    'energyMethod': energyMethod,
    'servingLabel': servingLabel,
    'sourceDate': sourceDate,
    'dataNotes': dataNotes,
    'externalId': externalId,
    'originalName': originalName,
    'brand': brand,
    'preparation': preparation,
    'micronutrients': micronutrients,
    'servingVerified': servingVerified,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: json['id'] as String,
    name: json['name'] as String,
    categoryLabel: json['categoryLabel'] as String,
    macrosPer100: MacroValues.fromJson(
      Map<String, dynamic>.from(json['macrosPer100'] as Map),
    ),
    macrosPer100ml: json['macrosPer100ml'] == null
        ? null
        : MacroValues.fromJson(
            Map<String, dynamic>.from(json['macrosPer100ml'] as Map),
          ),
    defaultServingGrams: json['defaultServingGrams'] as num,
    unitSupport: FoodUnitSupport.values.byName(json['unitSupport'] as String),
    searchKeywords: List<String>.from(json['searchKeywords'] as List? ?? []),
    isCustom: json['isCustom'] as bool? ?? false,
    source: json['source'] as String? ?? 'legacy',
    barcode: json['barcode'] as String?,
    detailsLoaded: json['detailsLoaded'] as bool? ?? true,
    energyMethod: json['energyMethod'] as String?,
    servingLabel: json['servingLabel'] as String?,
    sourceDate: json['sourceDate'] as String?,
    dataNotes: List<String>.from(json['dataNotes'] as List? ?? []),
    externalId: json['externalId'] as String?,
    originalName: json['originalName'] as String?,
    brand: json['brand'] as String?,
    preparation: json['preparation'] as String?,
    servingVerified: json['servingVerified'] as bool? ?? false,
    micronutrients: (json['micronutrients'] as Map? ?? {}).map(
      (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble()),
    ),
  );

  int get caloriesPer100g => macrosPer100.kcal?.round() ?? 0;
  Macros get macros => macrosPer100.toCoreMacros();

  bool supportsUnit(FoodUnit unit) {
    if (unit == FoodUnit.ml && macrosPer100ml == null) return false;
    if (unit == FoodUnit.serving && defaultServingGrams <= 0) return false;
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
  const DraftEntry({
    required this.food,
    required this.quantity,
    required this.unit,
    this.gramsOverride,
  });

  final FoodItem food;
  final num quantity;
  final FoodUnit unit;
  final num? gramsOverride;

  Map<String, dynamic> toJson() => {
    'food': food.toJson(),
    'quantity': quantity,
    'unit': unit.name,
    'gramsOverride': gramsOverride,
  };

  factory DraftEntry.fromJson(Map<String, dynamic> json) => DraftEntry(
    food: FoodItem.fromJson(Map<String, dynamic>.from(json['food'] as Map)),
    quantity: json['quantity'] as num,
    unit: FoodUnit.values.byName(json['unit'] as String),
    gramsOverride: json['gramsOverride'] as num?,
  );

  num get effectiveGrams {
    if (gramsOverride != null) return gramsOverride!;
    if (unit == FoodUnit.serving) return food.defaultServingGrams * quantity;
    if (unit == FoodUnit.grams) return quantity;
    return quantity;
  }

  MacroValues get computedMacros {
    if (unit == FoodUnit.ml) {
      final baseMl = food.macrosPer100ml;
      if (baseMl == null) return MacroValues.unknown;
      return baseMl.scale(quantity / 100);
    }
    return food.macrosPer100.scale(effectiveGrams / 100);
  }

  DraftEntry copyWith({
    FoodItem? food,
    num? quantity,
    FoodUnit? unit,
    num? gramsOverride,
  }) {
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
  MacroValues get totals =>
      entries.fold(MacroValues.zero, (a, b) => a + b.computedMacros);
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
    macros: json['macros'] is Map<String, dynamic>
        ? MacroValues.fromJson(json['macros'] as Map<String, dynamic>)
        : null,
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
    this.servings = 1,
    this.instructions = '',
    this.cookedWeightGrams,
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
  final num servings;
  final String instructions;
  final num? cookedWeightGrams;
  bool get isRecipe => entries.isNotEmpty;
  MealTemplate portion(num count) {
    if (!count.isFinite || count <= 0 || !servings.isFinite || servings <= 0) {
      throw const FormatException('Raciones inválidas.');
    }
    final factor = count / servings;
    return copyWith(
      name: '$name · $count ración(es)',
      servings: count,
      entries: [
        for (final e in entries)
          e.copyWith(
            quantity: e.quantity * factor,
            gramsOverride: e.gramsOverride == null
                ? null
                : e.gramsOverride! * factor,
          ),
      ],
      totals: effectiveTotals.scale(factor),
      cookedWeightGrams: cookedWeightGrams == null
          ? null
          : cookedWeightGrams! * factor,
    );
  }

  List<TemplateItem> get effectiveItems {
    if (items.isNotEmpty) return items;
    if (entries.isEmpty) return const [];
    return entries
        .map(
          (entry) => TemplateItem(
            name: entry.food.name,
            serving: '${entry.quantity} ${entry.unit.name}',
            macros: entry.computedMacros,
          ),
        )
        .toList(growable: false);
  }

  MacroValues get effectiveTotals {
    if (totals != MacroValues.zero || items.isNotEmpty) return totals;
    if (entries.isEmpty) return MacroValues.zero;
    return entries.fold(
      MacroValues.zero,
      (sum, entry) => sum + entry.computedMacros,
    );
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
    num? servings,
    String? instructions,
    num? cookedWeightGrams,
    List<DraftEntry>? entries,
  }) {
    return MealTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: clearMealType ? null : (mealType ?? this.mealType),
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      isFavorite: isFavorite ?? this.isFavorite,
      entries: entries ?? this.entries,
      items: items ?? this.items,
      totals: totals ?? this.totals,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      servings: servings ?? this.servings,
      instructions: instructions ?? this.instructions,
      cookedWeightGrams: cookedWeightGrams ?? this.cookedWeightGrams,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'servings': servings,
    'instructions': instructions,
    'cookedWeightGrams': cookedWeightGrams,
    'name': name,
    'mealType': mealType?.name,
    'folderId': folderId,
    'isFavorite': isFavorite,
    'items': effectiveItems.map((i) => i.toJson()).toList(),
    'entries': entries.map((entry) => entry.toJson()).toList(),
    'totals': effectiveTotals.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
  };

  factory MealTemplate.fromJson(Map<String, dynamic> json) {
    final mealTypeName = json['mealType']?.toString();
    return MealTemplate(
      id: (json['id'] ?? '').toString(),
      servings: json['servings'] as num? ?? 1,
      instructions: json['instructions'] as String? ?? '',
      cookedWeightGrams: json['cookedWeightGrams'] as num?,
      name: (json['name'] ?? '').toString(),
      mealType: MealType.values.where((t) => t.name == mealTypeName).isEmpty
          ? null
          : MealType.values.firstWhere((t) => t.name == mealTypeName),
      folderId: json['folderId']?.toString(),
      isFavorite: (json['isFavorite'] as bool?) ?? false,
      entries: (json['entries'] as List? ?? [])
          .map(
            (raw) => DraftEntry.fromJson(Map<String, dynamic>.from(raw as Map)),
          )
          .toList(),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((raw) => TemplateItem.fromJson(Map<String, dynamic>.from(raw)))
          .toList(growable: false),
      totals: json['totals'] is Map<String, dynamic>
          ? MacroValues.fromJson(json['totals'] as Map<String, dynamic>)
          : MacroValues.zero,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.tryParse(json['lastUsedAt'].toString()),
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
  LoggedMeal({
    String? id,
    required this.date,
    required this.mealType,
    required this.entries,
    this.snapshot,
    this.title,
    this.sourceId,
    this.method = 'manual',
  }) : id = id ?? const Uuid().v4();

  final String id;
  final MacroValues? snapshot;
  final String? title, sourceId;
  final String method;

  final DateTime date;
  final MealType mealType;
  final List<DraftEntry> entries;

  MacroValues get totals =>
      snapshot ??
      entries.fold(MacroValues.zero, (a, b) => a + b.computedMacros);
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

/// Structural validation shared by manual entry and versioned imports.
/// It never fills an absent nutrient or infers a density/cooking factor.
void validateNutritionFood(FoodItem f) {
  if (f.id.isEmpty ||
      f.name.trim().isEmpty ||
      !f.defaultServingGrams.isFinite ||
      f.defaultServingGrams < 0) {
    throw const FormatException('Alimento inválido.');
  }
  for (final m in [
    f.macrosPer100,
    if (f.macrosPer100ml != null) f.macrosPer100ml!,
  ]) {
    for (final v in [m.kcal, m.protein, m.carbs, m.fat]) {
      if (v != null && (!v.isFinite || v < 0)) {
        throw const FormatException('Nutriente inválido.');
      }
    }
  }
  for (final v in f.micronutrients.values) {
    if (v != null && (!v.isFinite || v < 0)) {
      throw const FormatException('Micronutriente inválido.');
    }
  }
}

void validateNutritionEntry(DraftEntry e) {
  validateNutritionFood(e.food);
  if (!e.food.detailsLoaded) {
    throw const FormatException(
      'Confirmá la ficha del alimento antes de registrarlo.',
    );
  }
  if (!e.quantity.isFinite ||
      e.quantity <= 0 ||
      !e.food.supportsUnit(e.unit) ||
      (e.gramsOverride != null &&
          (!e.gramsOverride!.isFinite || e.gramsOverride! <= 0))) {
    throw const FormatException('Cantidad o unidad no confirmada.');
  }
}

void validateNutritionTemplate(MealTemplate t) {
  if (t.id.isEmpty ||
      t.name.trim().isEmpty ||
      !t.servings.isFinite ||
      t.servings <= 0 ||
      (t.cookedWeightGrams != null &&
          (!t.cookedWeightGrams!.isFinite || t.cookedWeightGrams! <= 0))) {
    throw const FormatException('Receta o raciones inválidas.');
  }
  for (final e in t.entries) {
    validateNutritionEntry(e);
  }
  for (final v in [
    t.effectiveTotals.kcal,
    t.effectiveTotals.protein,
    t.effectiveTotals.carbs,
    t.effectiveTotals.fat,
  ]) {
    if (v != null && (!v.isFinite || v < 0)) {
      throw const FormatException('Totales no válidos.');
    }
  }
}

bool nutritionDataEqual(Object? a, Object? b) {
  if (a is num && b is num) return a == b;
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && nutritionDataEqual(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        [for (var i = 0; i < a.length; i++) i]
            .every((i) => nutritionDataEqual(a[i], b[i]));
  }
  return a == b;
}

bool sameFoodComposition(FoodItem a, FoodItem b) =>
    a.id == b.id &&
    a.defaultServingGrams == b.defaultServingGrams &&
    nutritionDataEqual(a.macrosPer100.toJson(), b.macrosPer100.toJson()) &&
    nutritionDataEqual(
      a.macrosPer100ml?.toJson(),
      b.macrosPer100ml?.toJson(),
    ) &&
    nutritionDataEqual(a.micronutrients, b.micronutrients);
String normalizeNutritionBarcode(String raw) {
  final code = raw.trim();
  if (!RegExp(r'^(?:\d{8}|\d{12}|\d{13}|\d{14})$').hasMatch(code)) {
    throw const FormatException(
      'Ingresá un código GTIN de 8, 12, 13 o 14 dígitos.',
    );
  }
  if (RegExp(r'^0+$').hasMatch(code)) {
    throw const FormatException('El código no identifica un producto.');
  }
  var sum = 0;
  for (var i = code.length - 2, weight = 3; i >= 0; i--, weight = 4 - weight) {
    sum += int.parse(code[i]) * weight;
  }
  if ((10 - sum % 10) % 10 != int.parse(code[code.length - 1])) {
    throw const FormatException('El dígito de control del código no coincide.');
  }
  return code.padLeft(14, '0');
}
