import 'package:flutter/foundation.dart';

@immutable
class HabitDailyLog {
  const HabitDailyLog({
    required this.habitId,
    required this.dateKey,
    required this.count,
    required this.isCompleted,
    this.completedAt,
  });

  final String habitId;
  final String dateKey;
  final int count;
  final bool isCompleted;
  final DateTime? completedAt;

  HabitDailyLog copyWith({
    int? count,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return HabitDailyLog(
      habitId: habitId,
      dateKey: dateKey,
      count: count ?? this.count,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'habitId': habitId,
        'dateKey': dateKey,
        'count': count,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
      };

  static HabitDailyLog? tryDecode(Map<String, Object?> map) {
    final habitId = map['habitId'] as String? ?? '';
    final dateKey = map['dateKey'] as String? ?? '';
    if (habitId.isEmpty || dateKey.isEmpty) return null;
    return HabitDailyLog(
      habitId: habitId,
      dateKey: dateKey,
      count: (map['count'] as int?) ?? 0,
      isCompleted: (map['isCompleted'] as bool?) ?? false,
      completedAt: DateTime.tryParse((map['completedAt'] as String?) ?? ''),
    );
  }
}

@immutable
class HabitStreak {
  const HabitStreak({
    required this.habitId,
    required this.currentStreak,
    this.lastCompletedDateKey,
  });

  const HabitStreak.empty(String habitId)
      : this(habitId: habitId, currentStreak: 0);

  final String habitId;
  final int currentStreak;
  final String? lastCompletedDateKey;

  Map<String, Object?> toJson() => {
        'habitId': habitId,
        'currentStreak': currentStreak,
        'lastCompletedDateKey': lastCompletedDateKey,
      };

  static HabitStreak? tryDecode(Map<String, Object?> map) {
    final habitId = map['habitId'] as String? ?? '';
    if (habitId.isEmpty) return null;
    return HabitStreak(
      habitId: habitId,
      currentStreak: (map['currentStreak'] as int?) ?? 0,
      lastCompletedDateKey: map['lastCompletedDateKey'] as String?,
    );
  }
}
