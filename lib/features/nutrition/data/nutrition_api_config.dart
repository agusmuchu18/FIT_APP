class NutritionApiConfig {
  static const usdaApiKey = String.fromEnvironment('USDA_API_KEY', defaultValue: '');
  static bool get hasUsdaKey => usdaApiKey.trim().isNotEmpty;
}
