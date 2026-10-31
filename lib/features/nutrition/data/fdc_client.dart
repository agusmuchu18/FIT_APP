import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente mínimo para USDA FoodData Central.
class FdcClient {
  FdcClient({
    required this.apiKey,
    this.proxyBaseUrl = '',
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String proxyBaseUrl;
  final http.Client _client;
  final Duration requestTimeout;
  bool get isConfigured =>
      apiKey.trim().isNotEmpty || proxyBaseUrl.trim().isNotEmpty;

  static const _base = 'https://api.nal.usda.gov/fdc/v1';

  /// Búsqueda liviana. Ideal: pageSize 25 y filtrar por dataType.
  Future<List<FdcSearchItem>> searchFoods(
    String query, {
    int pageSize = 25,
    int pageNumber = 1,
    List<String> dataTypes = const [
      'Foundation',
      'SR Legacy',
      'Branded',
      'Survey (FNDDS)',
    ],
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    _requireConfiguration();

    // Para listas con valores repetidos (dataType), usamos queryParametersAll.
    final usingProxy = proxyBaseUrl.trim().isNotEmpty;
    final uri = Uri.parse(usingProxy ? proxyBaseUrl : '$_base/foods/search')
        .replace(
          queryParameters: {
            if (usingProxy) 'operation': 'search' else 'api_key': apiKey,
            'query': q,
            'pageSize': '$pageSize',
            'pageNumber': '$pageNumber',
          },
        );

    // dataType en la spec es array; con GET suele funcionar repetido.
    final uriWithTypes = usingProxy
        ? uri
        : uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              // hack simple: algunas implementaciones aceptan "Foundation,SR Legacy".
              // si querés 100% prolijo con repetidos, podés usar Uri(queryParametersAll)
              'dataType': dataTypes.join(','),
            },
          );

    final res = await _client.get(uriWithTypes).timeout(requestTimeout);
    if (res.statusCode != 200) {
      throw FdcRequestException(
        operation: 'búsqueda',
        statusCode: res.statusCode,
      );
    }

    final decoded = jsonDecode(res.body);
    // En la práctica SearchResult suele venir como objeto con "foods"
    // o directamente lista, depende del formato/endpoint; nos defendemos.
    final foods = (decoded is Map && decoded['foods'] is List)
        ? decoded['foods'] as List
        : (decoded is List ? decoded : const []);

    return foods
        .map((e) => FdcSearchItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Detalle liviano: pedir formato abridged + SOLO los nutrient numbers que necesitás.
  ///
  /// La API permite `format=abridged|full` y `nutrients` (hasta 25) :contentReference[oaicite:4]{index=4}
  Future<Map<String, dynamic>> getFoodDetails(
    int fdcId, {
    bool abridged = false,
    List<int> nutrientNumbers = const [
      208, // Energy (kcal)
      957, // Atwater general, reported by USDA
      958, // Atwater specific, reported by USDA
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
      401, // Vitamin C
      328, // Vitamin D
    ],
  }) async {
    _requireConfiguration();
    if (nutrientNumbers.length > 25) {
      throw ArgumentError('USDA FDC allows up to 25 nutrients per request.');
    }

    final usingProxy = proxyBaseUrl.trim().isNotEmpty;
    final uri = Uri.parse(usingProxy ? proxyBaseUrl : '$_base/food/$fdcId')
        .replace(
          queryParameters: {
            if (usingProxy) 'operation': 'detail' else 'api_key': apiKey,
            if (usingProxy) 'fdcId': '$fdcId',
            'format': abridged ? 'abridged' : 'full',
            // enviamos como "203,204,205" (también acepta repetidos según spec) :contentReference[oaicite:5]{index=5}
            'nutrients': nutrientNumbers.join(','),
          },
        );

    final res = await _client.get(uri).timeout(requestTimeout);
    if (res.statusCode != 200) {
      throw FdcRequestException(
        operation: 'detalle',
        statusCode: res.statusCode,
      );
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  void _requireConfiguration() {
    if (apiKey.trim().isEmpty && proxyBaseUrl.trim().isEmpty) {
      throw const FdcRequestException(
        operation: 'consulta',
        message: 'USDA_API_KEY no está configurada.',
      );
    }
  }

  void dispose() => _client.close();
}

class FdcRequestException implements Exception {
  const FdcRequestException({
    required this.operation,
    this.statusCode,
    this.message,
  });

  final String operation;
  final int? statusCode;
  final String? message;

  @override
  String toString() {
    if (message != null) return message!;
    return 'La $operation de USDA falló${statusCode == null ? '' : ' ($statusCode)'}.';
  }
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
