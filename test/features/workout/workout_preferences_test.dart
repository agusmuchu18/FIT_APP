import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_preferences.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/training_home/workout_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rest defaults persist and apply to newly added exercises', () async {
    expect((await WorkoutPreferences.load()).defaultRestEnabled, isFalse);
    const preferences = WorkoutPreferences(
      defaultRestEnabled: true,
      defaultRestSeconds: 120,
    );
    await preferences.save();
    expect((await WorkoutPreferences.load()).defaultRestSeconds, 120);

    final controller = WorkoutSessionController(
      repository: WorkoutRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.addExercise(
      exerciseId: 'bench_press',
      name: 'Press banca',
    );
    expect(controller.exercises.single.restEnabled, isTrue);
    expect(controller.exercises.single.restSeconds, 120);
  });

  test('damaged settings fall back to safe defaults', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(WorkoutPreferences.storageKey, '{broken');
    final loaded = await WorkoutPreferences.load();
    expect(loaded.defaultRestEnabled, isFalse);
    expect(loaded.defaultRestSeconds, 90);
  });

  testWidgets('settings screen saves the default rest switch', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WorkoutSettingsScreen()));
    await tester.pump();
    expect(find.text('Activar descanso predeterminado'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump();
    expect((await WorkoutPreferences.load()).defaultRestEnabled, isTrue);

    await tester.tap(find.text('90 segundos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120 segundos').last);
    await tester.pumpAndSettle();
    expect((await WorkoutPreferences.load()).defaultRestSeconds, 120);
    expect(find.text('120 segundos'), findsOneWidget);
  });
}
