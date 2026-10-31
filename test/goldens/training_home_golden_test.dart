import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Training Home empty state visual', (tester) async {
    final fontData = await rootBundle.load('assets/fonts/Inter-Variable.ttf');
    await ui.loadFontFromList(
      fontData.buffer.asUint8List(),
      fontFamily: 'Inter',
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'pro_workout_templates': jsonEncode([]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const TrainingHomeScreen(),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/workout/session_strength.webp'),
        tester.element(find.byType(TrainingHomeScreen)),
      );
      await precacheImage(
        const AssetImage('assets/images/workout/equipment_detail.webp'),
        tester.element(find.byType(TrainingHomeScreen)),
      );
      await precacheImage(
        const AssetImage('assets/images/workout/routine_builder.webp'),
        tester.element(find.byType(TrainingHomeScreen)),
      );
    });
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('training_home_empty.png'),
    );
  });
}
