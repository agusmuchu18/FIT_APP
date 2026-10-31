import 'package:flutter/foundation.dart';

class NutritionApiConfig {
  static const _configuredUsdaApiKey = String.fromEnvironment(
    'USDA_API_KEY',
    defaultValue: '',
  );
  static const usdaProxyBaseUrl = String.fromEnvironment(
    'USDA_PROXY_BASE_URL',
    defaultValue: 'https://fit-app-usda-proxy.agusmuchu18-fit-app.workers.dev',
  );

  /// Una clave de USDA no puede mantenerse secreta dentro de un bundle web.
  /// La búsqueda web utiliza el proxy configurado y nunca recibe esa clave.
  static String get usdaApiKey => kIsWeb ? '' : _configuredUsdaApiKey;

  static bool get hasUsdaKey => usdaApiKey.trim().isNotEmpty;
  static bool get hasRemoteSearch =>
      hasUsdaKey || (kIsWeb && usdaProxyBaseUrl.isNotEmpty);
}
