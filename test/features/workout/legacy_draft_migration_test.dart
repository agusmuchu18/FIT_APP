import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/application/legacy_draft_migration.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyKey = LegacyDraftMigration.legacyDraftKey;

Map<String, dynamic> _strengthDraft() => {
  'type': 'strength',
  'workoutId': 'legacy-1',
  'templateId': 'push',
  'templateName': 'Empuje',
  'sessionStart': DateTime(2026, 10, 20, 18).toIso8601String(),
  'isPaused': true,
  'pausedAt': DateTime(2026, 10, 20, 18, 30).toIso8601String(),
  'accumulatedPausedSeconds': 120,
  'exercises': [
    WorkoutExercise(
      id: 'bench_press',
      name: 'Press banca',
      targetSets: 2,
      restSeconds: 90,
      sets: [
        SetEntry(id: 's1', reps: 8, externalLoadKg: 60, done: true),
        SetEntry(id: 's2', reps: 8, externalLoadKg: 60, done: false),
      ],
    ).toJson(),
  ],
};

Future<ScopedPreferences> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return ScopedPreferences.getInstance();
}

void main() {
  tearDown(WorkoutInProgressController.instance.resetSession);

  test('a strength draft from the old screen opens in the live session', () async {
    final prefs = await _prefs({_legacyKey: jsonEncode(_strengthDraft())});

    expect(await LegacyDraftMigration.run(prefs), isTrue);

    expect(prefs.getString(_legacyKey), isNull);
    final exercises = await WorkoutRepository().loadDraftExercises();
    expect(exercises, hasLength(1));
    final bench = exercises!.single;
    expect(bench.exerciseId, 'bench_press');
    expect(bench.restEnabled, isTrue);
    expect(bench.restSeconds, 90);
    expect(bench.sets.map((s) => (s.kg, s.reps, s.done)), [
      (60.0, 8, true),
      (60.0, 8, false),
    ]);
    final identity = await WorkoutRepository().loadDraftIdentity();
    expect(identity?.sessionId, 'legacy-1');
    expect(identity?.routineId, 'push');
    expect(identity?.routineName, 'Empuje');
    expect(identity?.isPaused, isTrue);
    expect(identity?.accumulatedPaused, const Duration(seconds: 120));

    await WorkoutInProgressController.instance.refresh();
    expect(WorkoutInProgressController.instance.hasActiveWorkout, isTrue);
    expect(WorkoutInProgressController.instance.isLegacyDraftActive, isFalse);
    expect(
      WorkoutInProgressController.instance.startTime,
      DateTime(2026, 10, 20, 18),
    );
  });

  test('an activity log without exercises stays with the old screen', () async {
    final raw = jsonEncode({
      'type': 'cardio',
      'workoutId': 'run',
      'activityName': 'Correr',
      'sessionStart': DateTime(2026, 10, 20).toIso8601String(),
      'exercises': <Object>[],
    });
    final prefs = await _prefs({_legacyKey: raw});

    expect(await LegacyDraftMigration.run(prefs), isFalse);
    expect(prefs.getString(_legacyKey), raw);
    expect(prefs.getString(WorkoutRepository.draftKey), isNull);
  });

  test('an unreadable draft is kept untouched', () async {
    final prefs = await _prefs({_legacyKey: '{invalid'});
    expect(await LegacyDraftMigration.run(prefs), isFalse);
    expect(prefs.getString(_legacyKey), '{invalid');
  });

  test('a session already open in the live screen is never replaced', () async {
    final legacy = jsonEncode(_strengthDraft());
    final prefs = await _prefs({
      _legacyKey: legacy,
      WorkoutRepository.draftKey: jsonEncode({
        'workoutId': 'live',
        'sessionStart': DateTime(2026, 10, 21).toIso8601String(),
        'exercises': <Object>[],
      }),
    });
    expect(await LegacyDraftMigration.run(prefs), isFalse);
    expect(prefs.getString(_legacyKey), legacy);
    expect(
      jsonDecode(prefs.getString(WorkoutRepository.draftKey)!)['workoutId'],
      'live',
    );
  });

  test('a draft whose save already reached history is dropped', () async {
    final prefs = await _prefs({
      _legacyKey: jsonEncode({
        ..._strengthDraft(),
        'pendingCompletedSessionId': 'legacy-1',
      }),
    });
    await WorkoutRepository().persistLegacySession(
      WorkoutSession(
        id: 'legacy-1',
        type: WorkoutType.strength,
        date: DateTime(2026, 10, 20, 19),
      ),
    );

    expect(await LegacyDraftMigration.run(prefs), isTrue);
    expect(prefs.getString(_legacyKey), isNull);
    expect(prefs.getString(WorkoutRepository.draftKey), isNull);
  });

  test('a save still in progress is left for the old screen to finish', () async {
    final raw = jsonEncode({
      ..._strengthDraft(),
      'pendingCompletedSessionId': 'legacy-1',
    });
    final prefs = await _prefs({_legacyKey: raw});
    expect(await LegacyDraftMigration.run(prefs), isFalse);
    expect(prefs.getString(_legacyKey), raw);
  });
}
