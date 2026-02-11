import 'package:fit_app/features/habits/domain/habit_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HabitEntry buildHabit({
    HabitFrequency frequency = HabitFrequency.daily,
    DateTime? startDate,
    Set<int>? weekdays,
    int intervalWeeks = 1,
    int? dayOfMonth,
    bool adjustToLastDayIfMissing = true,
  }) {
    return HabitEntry.create(
      name: 'Test',
      iconKey: 'spark',
      colorArgb: 0xFF000000,
      category: 'Personal',
      frequency: frequency,
      startDate: startDate,
      activeWeekdays: weekdays,
      intervalWeeks: intervalWeeks,
      dayOfMonth: dayOfMonth,
      adjustToLastDayIfMissing: adjustToLastDayIfMissing,
    );
  }

  test('startDate futuro no aparece antes', () {
    final habit = buildHabit(startDate: DateTime(2026, 3, 15));
    expect(shouldAppearOn(habit, DateTime(2026, 3, 14)), isFalse);
    expect(shouldAppearOn(habit, DateTime(2026, 3, 15)), isTrue);
  });

  test('daily con weekdays solo aparece en días activos', () {
    final habit = buildHabit(
      startDate: DateTime(2026, 3, 2),
      weekdays: {DateTime.monday, DateTime.wednesday},
    );
    expect(shouldAppearOn(habit, DateTime(2026, 3, 2)), isTrue);
    expect(shouldAppearOn(habit, DateTime(2026, 3, 3)), isFalse);
    expect(shouldAppearOn(habit, DateTime(2026, 3, 4)), isTrue);
  });

  test('weekly interval aparece cada N semanas mismo weekday', () {
    final habit = buildHabit(
      frequency: HabitFrequency.weekly,
      startDate: DateTime(2026, 3, 7),
      intervalWeeks: 2,
    );
    expect(shouldAppearOn(habit, DateTime(2026, 3, 7)), isTrue);
    expect(shouldAppearOn(habit, DateTime(2026, 3, 14)), isFalse);
    expect(shouldAppearOn(habit, DateTime(2026, 3, 21)), isTrue);
  });

  test('monthly respeta dayOfMonth y ajuste a fin de mes', () {
    final habit = buildHabit(
      frequency: HabitFrequency.monthly,
      startDate: DateTime(2026, 1, 31),
      dayOfMonth: 31,
      adjustToLastDayIfMissing: true,
    );
    expect(shouldAppearOn(habit, DateTime(2026, 2, 28)), isTrue);
    expect(shouldAppearOn(habit, DateTime(2026, 3, 31)), isTrue);

    final strictHabit = buildHabit(
      frequency: HabitFrequency.monthly,
      startDate: DateTime(2026, 1, 31),
      dayOfMonth: 31,
      adjustToLastDayIfMissing: false,
    );
    expect(shouldAppearOn(strictHabit, DateTime(2026, 2, 28)), isFalse);
  });
}
