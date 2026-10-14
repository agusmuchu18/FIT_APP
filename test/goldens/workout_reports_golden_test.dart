import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/presentation/workout_summary_screen.dart';
import 'package:fit_app/features/workout/training_home/workout_history_screen.dart';

import '../support/workout_report_fixture.dart';

void main() {
  testWidgets('summary, history, detail, empty and compact reports', (
    tester,
  ) async {
    for (final font in [
      ('assets/fonts/Inter-Variable.ttf', 'Inter'),
      ('fonts/MaterialIcons-Regular.otf', 'MaterialIcons'),
    ]) {
      final bytes = await rootBundle.load(font.$1);
      await ui.loadFontFromList(
        bytes.buffer.asUint8List(),
        fontFamily: font.$2,
      );
    }
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = WorkoutReportsRepository([
      workoutReportFixture(),
      workoutReportFixture(
        id: 'previous',
        date: DateTime(2026, 10, 8, 18, 30),
        kg: 35,
      ),
    ]);
    Future<void> capture(
      Widget screen,
      String file, {
      double textScale = 1,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: screen,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        for (final asset in [
          'summary_hero',
          'history_empty',
          'history_mixed',
        ]) {
          await precacheImage(
            AssetImage('assets/images/workout/$asset.webp'),
            context,
          );
        }
        for (final category in [
          'push',
          'pull',
          'legs',
          'arms',
          'mobility',
          'mixed',
        ]) {
          await precacheImage(
            ResizeImage(
              AssetImage('assets/images/workout/history_$category.webp'),
              width: 160,
            ),
            context,
          );
        }
        for (final id in [
          'bench_press',
          'pull_up',
          'back_squat',
          'deadlift',
          'military_press',
          'plank',
        ]) {
          await precacheImage(
            ResizeImage(
              AssetImage('assets/images/workout/exercises/$id.webp'),
              width: 160,
            ),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(Scaffold), matchesGoldenFile(file));
    }

    await capture(
      WorkoutSummaryScreen(sessionId: 'saved', repository: repository),
      'workout_summary.png',
    );
    await capture(
      WorkoutHistoryScreen(repository: repository, now: DateTime(2026, 10, 12)),
      'workout_history.png',
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -640));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('workout_history_cards.png'),
    );
    await capture(
      WorkoutHistoryDetailScreen(sessionId: 'saved', repository: repository),
      'workout_detail.png',
    );
    await tester.scrollUntilVisible(find.textContaining('Serie 2'), 300);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('workout_detail_sets.png'),
    );
    await capture(
      WorkoutHistoryScreen(
        repository: WorkoutReportsRepository([]),
        now: DateTime(2026, 10, 12),
      ),
      'workout_history_empty.png',
    );
    tester.view.physicalSize = const Size(320, 900);
    await capture(
      WorkoutSummaryScreen(sessionId: 'saved', repository: repository),
      'workout_summary_compact.png',
      textScale: 2,
    );
    tester.view.physicalSize = const Size(900, 900);
    await capture(
      WorkoutSummaryScreen(sessionId: 'saved', repository: repository),
      'workout_summary_wide.png',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
