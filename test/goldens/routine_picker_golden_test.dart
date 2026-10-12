import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Crear rutina muestra ejercicios desde el inicio', (
    tester,
  ) async {
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
      'pro_workout_sessions': jsonEncode([]),
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const TemplateExercisePickerScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explorá ejercicios'), findsOneWidget);
    expect(find.byType(ExerciseExpandableCard), findsWidgets);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('routine_picker_default.png'),
    );
  });
}
