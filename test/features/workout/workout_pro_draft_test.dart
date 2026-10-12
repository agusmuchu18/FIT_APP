import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/features/workout/pro/providers/workout_pro_provider.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/pro/widgets/workout_bottom_bar.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'saving a Pro draft leaves it editable and creates no historical session',
    () async {
      final provider = WorkoutProProvider();
      await provider.initialize();
      provider.setType(WorkoutType.cardio);
      provider.setActivityName('Correr');
      await provider.saveDraft();
      expect(provider.hasDraft, true);
      expect(provider.lastSavedSessionId, isNull);
      expect(await WorkoutRepository().listAllSessions(), isEmpty);
      provider.setDuration(20);
      expect(await provider.saveSession(), true);
      expect(await WorkoutRepository().listAllSessions(), hasLength(1));
      provider.dispose();
    },
  );
  testWidgets(
    'Pro action bar has usable separate actions at 320px and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0, finishes = 0, pauses = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            bottomNavigationBar: WorkoutBottomBar(
              exerciseCount: 2,
              setCount: 6,
              durationLabel: '24m',
              onSave: () => saves++,
              onFinish: () => finishes++,
              onPause: () => pauses++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Guardar borrador'));
      await tester.tap(find.text('Finalizar entrenamiento'));
      await tester.tap(find.text('Pausar sesión'));
      expect((saves, finishes, pauses), (1, 1, 1));
      expect(tester.takeException(), isNull);
    },
  );
}
