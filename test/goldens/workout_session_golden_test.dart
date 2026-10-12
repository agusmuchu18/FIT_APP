import 'dart:ui' as ui;
import 'dart:convert';

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/presentation/workout_in_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('session overview and editing retain a readable mobile layout', (
    tester,
  ) async {
    final font = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
    await ui.loadFontFromList(font.buffer.asUint8List(), fontFamily: 'Inter');
    final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
    await ui.loadFontFromList(
      icons.buffer.asUint8List(),
      fontFamily: 'MaterialIcons',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      WorkoutRepository.draftKey: jsonEncode({
        'workoutId': 'golden-session',
        'sessionStart': '2026-10-01T10:00:00.000',
        'isPaused': true,
        'pausedAt': '2026-10-01T10:17:24.000',
        'exercises': [
          const ExerciseInSession(
            id: 'bench',
            exerciseId: 'bench_press',
            name: 'Press de banca',
            restEnabled: true,
            restSeconds: 90,
            sets: [
              SetInSession(id: 'one', index: 1, kg: 40, reps: 8, done: true),
              SetInSession(id: 'two', index: 2, kg: 40, reps: 8),
            ],
          ).toJson(),
          const ExerciseInSession(
            id: 'plank',
            exerciseId: 'plank',
            name: 'Plancha',
            isTimed: true,
            sets: [SetInSession(id: 'three', index: 1, durationSeconds: 45)],
          ).toJson(),
        ],
      }),
    });
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const WorkoutInProgressScreen()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('workout_session_overview.png'),
    );
    await tester.tap(find.text('Press de banca'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -330));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('workout_session_editing.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
