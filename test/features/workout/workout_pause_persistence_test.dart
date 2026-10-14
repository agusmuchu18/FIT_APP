import 'dart:convert';

import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'mini bar pauses the v2 draft without changing the legacy draft',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = WorkoutRepository();
      final prefs = await SharedPreferences.getInstance();
      const legacyRaw =
          '{"sessionStart":"2026-09-27T10:00:00","workoutId":"old"}';
      await prefs.setString(WorkoutInProgressController.draftKey, legacyRaw);
      await repository.persistDraftWithStartTime(
        const [
          ExerciseInSession(
            id: 'exercise-1',
            exerciseId: 'bench_press',
            name: 'Press banca',
            sets: [],
          ),
        ],
        startTime: DateTime(2026, 9, 28, 10),
        workoutId: 'new-session',
      );

      final active = WorkoutInProgressController.instance;
      await active.initialize();
      expect(active.currentDraft?.workoutId, 'new-session');

      await active.pause();
      final firstPause = await repository.loadDraftIdentity();
      expect(firstPause?.isPaused, isTrue);
      expect(firstPause?.pausedAt, isNotNull);
      await active.pause();
      expect(
        (await repository.loadDraftIdentity())?.pausedAt,
        firstPause?.pausedAt,
      );

      await repository.persistDraftWithStartTime(
        const [],
        startTime: DateTime(2026, 9, 28, 10),
        workoutId: 'new-session',
      );
      expect((await repository.loadDraftIdentity())?.isPaused, isTrue);
      expect(prefs.getString(WorkoutInProgressController.draftKey), legacyRaw);

      await active.resumePausedWorkout();
      expect((await repository.loadDraftIdentity())?.isPaused, isFalse);
      expect((await repository.loadDraftIdentity())?.pausedAt, isNull);
      expect(prefs.getString(WorkoutInProgressController.draftKey), legacyRaw);

      await active.discard();
      expect(await repository.loadDraftExercises(), isNull);
      expect(prefs.getString(WorkoutInProgressController.draftKey), legacyRaw);
    },
  );

  test('session duration excludes paused time after reopening', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = WorkoutRepository();
    final start = DateTime(2026, 9, 28, 10);
    await repository.persistDraftWithStartTime(
      const [],
      startTime: start,
      workoutId: 'session-clock',
    );
    final prefs = await SharedPreferences.getInstance();
    final json = jsonDecode(
      prefs.getString(WorkoutRepository.draftKey)!,
    ) as Map<String, dynamic>;
    json['isPaused'] = true;
    json['pausedAt'] = start.add(const Duration(minutes: 4)).toIso8601String();
    json['accumulatedPausedSeconds'] = 60;
    await prefs.setString(WorkoutRepository.draftKey, jsonEncode(json));

    final controller = WorkoutSessionController(repository: repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(controller.isPaused, isTrue);
    expect(
      controller.elapsedAt(start.add(const Duration(minutes: 10))),
      const Duration(minutes: 3),
    );
    expect((await repository.loadDraftIdentity())?.isPaused, isTrue);
  });
}
