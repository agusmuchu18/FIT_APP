import 'dart:convert';

import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/presentation/widgets/rest_timer_banner.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const exerciseWithRest = ExerciseInSession(
  id: 'exercise-1',
  exerciseId: 'bench_press',
  name: 'Press banca',
  restEnabled: true,
  restSeconds: 60,
  sets: [SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8)],
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'completed set starts rest, persists and does not restart on edit',
    () async {
      final repository = WorkoutRepository();
      final controller = WorkoutSessionController(repository: repository);
      addTearDown(controller.dispose);
      await controller.initialize(initialExercises: const [exerciseWithRest]);

      controller.updateSet('exercise-1', 'set-1', done: true);
      expect(controller.hasActiveRest, isTrue);
      expect(controller.restSourceExerciseName, 'Press banca');
      final remaining = controller.restRemainingAt(DateTime.now());
      expect(remaining.inSeconds, inInclusiveRange(59, 60));
      expect(
        controller
            .restRemainingAt(DateTime.now().add(const Duration(seconds: 20)))
            .inSeconds,
        inInclusiveRange(39, 40),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final saved = await repository.loadDraftIdentity();
      expect(saved?.restDurationSeconds, 60);
      expect(saved?.restSourceSetId, 'set-1');

      final restored = WorkoutSessionController(repository: repository);
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.hasActiveRest, isTrue);
      restored.updateSet('exercise-1', 'set-1', kg: 55, done: true);
      expect((await repository.loadDraftIdentity())?.restDurationSeconds, 60);

      restored.extendRest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect((await repository.loadDraftIdentity())?.restDurationSeconds, 90);
      restored.skipRest();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(restored.hasActiveRest, isFalse);
      expect((await repository.loadDraftIdentity())?.restSourceSetId, isNull);
    },
  );

  test('paused draft freezes rest countdown until resumed', () async {
    final repository = WorkoutRepository();
    final controller = WorkoutSessionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize(initialExercises: const [exerciseWithRest]);
    controller.updateSet('exercise-1', 'set-1', done: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final prefs = await SharedPreferences.getInstance();
    final draft = jsonDecode(
      prefs.getString(WorkoutRepository.draftKey)!,
    ) as Map<String, dynamic>;
    final pausedAt = DateTime.now();
    draft['isPaused'] = true;
    draft['pausedAt'] = pausedAt.toIso8601String();
    await prefs.setString(WorkoutRepository.draftKey, jsonEncode(draft));

    final restored = WorkoutSessionController(repository: repository);
    addTearDown(restored.dispose);
    await restored.initialize();
    final atPause = restored.restRemainingAt(pausedAt);
    final later = restored.restRemainingAt(
      pausedAt.add(const Duration(minutes: 5)),
    );
    expect(later, atPause);
  });

  test('session pause control freezes and resumes active rest', () async {
    final controller = WorkoutSessionController(
      repository: WorkoutRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize(initialExercises: const [exerciseWithRest]);
    controller.updateSet('exercise-1', 'set-1', done: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await WorkoutInProgressController.instance.initialize();

    await controller.togglePause();
    expect(controller.isPaused, isTrue);
    final atPause = controller.restRemainingAt(DateTime.now());
    expect(
      controller.restRemainingAt(
        DateTime.now().add(const Duration(minutes: 5)),
      ),
      atPause,
    );

    await controller.togglePause();
    expect(controller.isPaused, isFalse);
  });

  testWidgets('rest controls fit a narrow screen with enlarged text', (
    tester,
  ) async {
    final controller = WorkoutSessionController(
      repository: WorkoutRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize(initialExercises: const [exerciseWithRest]);
    controller.updateSet('exercise-1', 'set-1', done: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(2),
                ),
                child: RestTimerBanner(controller: controller),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Saltar'), findsOneWidget);
    expect(find.text('+15 s'), findsOneWidget);
    expect(find.text('−15 s'), findsOneWidget);
  });
}
