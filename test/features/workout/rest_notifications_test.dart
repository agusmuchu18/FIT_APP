import 'dart:convert';

import 'package:fit_app/features/workout/application/rest_notifications.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/widgets/workout_mini_bar_host_overlay.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRestNotifier implements RestNotifier {
  final scheduled = <Duration>[];
  var cancels = 0;
  var permissionRequests = 0;

  @override
  Future<void> ensurePermission() async => permissionRequests++;

  @override
  Future<void> scheduleRestEnd(Duration remaining, {String? workoutName}) async =>
      scheduled.add(remaining);

  @override
  Future<void> cancelRestEnd() async => cancels++;
}

Future<void> _moveTo(WidgetTester tester, List<AppLifecycleState> states) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
    await tester.pump();
  }
}

void main() {
  late RestNotifier original;
  late FakeRestNotifier fake;

  setUp(() {
    original = RestNotifications.instance;
    fake = FakeRestNotifier();
    RestNotifications.instance = fake;
  });
  tearDown(() {
    RestNotifications.instance = original;
    WorkoutInProgressController.instance.resetSession();
  });

  Future<void> pumpApp(WidgetTester tester, {required bool restRunning}) async {
    final start = DateTime.now().subtract(const Duration(minutes: 10));
    SharedPreferences.setMockInitialValues({
      WorkoutRepository.draftKey: jsonEncode({
        'workoutId': 'rest',
        'routineName': 'Empuje',
        'sessionStart': start.toIso8601String(),
        'isPaused': false,
        'accumulatedPausedSeconds': 0,
        // Rest started 30 s ago with 90 s planned: about 60 s remain.
        'restStartedAtElapsedSeconds': restRunning ? 570 : null,
        'restDurationSeconds': restRunning ? 90 : null,
        'exercises': [],
      }),
    });
    await tester.runAsync(WorkoutInProgressController.instance.refresh);
    await tester.pumpWidget(
      const MaterialApp(builder: workoutMiniBarAppBuilder, home: SizedBox()),
    );
    await tester.pump();
  }

  testWidgets('leaving the app during a rest schedules its end', (
    tester,
  ) async {
    await pumpApp(tester, restRunning: true);
    expect(WorkoutInProgressController.instance.currentDraft, isNotNull);
    await _moveTo(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(fake.scheduled, isNotEmpty);
    expect(fake.scheduled.last.inSeconds, inInclusiveRange(55, 61));

    await _moveTo(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(fake.cancels, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('without a running rest nothing is scheduled', (tester) async {
    await pumpApp(tester, restRunning: false);
    await _moveTo(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    expect(fake.scheduled, isEmpty);
    await _moveTo(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
