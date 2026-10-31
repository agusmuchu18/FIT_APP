import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/models.dart';

class OfflineFoodCatalog {
  const OfflineFoodCatalog._();

  static const assetPath = 'assets/data/usda_foundation_2026_10.json';
  static Future<List<FoodItem>>? _cached;

  static Future<List<FoodItem>> load() => _cached ??= _load();

  static Future<List<FoodItem>> _load() async {
    final decoded = jsonDecode(await rootBundle.loadString(assetPath));
    final items = (decoded as Map<String, dynamic>)['items'] as List<dynamic>;
    return items
        .map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final name = item['n'] as String;
          final category = item['c'] as String? ?? 'USDA Foundation';
          final serving = item['s'] as num? ?? 100;
          return FoodItem(
            source: 'USDA Foundation 2026-10',
            energyMethod: item['energyMethod'] as String?,
            servingLabel: item['servingLabel'] as String?,
            sourceDate: item['sourceDate'] as String?,
            dataNotes: List<String>.from(item['dataNotes'] as List? ?? []),
            micronutrients: (item['micros'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble()),
            ),
            externalId: item['id'].toString(),
            originalName: name,
            servingVerified: item['s'] != null,
            id: 'fdc:${item['id']}',
            name: _spanishNames[item['id'].toString()] ?? name,
            categoryLabel: '$category · USDA',
            macrosPer100: MacroValues(
              kcal: (item['k'] as num?)?.toDouble(),
              protein: (item['p'] as num?)?.toDouble(),
              carbs: (item['h'] as num?)?.toDouble(),
              fat: (item['f'] as num?)?.toDouble(),
            ),
            defaultServingGrams: serving,
            unitSupport: item['s'] == null
                ? FoodUnitSupport.gramsOnly
                : FoodUnitSupport.gramsAndServing,
            searchKeywords: [name, category, ...searchAliasesFor(name)],
          );
        })
        .toList(growable: false);
  }
}

const _spanishToEnglish = <String, String>{
  'zapallo': 'squash',
  'anana': 'pineapple',
  'mandioca': 'cassava',
  'banana': 'banana',
  'frijol': 'bean',
  'porotos': 'bean',
  'frutillas': 'strawberry',
  'aguacate': 'avocado',
  'aceite': 'oil',
  'ajo': 'garlic',
  'almendra': 'almond',
  'arandano': 'blueberry',
  'arroz': 'rice',
  'atun': 'tuna',
  'avena': 'oat',
  'azucar': 'sugar',
  'batata': 'sweet potato',
  'brocoli': 'broccoli',
  'cafe': 'coffee',
  'carne': 'beef',
  'cebolla': 'onion',
  'cerdo': 'pork',
  'chocolate': 'chocolate',
  'durazno': 'peach',
  'espinaca': 'spinach',
  'frutilla': 'strawberry',
  'garbanzo': 'chickpea',
  'harina': 'flour',
  'huevo': 'egg',
  'leche': 'milk',
  'lechuga': 'lettuce',
  'lenteja': 'lentil',
  'maiz': 'corn',
  'manzana': 'apple',
  'manteca': 'butter',
  'naranja': 'orange',
  'nuez': 'walnut',
  'palta': 'avocado',
  'pan': 'bread',
  'papa': 'potato',
  'pescado': 'fish',
  'pollo': 'chicken',
  'poroto': 'bean',
  'queso': 'cheese',
  'salmon': 'salmon',
  'tomate': 'tomato',
  'uva': 'grape',
  'yogur': 'yogurt',
};

Iterable<String> searchAliasesFor(String englishName) sync* {
  final normalized = englishName.toLowerCase();
  for (final entry in _spanishToEnglish.entries) {
    if (normalized.contains(entry.value)) yield entry.key;
  }
}

List<String> expandSpanishSearch(String query) {
  final normalized = normalizeFoodSearch(query);
  final translated = normalized
      .split(' ')
      .map((word) => _spanishToEnglish[word] ?? word)
      .join(' ');
  return translated == normalized ? [normalized] : [normalized, translated];
}

String normalizeFoodSearch(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

// Exact editorial translations, keyed by stable USDA ID. Other names remain
// original until reviewed; never translate a preparation into a different food.
const _spanishNames = <String, String>{
  '321358': 'Hummus comercial',
  '321360': 'Tomates uva, crudos',
  '321611': 'Chauchas verdes en conserva, escurridas',
  '323121': 'Salchicha de carne vacuna, sin calentar',
  '323294': 'Almendras tostadas en seco, con sal',
  '323505': 'Kale crudo',
  '323604': 'Huevo entero crudo, congelado y pasteurizado',
  '323697': 'Clara de huevo cruda, congelada y pasteurizada',
  '323793': 'Clara de huevo deshidratada',
  '324317':
      'Aros de cebolla empanados, prefritos y congelados, calentados al horno',
  '324653': 'Pepinos encurtidos con eneldo',
  '325036': 'Queso parmesano rallado',
  '325198': 'Queso procesado americano, fortificado con vitamina D',
  '325287': 'Jugo de pomelo blanco, envasado y sin azúcar',
  '325430': 'Duraznos amarillos crudos',
  '325524': 'Semillas de girasol peladas, tostadas en seco y con sal',
};
