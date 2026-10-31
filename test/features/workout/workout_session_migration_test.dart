import 'dart:convert';
import 'dart:io';

import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'v2 preference history migrates to Hive without loss or duplication',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fit-workout-test-',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      final box = await Hive.openBox<String>(
        WorkoutRepository.richSessionsBoxName,
      );
      final oldExercise = const ExerciseInSession(
        id: 'instance-1',
        exerciseId: 'bench_press',
        name: 'Press banca',
        sets: [SetInSession(id: 'set-1', index: 1, kg: 40, reps: 8)],
      ).toJson();
      final newerExercise = const ExerciseInSession(
        id: 'instance-2',
        exerciseId: 'bench_press',
        name: 'Press banca',
        sets: [SetInSession(id: 'set-2', index: 1, kg: 50, reps: 6)],
      ).toJson();
      final oldRaw = jsonEncode({
        'id': 'legacy-1',
        'date': '2026-09-26T10:00:00',
        'exercises': [oldExercise],
      });
      final newerRaw = jsonEncode({
        'id': 'legacy-2',
        'date': '2026-09-27T10:00:00',
        'exercises': [newerExercise],
      });
      SharedPreferences.setMockInitialValues({
        WorkoutRepository.sessionsKey: [newerRaw, '{damaged', oldRaw],
      });
      final repository = WorkoutRepository();

      expect(await repository.listSessions(), hasLength(2));
      expect(box.keys.toSet(), {'legacy-1', 'legacy-2'});
      expect(
        (await repository.loadLatestCompletedSessionExercises())?.single.id,
        'instance-2',
      );
      expect(await repository.listSessions(), hasLength(2));
      expect(box.length, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(WorkoutRepository.sessionsKey), [
        newerRaw,
        '{damaged',
        oldRaw,
      ]);
      await repository.persistCompletedWorkout(
        const [],
        sessionId: 'new-session',
        completedAt: DateTime(2026, 9, 28, 10),
      );
      expect(box.keys.toSet(), {'legacy-1', 'legacy-2', 'new-session'});
      expect(await repository.listSessions(), hasLength(3));
      expect(prefs.getStringList(WorkoutRepository.sessionsKey), [
        newerRaw,
        '{damaged',
        oldRaw,
      ]);
    },
  );
}
