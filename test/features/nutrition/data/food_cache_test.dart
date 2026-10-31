import 'package:fit_app/features/nutrition/data/fdc_client.dart';
import 'package:fit_app/features/nutrition/data/food_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const apple = FdcSearchItem(fdcId: 1, description: 'Apple');
  const banana = FdcSearchItem(fdcId: 2, description: 'Banana');
  const carrot = FdcSearchItem(fdcId: 3, description: 'Carrot');

  test('normaliza consultas y devuelve listas inmutables', () {
    final cache = FoodCache();
    cache.putSearch('  RED   Apple ', [apple]);

    final cached = cache.getSearch('red apple');

    expect(cached, [apple]);
    expect(() => cached!.add(banana), throwsUnsupportedError);
  });

  test('descarta la entrada menos usada al superar el límite', () {
    final cache = FoodCache(maxSearchEntries: 2);
    cache.putSearch('apple', [apple]);
    cache.putSearch('banana', [banana]);
    cache.getSearch('apple');

    cache.putSearch('carrot', [carrot]);

    expect(cache.getSearch('apple'), isNotNull);
    expect(cache.getSearch('banana'), isNull);
    expect(cache.getSearch('carrot'), isNotNull);
  });

  test('elimina entradas vencidas', () {
    final cache = FoodCache();
    cache.putSearch('apple', [apple], ttl: const Duration(microseconds: -1));

    expect(cache.getSearch('apple'), isNull);
  });

  test('protege los detalles cacheados contra mutaciones', () {
    final cache = FoodCache();
    cache.putDetails(1, {'description': 'Apple'});

    final cached = cache.getDetails(1)!;

    expect(cached['description'], 'Apple');
    expect(() => cached['description'] = 'Changed', throwsUnsupportedError);
  });
}
