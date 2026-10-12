import 'dart:convert';

import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'reads the newest matching exercise from legacy JSON sessions',
    () async {
      SharedPreferences.setMockInitialValues({
        WorkoutRepository.legacySessionsKey: jsonEncode([
          {
            'exercises': [
              {
                'id': 'bench_press',
                'sets': [
                  {'externalLoadKg': 40, 'reps': 6},
                ],
              },
            ],
          },
          {
            'exercises': [
              {
                'id': 'bench_press',
                'sets': [
                  {'externalLoadKg': 50, 'reps': 8},
                ],
              },
            ],
          },
        ]),
      });

      final previous = await WorkoutRepository().getPreviousSetsForExercise(
        'bench_press',
      );

      expect(previous, hasLength(1));
      expect(previous.single.kg, 50);
      expect(previous.single.reps, 8);
    },
  );

  test('prefers a current session over legacy history', () async {
    SharedPreferences.setMockInitialValues({
      WorkoutRepository.sessionsKey: [
        jsonEncode({
          'exercises': [
            {
              'exerciseId': 'bench_press',
              'sets': [
                {'kg': 60, 'reps': 5},
              ],
            },
          ],
        }),
      ],
      WorkoutRepository.legacySessionsKey: jsonEncode([
        {
          'exercises': [
            {
              'id': 'bench_press',
              'sets': [
                {'externalLoadKg': 50, 'reps': 8},
              ],
            },
          ],
        },
      ]),
    });

    final previous = await WorkoutRepository().getPreviousSetsForExercise(
      'bench_press',
    );

    expect(previous.single.kg, 60);
    expect(previous.single.reps, 5);
  });

  test('skips damaged legacy entries and unexpected values', () async {
    SharedPreferences.setMockInitialValues({
      WorkoutRepository.legacySessionsKey: [
        jsonEncode({
          'exercises': [
            {
              'id': 'bench_press',
              'sets': [
                {'externalLoadKg': 30, 'reps': 10},
              ],
            },
          ],
        }),
        'not-json',
      ],
    });

    final previous = await WorkoutRepository().getPreviousSetsForExercise(
      'bench_press',
    );
    expect(previous.single.kg, 30);

    SharedPreferences.setMockInitialValues({
      WorkoutRepository.legacySessionsKey: 123,
    });
    expect(
      await WorkoutRepository().getPreviousSetsForExercise('bench_press'),
      isEmpty,
    );
  });

  test('handles missing and malformed legacy JSON', () async {
    final repository = WorkoutRepository();
    expect(await repository.getPreviousSetsForExercise('bench_press'), isEmpty);

    SharedPreferences.setMockInitialValues({
      WorkoutRepository.legacySessionsKey: '{invalid',
    });
    expect(await repository.getPreviousSetsForExercise('bench_press'), isEmpty);
  });
}
