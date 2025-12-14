import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente mínimo para USDA FoodData Central.
class FdcClient {
  FdcClient({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _base = 'https://api.nal.usda.gov/fdc/v1';

  /// Búsqueda liviana. Ideal: pageSize 25 y filtrar por dataType.
  Future<List<FdcSearchItem>> searchFoods(
    String query, {
    int pageSize = 25,
    int pageNumber = 1,
    List<String> dataTypes = const ['Foundation', 'SR Legacy'],
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];

    // Para listas con valores repetidos (dataType), usamos queryParametersAll.
    final uri = Uri.parse('$_base/foods/search').replace(
      queryParameters: {
        'api_key': apiKey,
        'query': q,
        'pageSize': '$pageSize',
        'pageNumber': '$pageNumber',
      },
    );

    // dataType en la spec es array; con GET suele funcionar repetido.
    final uriWithTypes = uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        // hack simple: algunas implementaciones aceptan "Foundation,SR Legacy".
        // si querés 100% prolijo con repetidos, podés usar Uri(queryParametersAll)
        'dataType': dataTypes.join(','),
      },
    );

    final res = await _client.get(uriWithTypes);
    if (res.statusCode != 200) {
      throw Exception('FDC search failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    // En la práctica SearchResult suele venir como objeto con "foods"
    // o directamente lista, depende del formato/endpoint; nos defendemos.
    final foods = (decoded is Map && decoded['foods'] is List)
        ? decoded['foods'] as List
        : (decoded is List ? decoded : const []);

    return foods.map((e) => FdcSearchItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Detalle liviano: pedir formato abridged + SOLO los nutrient numbers que necesitás.
  ///
  /// La API permite `format=abridged|full` y `nutrients` (hasta 25) :contentReference[oaicite:4]{index=4}
  Future<Map<String, dynamic>> getFoodDetails(
    int fdcId, {
    bool abridged = true,
    List<int> nutrientNumbers = const [
      208, // Energy (kcal)
      203, // Protein
      204, // Total lipid (fat)
      205, // Carbohydrate
      291, // Fiber
      269, // Sugars
      606, // Saturated fat
      645, // Monounsaturated fat
      646, // Polyunsaturated fat
      307, // Sodium
      601, // Cholesterol
      306, // Potassium
      301, // Calcium
      303, // Iron
      304, // Magnesium
    ],
  }) async {
    if (nutrientNumbers.length > 25) {
      throw ArgumentError('USDA FDC allows up to 25 nutrients per request.');
    }

    final uri = Uri.parse('$_base/food/$fdcId').replace(
      queryParameters: {
        'api_key': apiKey,
        'format': abridged ? 'abridged' : 'full',
        // enviamos como "203,204,205" (también acepta repetidos según spec) :contentReference[oaicite:5]{index=5}
        'nutrients': nutrientNumbers.join(','),
      },
    );

    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('FDC details failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void dispose() => _client.close();
}

/// Resultado de búsqueda (abridged).
class FdcSearchItem {
  const FdcSearchItem({
    required this.fdcId,
    required this.description,
    this.dataType,
    this.brandOwner,
  });

  final int fdcId;
  final String description;
  final String? dataType;
  final String? brandOwner;

  factory FdcSearchItem.fromJson(Map<String, dynamic> json) {
    return FdcSearchItem(
      fdcId: (json['fdcId'] as num).toInt(),
      description: (json['description'] ?? '').toString(),
      dataType: json['dataType']?.toString(),
      brandOwner: json['brandOwner']?.toString(),
    );
  }
}

