import 'dart:convert';

import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:fit_app/features/workout/widgets/workout_mini_bar.dart';
import 'package:fit_app/features/workout/widgets/workout_mini_bar_host_overlay.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTrainingWithOverlay(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/workout',
        navigatorObservers: [WorkoutMiniBarRouteObserver()],
        builder: (context, child) {
          final app = child ?? const SizedBox.shrink();
          return Overlay(
            initialEntries: [
              OverlayEntry(builder: (_) => app),
              OverlayEntry(builder: (_) => const WorkoutMiniBarHostOverlay()),
            ],
          );
        },
        routes: {
          '/workout': (_) => const TrainingHomeScreen(),
          '/workout/session': (_) => const Scaffold(body: Text('Session')),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('render de TrainingHomeScreen con draft activo muestra mini bar', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      WorkoutInProgressController.draftKey: jsonEncode({
        'sessionStart': now.subtract(const Duration(minutes: 3)).toIso8601String(),
        'isPaused': false,
        'pausedAt': null,
        'accumulatedPausedSeconds': 0,
        'lastUpdated': now.toIso8601String(),
      }),
      'pro_workout_templates': jsonEncode([]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await WorkoutInProgressController.instance.initialize();
    await pumpTrainingWithOverlay(tester);

    expect(find.byType(WorkoutMiniBar), findsOneWidget);
    expect(find.text('Entrenamiento en curso'), findsOneWidget);
  });

  testWidgets('draft null no muestra mini bar', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pro_workout_templates': jsonEncode([]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await WorkoutInProgressController.instance.initialize();
    WorkoutInProgressController.instance.syncFromRaw(null);

    await pumpTrainingWithOverlay(tester);

    expect(find.byType(WorkoutMiniBar), findsNothing);
  });

  testWidgets('tooltips de mini bar funcionan dentro de Overlay real', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      WorkoutInProgressController.draftKey: jsonEncode({
        'sessionStart': now.subtract(const Duration(minutes: 1)).toIso8601String(),
        'isPaused': false,
        'pausedAt': null,
        'accumulatedPausedSeconds': 0,
        'lastUpdated': now.toIso8601String(),
      }),
      'pro_workout_templates': jsonEncode([]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await WorkoutInProgressController.instance.initialize();
    await pumpTrainingWithOverlay(tester);

    await tester.longPress(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Pausar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
