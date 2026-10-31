import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/profile/profile_social_screen.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/workout/training_test_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  Future<void> mount(
    WidgetTester tester,
    List<WorkoutSession> sessions, {
    double width = 390,
    double scale = 1,
  }) async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await rootBundle.load(entry.value);
      await ui.loadFontFromList(
        data.buffer.asUint8List(),
        fontFamily: entry.key,
      );
    }
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: ProfileSocialScreen(
          repository: TrainingFixtureRepository(sessions),
          now: DateTime(2026, 10, 17),
          photos: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder outerScroll() => find
      .descendant(
        of: find.byType(NestedScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> statistics(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Estadísticas'),
      300,
      scrollable: outerScroll(),
    );
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
  }

  testWidgets('profile header and statistics use actual training fixtures', (
    tester,
  ) async {
    await mount(tester, trainingFixtureSessions());
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('profile_training_overview.png'),
    );
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('profile_training_statistics.png'),
    );
  });
  testWidgets(
    'empty profile statistics remain scrollable at 320px and 200 percent',
    (tester) async {
      await mount(tester, [], width: 320, scale: 2);
      await statistics(tester);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('profile_training_accessible.png'),
      );
    },
  );
}
