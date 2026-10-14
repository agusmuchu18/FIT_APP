import 'dart:convert';

import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/pro/providers/workout_pro_provider.dart';
import 'package:fit_app/features/workout/application/workout_completion_recovery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workout_completion_projection_test.dart'
    show RecordingFitnessRepository;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('legacy retry/reopen retains one ID and repairs projection without deleting raw rows', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      WorkoutRepository.legacySessionsKey,
      jsonEncode([
        {'id': 'unreadable', 'date': 'invalid', 'type': 'strength'},
      ]),
    );
    final fitness = RecordingFitnessRepository()..failNextSave = true;
    final provider = WorkoutProProvider(fitnessRepository: fitness);
    await provider.initialize();
    provider.setType(WorkoutType.cardio);
    provider.setActivityName('Caminata');
    provider.setDuration(20);
    await expectLater(provider.saveSession(), throwsStateError);
    expect(provider.completionPending, isTrue);
    final sessions = await WorkoutRepository().listAllSessions();
    expect(sessions, hasLength(1));
    final id = sessions.single.id;
    provider.dispose();
    final reopened = WorkoutProProvider(fitnessRepository: fitness);
    addTearDown(reopened.dispose);
    await reopened.initialize();
    expect(reopened.completionPending, isTrue);
    expect(await reopened.saveSession(), isTrue);
    expect(await reopened.saveSession(), isTrue);
    expect((await WorkoutRepository().listAllSessions()).single.id, id);
    expect((await fitness.getWorkouts()).single.id, id);
    final raw = jsonDecode(
      preferences.getString(WorkoutRepository.legacySessionsKey)!,
    ) as List;
    expect(raw.first['id'], 'unreadable');
    expect(raw, hasLength(2));
    expect(preferences.getString('pro_workout_draft'), isNull);
  });
  test('recovery repairs pending Pro close after restart', () async {
    final fitness = RecordingFitnessRepository()..failNextSave = true;
    final provider = WorkoutProProvider(fitnessRepository: fitness);
    await provider.initialize();
    provider.setType(WorkoutType.cardio);
    provider.setDuration(10);
    await expectLater(provider.saveSession(), throwsStateError);
    provider.dispose();
    await recoverCompletedWorkouts(WorkoutRepository(), fitness);
    await recoverCompletedWorkouts(WorkoutRepository(), fitness);
    expect(await fitness.getWorkouts(), hasLength(1));
    expect(
      (await SharedPreferences.getInstance()).getString('pro_workout_draft'),
      isNull,
    );
  });
  test(
    'corrupt Pro draft is kept and cannot be overwritten by entry args',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pro_workout_draft', '{invalid');
      final provider = WorkoutProProvider();
      addTearDown(provider.dispose);
      await provider.initialize();
      provider.applyEntryArgs(trainingContext: 'Gym');
      expect(provider.initializationError, isNotNull);
      expect(provider.initialized, isFalse);
      expect(await provider.saveSession(), isFalse);
      expect(prefs.getString('pro_workout_draft'), '{invalid');
    },
  );
}
