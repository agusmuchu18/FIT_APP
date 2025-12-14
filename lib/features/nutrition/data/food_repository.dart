import 'dart:collection';

import 'package:csv/csv.dart';

import '../../../core/domain/entities.dart';

class FoodItem {
  FoodItem({
    required this.name,
    required this.caloriesPer100g,
    required this.macros,
  })  : assert(name.length > 0),
        assert(caloriesPer100g >= 0),
        assert(macros.carbs >= 0 && macros.protein >= 0 && macros.fat >= 0);

  final String name;
  final int caloriesPer100g;
  final Macros macros;

  int caloriesForPortion(int grams) {
    if (grams < 0) {
      throw ArgumentError.value(grams, 'grams', 'must be >= 0');
    }
    return ((caloriesPer100g * grams) / 100).round();
  }

  Macros macrosForPortion(int grams) {
    if (grams < 0) {
      throw ArgumentError.value(grams, 'grams', 'must be >= 0');
    }
    return Macros(
      carbs: ((macros.carbs * grams) / 100).round(),
      protein: ((macros.protein * grams) / 100).round(),
      fat: ((macros.fat * grams) / 100).round(),
    );
  }

  // Útil para dedupe y búsquedas consistentes.
  String get normalizedName => _normalizeName(name);

  @override
  String toString() =>
      'FoodItem(name: $name, caloriesPer100g: $caloriesPer100g, macros: $macros)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItem &&
          other.normalizedName == normalizedName &&
          other.caloriesPer100g == caloriesPer100g &&
          other.macros.carbs == macros.carbs &&
          other.macros.protein == macros.protein &&
          other.macros.fat == macros.fat;

  @override
  int get hashCode => Object.hash(
        normalizedName,
        caloriesPer100g,
        macros.carbs,
        macros.protein,
        macros.fat,
      );
}

enum _CatalogSource { remote, localCsv, localJson }

class FoodRepository {
  FoodRepository({
    String? csvCatalog,
    List<Map<String, dynamic>>? jsonCatalog,
    this.onWarning,
    this.onError,
  })  : _csvCatalog = csvCatalog ?? _defaultCsvCatalog,
        _jsonCatalog = jsonCatalog ?? _defaultJsonCatalog;

  /// Callback opcional para observabilidad (no rompe UX en prod).
  final void Function(String message)? onWarning;

  /// Callback opcional para errores (ej: reporting / crashlytics).
  final void Function(Object error, StackTrace stackTrace)? onError;

  final String _csvCatalog;
  final List<Map<String, dynamic>> _jsonCatalog;

  // Cache local por fuente (para respetar preferJson).
  List<FoodItem>? _cachedCsv;
  List<FoodItem>? _cachedJson;

  // Cache “activo” (puede ser remoto o local). Mantiene compatibilidad:
  // si sync trae remoto, loadLocalCatalog() sigue devolviendo el cache activo.
  List<FoodItem>? _activeCatalog;
  _CatalogSource? _activeSource;

  // Evita duplicar trabajo si se llama al mismo tiempo desde varios lugares.
  Future<List<FoodItem>>? _inFlightLocalLoad;
  Future<List<FoodItem>>? _inFlightSync;

  /// Limpia caches. Útil para tests o refresh manual.
  void clearCache() {
    _cachedCsv = null;
    _cachedJson = null;
    _activeCatalog = null;
    _activeSource = null;
    _inFlightLocalLoad = null;
    _inFlightSync = null;
  }

  /// Carga el catálogo local.
  ///
  /// - preferJson: prioriza JSON local si hay datos.
  /// - useActiveCache: por default mantiene compatibilidad:
  ///   si antes sincronizaste remoto, devuelve ese catálogo.
  ///   Setealo en false si querés *forzar* local.
  Future<List<FoodItem>> loadLocalCatalog({
    bool preferJson = false,
    bool useActiveCache = true,
  }) async {
    if (useActiveCache && _activeCatalog != null) {
      return _activeCatalog!;
    }
    if (_inFlightLocalLoad != null) return _inFlightLocalLoad!;

    _inFlightLocalLoad = Future(() {
      List<FoodItem> parsed;

      if (preferJson) {
        parsed = _cachedJson ??= _parseJsonCatalog();
        if (parsed.isEmpty) {
          parsed = _cachedCsv ??= _parseCsvCatalog();
          _setActive(parsed, parsed.isEmpty ? null : _CatalogSource.localCsv);
        } else {
          _setActive(parsed, _CatalogSource.localJson);
        }
      } else {
        parsed = _cachedCsv ??= _parseCsvCatalog();
        if (parsed.isEmpty) {
          parsed = _cachedJson ??= _parseJsonCatalog();
          _setActive(parsed, parsed.isEmpty ? null : _CatalogSource.localJson);
        } else {
          _setActive(parsed, _CatalogSource.localCsv);
        }
      }

      // Si ambos vacíos, al menos devolvemos lista vacía inmutable.
      return _immutable(parsed);
    }).whenComplete(() {
      _inFlightLocalLoad = null;
    });

    return _inFlightLocalLoad!;
  }

  /// Sincroniza con catálogo público (remoto) si se provee fetcher.
  /// Si falla o viene vacío, hace fallback a local.
  Future<List<FoodItem>> syncWithPublicCatalog({
    Future<List<FoodItem>> Function()? fetcher,
  }) async {
    if (_inFlightSync != null) return _inFlightSync!;

    _inFlightSync = Future(() async {
      if (fetcher != null) {
        try {
          final remote = await fetcher();
          final sanitized = _sanitizeCatalog(remote);
          if (sanitized.isNotEmpty) {
            _setActive(sanitized, _CatalogSource.remote);
            return _immutable(sanitized);
          } else {
            onWarning?.call(
              'Remote catalog returned empty list. Falling back to local.',
            );
          }
        } catch (e, st) {
          onError?.call(e, st);
          // fallback local
        }
      }

      return loadLocalCatalog();
    }).whenComplete(() {
      _inFlightSync = null;
    });

    return _inFlightSync!;
  }

  // -------------------------
  // Parsing / sanitization
  // -------------------------

  List<FoodItem> _parseCsvCatalog() {
    final text = _csvCatalog;
    if (text.trim().isEmpty) return const [];

    final delimiter = _detectDelimiter(text);
    final converter = CsvToListConverter(
      fieldDelimiter: delimiter,
      textDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false, // control total
    );

    List<List<dynamic>> rows;
    try {
      rows = converter.convert(text);
    } catch (e, st) {
      onError?.call(e, st);
      return const [];
    }

    if (rows.isEmpty) return const [];

    // Header: case-insensitive + soporta caloriesPer100g o calories
    final header = rows.first
        .map((e) => (e ?? '').toString().trim().toLowerCase())
        .toList();

    int idxName = header.indexOf('name');
    int idxCalories = header.indexOf('calories');
    if (idxCalories == -1) idxCalories = header.indexOf('caloriesper100g');
    final idxCarbs = header.indexOf('carbs');
    final idxProtein = header.indexOf('protein');
    final idxFat = header.indexOf('fat');

    final headerLooksValid = idxName != -1 &&
        idxCalories != -1 &&
        idxCarbs != -1 &&
        idxProtein != -1 &&
        idxFat != -1;

    final items = <FoodItem>[];

    for (final row in rows.skip(1)) {
      if (row.isEmpty) continue;

      String name;
      int calories;
      int carbs;
      int protein;
      int fat;

      if (headerLooksValid) {
        name = _cellString(row, idxName);
        calories = _cellInt(row, idxCalories);
        carbs = _cellInt(row, idxCarbs);
        protein = _cellInt(row, idxProtein);
        fat = _cellInt(row, idxFat);
      } else {
        // Fallback por orden clásico: name, calories, carbs, protein, fat
        if (row.length < 5) continue;
        name = _cellString(row, 0);
        calories = _cellInt(row, 1);
        carbs = _cellInt(row, 2);
        protein = _cellInt(row, 3);
        fat = _cellInt(row, 4);
      }

      final normalized = _normalizeName(name);
      if (normalized.isEmpty) continue;

      items.add(
        FoodItem(
          name: normalized,
          caloriesPer100g: _nonNegative(calories),
          macros: Macros(
            carbs: _nonNegative(carbs),
            protein: _nonNegative(protein),
            fat: _nonNegative(fat),
          ),
        ),
      );
    }

    return _sanitizeCatalog(items);
  }

  List<FoodItem> _parseJsonCatalog() {
    if (_jsonCatalog.isEmpty) return const [];

    final items = <FoodItem>[];
    for (final item in _jsonCatalog) {
      try {
        final name = _asString(item['name']);
        final normalized = _normalizeName(name ?? '');
        if (normalized.isEmpty) continue;

        final calories = _asInt(item['caloriesPer100g']);
        final carbs = _asInt(item['carbs']);
        final protein = _asInt(item['protein']);
        final fat = _asInt(item['fat']);

        items.add(
          FoodItem(
            name: normalized,
            caloriesPer100g: _nonNegative(calories),
            macros: Macros(
              carbs: _nonNegative(carbs),
              protein: _nonNegative(protein),
              fat: _nonNegative(fat),
            ),
          ),
        );
      } catch (e, st) {
        onError?.call(e, st);
        // seguimos con el resto
      }
    }

    return _sanitizeCatalog(items);
  }

  /// Normaliza + dedupe + ordena + vuelve inmutable.
  List<FoodItem> _sanitizeCatalog(List<FoodItem> input) {
    if (input.isEmpty) return const [];

    // Dedupe por nombre normalizado (primero gana).
    final map = <String, FoodItem>{};
    for (final item in input) {
      final key = item.normalizedName;
      if (key.isEmpty) continue;
      map.putIfAbsent(key, () => item);
    }

    final list = map.values.toList();

    // Ordenado estable por nombre (ignorando mayúsculas).
    list.sort((a, b) => a.normalizedName
        .toLowerCase()
        .compareTo(b.normalizedName.toLowerCase()));

    return list;
  }

  void _setActive(List<FoodItem> items, _CatalogSource? source) {
    _activeCatalog = _immutable(items);
    _activeSource = source;
  }

  List<FoodItem> _immutable(List<FoodItem> items) {
    if (items is UnmodifiableListView<FoodItem>) return items;
    return UnmodifiableListView(items);
  }

  // -------------------------
  // CSV helpers
  // -------------------------

  String _cellString(List<dynamic> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return (row[index] ?? '').toString();
  }

  int _cellInt(List<dynamic> row, int index) {
    final s = _cellString(row, index).trim();
    if (s.isEmpty) return 0;

    // Permite "116", "116.0" y también "116,0" si alguien exportó raro.
    final normalized = s.replaceAll(',', '.');
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(normalized);
    if (asDouble != null) return asDouble.round();

    return 0;
  }

  String _detectDelimiter(String csv) {
    // Usa primera línea “real”.
    final firstLine = csv.split(RegExp(r'\r?\n')).firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    if (firstLine.isEmpty) return ',';

    final commas = _countChar(firstLine, ',');
    final semicolons = _countChar(firstLine, ';');

    // Si hay más ; que , asumimos ;.
    return semicolons > commas ? ';' : ',';
  }

  int _countChar(String s, String ch) {
    var count = 0;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == ch) count++;
    }
    return count;
  }

  // -------------------------
  // JSON helpers
  // -------------------------

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      final v = value.trim();
      if (v.isEmpty) return 0;
      final normalized = v.replaceAll(',', '.');
      final i = int.tryParse(normalized);
      if (i != null) return i;
      final d = double.tryParse(normalized);
      return d?.round() ?? 0;
    }
    return 0;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }
}

int _nonNegative(int v) => v < 0 ? 0 : v;

String _normalizeName(String raw) {
  // trim + colapsa espacios internos
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
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
