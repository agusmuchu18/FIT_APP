import 'package:intl/date_symbol_data_local.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/workout_device_journey.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('rutina → reapertura → pausa → cierre → historial local', (
    tester,
  ) async {
    final previousScope = AccountStorageScope.current;
    final scope = AccountStorageScope.forUser(
      'integration-workout-${DateTime.now().microsecondsSinceEpoch}',
    );
    final boxes = [
      'fit_workouts',
      'fit_meals',
      'fit_sleep',
      'fit_prefs',
      WorkoutRepository.richSessionsBoxName,
    ].map((base) => AccountStorageScope.boxName(base, scope)).toList();
    AccountStorageScope.current = scope;
    LocalJourneyRepository? fitness;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      WorkoutInProgressController.instance.resetSession();
      await tester.runAsync(() async {
        fitness?.workoutsRevision.dispose();
        // Remove only this unique test namespace, never guest/account records.
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys().where(
          (key) => key.startsWith('account:$scope:'),
        )) {
          await prefs.remove(key);
        }
        for (final name in boxes) {
          if (Hive.isBoxOpen(name)) await Hive.box<String>(name).close();
          await Hive.deleteBoxFromDisk(name);
        }
      });
      AccountStorageScope.current = previousScope;
    });
    fitness = await tester.runAsync(() async {
      await Hive.initFlutter();
      final storage = await LocalStorageService.create(scope: scope);
      await Hive.openBox<String>(boxes.last);
      return LocalJourneyRepository(storage);
    });
    await runWorkoutDeviceJourney(tester, fitness!);
  });
}
