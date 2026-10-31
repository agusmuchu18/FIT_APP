import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/workout_device_journey.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  testWidgets(
    'rehearses the mobile journey with disk Hive and mocked preferences',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previousScope = AccountStorageScope.current;
      AccountStorageScope.current = AccountStorageScope.forUser(
        'journey-rehearsal',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final temporary = await tester.runAsync(
        () => Directory.systemTemp.createTemp('fit-workout-journey-'),
      );
      Hive.init(temporary!.path);
      final storage = await tester.runAsync(() => LocalStorageService.create());
      await tester.runAsync(
        () => Hive.openBox<String>(WorkoutRepository().sessionsBoxName),
      );
      final fitness = LocalJourneyRepository(storage!);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        WorkoutInProgressController.instance.resetSession();
        fitness.workoutsRevision.dispose();
        var closed = false;
        Future<void>? closing;
        await tester.runAsync(() async {
          closing = Hive.close().then((_) => closed = true);
        });
        // Hive stream notifications can belong to the widget fake-async zone.
        // Pump that zone while allowing the real disk close to complete.
        for (var attempt = 0; !closed && attempt < 100; attempt++) {
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        }
        expect(
          closed,
          isTrue,
          reason: 'Hive debe cerrar antes de eliminar el fixture',
        );
        await closing;
        await tester.runAsync(() => temporary.delete(recursive: true));
        AccountStorageScope.current = previousScope;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await runWorkoutDeviceJourney(tester, fitness);
    },
  );
}
