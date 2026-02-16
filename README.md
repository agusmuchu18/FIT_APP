# fit_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## USDA FoodData Central API key

Para habilitar búsquedas USDA en nutrición:

```bash
flutter run --dart-define=USDA_API_KEY=TU_KEY
flutter run -d chrome --dart-define=USDA_API_KEY=TU_KEY
```

Para build local:

```bash
flutter build apk --dart-define=USDA_API_KEY=TU_KEY
flutter build web --dart-define=USDA_API_KEY=TU_KEY
```

Para GitHub Pages (GitHub Actions), crear el secret del repositorio:

1. `Settings` → `Secrets and variables` → `Actions`
2. `New repository secret`
3. Name: `USDA_API_KEY`
4. Value: `<tu key>`
