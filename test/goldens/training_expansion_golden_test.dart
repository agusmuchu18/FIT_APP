import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/presentation/workout_insights_screen.dart';
import 'package:fit_app/features/workout/training_home/exercise_technical_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../features/workout/training_test_fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
    ThemeData? theme,
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
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.workout,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    if (images.isNotEmpty) {
      final context = tester.element(find.byType(Image).first);
      await tester.runAsync(() async {
        for (final image in images) {
          await precacheImage(image.image, context);
        }
      });
      await tester.pumpAndSettle();
    }
  }

  testWidgets('populated exercise chart and accessible exact table', (
    tester,
  ) async {
    await mount(
      tester,
      ExerciseTechnicalScreen(
        exercise: trainingFixtureExercise(),
        repository: TrainingFixtureRepository(trainingFixtureSessions()),
        library: TrainingFixtureLibrary(),
      ),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('training_exercise_progress.png'),
    );
  });
  testWidgets(
    'muscle map and compact large text report retain readable controls',
    (tester) async {
      await mount(
        tester,
        WorkoutInsightsScreen(
          library: TrainingFixtureLibrary(),
          repository: TrainingFixtureRepository(trainingFixtureSessions()),
          now: DateTime(2026, 10, 17),
        ),
      );
      await tester.tap(find.text('Músculos'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ListView).hitTestable().last,
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('training_muscle_map.png'),
      );
      await mount(
        tester,
        WorkoutInsightsScreen(
          library: TrainingFixtureLibrary(),
          repository: TrainingFixtureRepository(trainingFixtureSessions()),
          now: DateTime(2026, 10, 17),
        ),
        size: const Size(320, 844),
        scale: 2,
        theme: AppTheme.light,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('training_insights_large_text.png'),
      );
    },
  );
}
