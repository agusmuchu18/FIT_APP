import '../../../core/domain/entities.dart';

class FoodItem {
  FoodItem({
    required this.name,
    required this.caloriesPer100g,
    required this.macros,
  });

  final String name;
  final int caloriesPer100g;
  final Macros macros;

  int caloriesForPortion(int grams) =>
      ((caloriesPer100g * grams) / 100).round();

  Macros macrosForPortion(int grams) {
    return Macros(
      carbs: ((macros.carbs * grams) / 100).round(),
      protein: ((macros.protein * grams) / 100).round(),
      fat: ((macros.fat * grams) / 100).round(),
    );
  }
}

class FoodRepository {
  FoodRepository({
    String? csvCatalog,
    List<Map<String, dynamic>>? jsonCatalog,
  })  : _csvCatalog = csvCatalog ?? _defaultCsvCatalog,
        _jsonCatalog = jsonCatalog ?? _defaultJsonCatalog;

  final String _csvCatalog;
  final List<Map<String, dynamic>> _jsonCatalog;
  List<FoodItem>? _cached;

  Future<List<FoodItem>> loadLocalCatalog({bool preferJson = false}) async {
    if (_cached != null) return _cached!;
    final parsed = preferJson ? _parseJsonCatalog() : _parseCsvCatalog();
    if (parsed.isNotEmpty) {
      _cached = parsed;
      return parsed;
    }

    final fallback = _parseJsonCatalog();
    _cached = fallback;
    return fallback;
  }

  Future<List<FoodItem>> syncWithPublicCatalog({
    Future<List<FoodItem>> Function()? fetcher,
  }) async {
    try {
      if (fetcher != null) {
        final remoteItems = await fetcher();
        if (remoteItems.isNotEmpty) {
          _cached = remoteItems;
          return remoteItems;
        }
      }
    } catch (_) {
      // When offline or the API is not reachable, fall back to local data.
    }

    return loadLocalCatalog();
  }

  List<FoodItem> _parseCsvCatalog() {
    final lines = _csvCatalog.split('\n');
    if (lines.length <= 1) return [];

    final entries = <FoodItem>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final values = line.split(',');
      if (values.length < 5) continue;

      final name = values[0];
      final calories = int.tryParse(values[1]) ?? 0;
      final carbs = int.tryParse(values[2]) ?? 0;
      final protein = int.tryParse(values[3]) ?? 0;
      final fat = int.tryParse(values[4]) ?? 0;

      entries.add(
        FoodItem(
          name: name,
          caloriesPer100g: calories,
          macros: Macros(carbs: carbs, protein: protein, fat: fat),
        ),
      );
    }
    return entries;
  }

  List<FoodItem> _parseJsonCatalog() {
    return _jsonCatalog
        .map(
          (item) => FoodItem(
            name: item['name'] as String,
            caloriesPer100g: item['caloriesPer100g'] as int,
            macros: Macros(
              carbs: item['carbs'] as int,
              protein: item['protein'] as int,
              fat: item['fat'] as int,
            ),
          ),
        )
        .toList();
  }
}

const _defaultCsvCatalog = 'name,calories,carbs,protein,fat\n'
    'Manzana,52,14,0,0\n'
    'Pollo a la plancha,165,0,31,4\n'
    'Arroz integral,111,23,3,1\n'
    'Aguacate,160,9,2,15\n'
    'Yogur griego,59,3,10,0';

const _defaultJsonCatalog = [
  {
    'name': 'Pan integral',
    'caloriesPer100g': 247,
    'carbs': 41,
    'protein': 13,
    'fat': 4,
  },
  {
    'name': 'Atún en agua',
    'caloriesPer100g': 116,
    'carbs': 0,
    'protein': 26,
    'fat': 1,
  },
  {
    'name': 'Garbanzos cocidos',
    'caloriesPer100g': 164,
    'carbs': 27,
    'protein': 9,
    'fat': 3,
  },
];
