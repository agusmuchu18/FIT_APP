import 'dart:convert';

import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('details request full portions and reported energy codes', () async {
    late Uri requested;
    final client = FdcClient(
      apiKey: 'test-only',
      client: MockClient((request) async {
        requested = request.url;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.dispose);
    await client.getFoodDetails(123);
    expect(requested.queryParameters['format'], 'full');
    final nutrients = requested.queryParameters['nutrients']!.split(',');
    expect(nutrients, containsAll(['957', '958', '401', '328', '203']));
    expect(nutrients.length, lessThanOrEqualTo(25));
  });

  test('rechaza una consulta sin API key antes de usar la red', () async {
    var requestCount = 0;
    final client = FdcClient(
      apiKey: '',
      client: MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.searchFoods('apple'),
      throwsA(isA<FdcRequestException>()),
    );
    expect(requestCount, 0);
  });

  test('codifica la búsqueda y convierte la respuesta', () async {
    late Uri requestedUri;
    final client = FdcClient(
      apiKey: 'test-key',
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'foods': [
              {
                'fdcId': 123,
                'description': 'Red apple',
                'dataType': 'Foundation',
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.searchFoods('red apple');

    expect(requestedUri.queryParameters['api_key'], 'test-key');
    expect(requestedUri.queryParameters['query'], 'red apple');
    expect(result.single.fdcId, 123);
    expect(result.single.description, 'Red apple');
  });

  test('web proxy receives no USDA secret from the client', () async {
    late Uri requestedUri;
    final client = FdcClient(
      apiKey: '',
      proxyBaseUrl: 'https://proxy.example/usda',
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response('{"foods": []}', 200);
      }),
    );
    await client.searchFoods('manzana');
    expect(requestedUri.queryParameters['operation'], 'search');
    expect(requestedUri.queryParameters, isNot(contains('api_key')));
    client.dispose();
  });

  test('no expone el cuerpo remoto cuando USDA devuelve un error', () async {
    final client = FdcClient(
      apiKey: 'test-key',
      client: MockClient(
        (_) async => http.Response('respuesta sensible del proveedor', 429),
      ),
    );

    await expectLater(
      client.searchFoods('apple'),
      throwsA(
        isA<FdcRequestException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having(
              (error) => error.toString(),
              'mensaje',
              isNot(contains('respuesta sensible')),
            ),
      ),
    );
  });
}
