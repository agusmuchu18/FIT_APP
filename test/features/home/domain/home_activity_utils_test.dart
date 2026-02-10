import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/features/home/domain/home_activity_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeDay', () {
    test('removes time component', () {
      final value = DateTime(2026, 2, 10, 23, 59, 58);

      final normalized = normalizeDay(value);

      expect(normalized, DateTime(2026, 2, 10));
    });
  });

  group('activity day detection', () {
    test('buildActiveDaysSet and hasActivity include workout/meal/sleep days', () {
      final workouts = [
        WorkoutEntry(
          id: DateTime(2026, 2, 9, 6).toIso8601String(),
          name: 'Run',
          durationMinutes: 45,
          intensity: 'medium',
        ),
      ];
      final meals = [
        MealEntry(
          id: DateTime(2026, 2, 10, 13).toIso8601String(),
          title: 'Almuerzo',
          calories: 700,
          macros: const Macros(carbs: 70, protein: 35, fat: 20),
        ),
      ];
      final sleep = [
        SleepEntry(
          id: DateTime(2026, 2, 11, 8).toIso8601String(),
          hours: 7.5,
          quality: 'Buena',
          sleepDate: '2026-02-11',
        ),
      ];

      final activeDays = buildActiveDaysSet(
        workouts: workouts,
        meals: meals,
        sleepEntries: sleep,
      );

      expect(hasActivity(day: DateTime(2026, 2, 9), activeDays: activeDays), isTrue);
      expect(hasActivity(day: DateTime(2026, 2, 10), activeDays: activeDays), isTrue);
      expect(hasActivity(day: DateTime(2026, 2, 11), activeDays: activeDays), isTrue);
      expect(hasActivity(day: DateTime(2026, 2, 12), activeDays: activeDays), isFalse);
    });


    test('uses createdAt fallback when id has no parseable date', () {
      final createdAt = DateTime.utc(2026, 2, 14, 10);
      final updatedAt = DateTime.utc(2026, 2, 20, 8);
      final workout = WorkoutEntry(
        id: 'workout-without-date',
        name: 'Bike',
        durationMinutes: 40,
        intensity: 'high',
        meta: EntityMeta(
          createdAt: createdAt,
          updatedAt: updatedAt,
          deleted: false,
          revision: 1,
        ),
      );

      final activeDays = buildActiveDaysSet(
        workouts: [workout],
        meals: const [],
        sleepEntries: const [],
      );

      expect(hasActivity(day: DateTime(2026, 2, 14), activeDays: activeDays), isTrue);
      expect(hasActivity(day: DateTime(2026, 2, 20), activeDays: activeDays), isFalse);
    });

    test('getActivityForDay returns day aggregates', () {
      final target = DateTime(2026, 2, 10);
      final workouts = [
        WorkoutEntry(
          id: DateTime(2026, 2, 10, 7).toIso8601String(),
          name: 'Lift',
          durationMinutes: 30,
          intensity: 'high',
        ),
      ];
      final meals = [
        MealEntry(
          id: DateTime(2026, 2, 10, 12).toIso8601String(),
          title: 'Lunch',
          calories: 600,
          macros: const Macros(carbs: 60, protein: 30, fat: 18),
        ),
      ];
      final sleep = [
        SleepEntry(
          id: DateTime(2026, 2, 10, 8).toIso8601String(),
          hours: 8,
          quality: 'Excelente',
          sleepDate: '2026-02-10',
        ),
      ];

      final summary = getActivityForDay(
        day: target,
        workouts: workouts,
        meals: meals,
        sleepEntries: sleep,
      );

      expect(summary.hasActivity, isTrue);
      expect(summary.totalTrainingMinutes, 30);
      expect(summary.totalCalories, 600);
      expect(summary.workouts.length, 1);
      expect(summary.meals.length, 1);
      expect(summary.sleepEntries.length, 1);
    });
  });
}
