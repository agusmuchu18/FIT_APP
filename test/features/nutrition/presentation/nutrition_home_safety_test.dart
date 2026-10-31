import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/nutrition/data/nutrition_day_repository.dart';
import 'package:fit_app/features/nutrition/presentation/nutrition_home_screen.dart';

import '../../../support/nutrition_test_storage.dart';

void main() {
  setUp(() async {
    await nutritionTestStorage();
    await initializeDateFormatting('es');
  });
  testWidgets(
    'unconfigured goals are not represented as fixed nutrition targets',
    (t) async {
      await t.runAsync(() => NutritionDayRepository().recover());
      await t.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: const NutritionHomeScreen()),
      );
      await t.pumpAndSettle();
      expect(find.text('Meta sin configurar'), findsOneWidget);
      expect(find.text('Sin meta diaria'), findsOneWidget);
      expect(find.textContaining('/160'), findsNothing);
      expect(find.textContaining('2.400'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'corrupt legacy data shows recovery instead of a spinner or reset',
    (t) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(NutritionDayRepository.legacyDayKey, 'not-json');
      await t.runAsync(() async {
        await expectLater(
          NutritionDayRepository().recover(),
          throwsFormatException,
        );
      });
      await t.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const NutritionHomeScreen()),
      );
      await t.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(prefs.getString(NutritionDayRepository.legacyDayKey), 'not-json');
      expect(t.takeException(), isNull);
    },
  );
}
