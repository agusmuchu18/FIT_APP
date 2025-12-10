class WorkoutEntry {
  WorkoutEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.intensity,
    this.notes,
    this.template,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final String intensity;
  final String? notes;
  final String? template;

  WorkoutEntry copyWith({
    String? name,
    int? durationMinutes,
    String? intensity,
    String? notes,
    String? template,
  }) {
    return WorkoutEntry(
      id: id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      template: template ?? this.template,
    );
  }
}

class MealEntry {
  MealEntry({
    required this.id,
    required this.title,
    required this.calories,
    required this.macros,
    this.template,
    this.notes,
  });

  final String id;
  final String title;
  final int calories;
  final Macros macros;
  final String? template;
  final String? notes;

  MealEntry copyWith({
    String? title,
    int? calories,
    Macros? macros,
    String? template,
    String? notes,
  }) {
    return MealEntry(
      id: id,
      title: title ?? this.title,
      calories: calories ?? this.calories,
      macros: macros ?? this.macros,
      template: template ?? this.template,
      notes: notes ?? this.notes,
    );
  }
}

class Macros {
  Macros({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final int carbs;
  final int protein;
  final int fat;
}

class SleepEntry {
  SleepEntry({
    required this.id,
    required this.hours,
    required this.quality,
    this.notes,
    this.template,
    this.bedtime,
    this.wakeTime,
    this.screenUsageBeforeSleep,
    this.stressLevel,
    this.wakeEnergy,
  });

  final String id;
  final double hours;
  final String quality;
  final String? notes;
  final String? template;
  final String? bedtime;
  final String? wakeTime;
  final bool? screenUsageBeforeSleep;
  final int? stressLevel;
  final int? wakeEnergy;

  SleepEntry copyWith({
    double? hours,
    String? quality,
    String? notes,
    String? template,
    String? bedtime,
    String? wakeTime,
    bool? screenUsageBeforeSleep,
    int? stressLevel,
    int? wakeEnergy,
  }) {
    return SleepEntry(
      id: id,
      hours: hours ?? this.hours,
      quality: quality ?? this.quality,
      notes: notes ?? this.notes,
      template: template ?? this.template,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      screenUsageBeforeSleep:
          screenUsageBeforeSleep ?? this.screenUsageBeforeSleep,
      stressLevel: stressLevel ?? this.stressLevel,
      wakeEnergy: wakeEnergy ?? this.wakeEnergy,
    );
  }
}

class UserPreferences {
  UserPreferences({
    required this.id,
    required this.dailyStepGoal,
    required this.targetCalories,
    required this.preferredSleep,
  });

  final String id;
  final int dailyStepGoal;
  final int targetCalories;
  final double preferredSleep;

  UserPreferences copyWith({
    int? dailyStepGoal,
    int? targetCalories,
    double? preferredSleep,
  }) {
    return UserPreferences(
      id: id,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      targetCalories: targetCalories ?? this.targetCalories,
      preferredSleep: preferredSleep ?? this.preferredSleep,
    );
  }
}
