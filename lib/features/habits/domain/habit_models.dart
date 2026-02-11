import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum HabitFrequency { daily, weekly, monthly }

extension HabitFrequencyX on HabitFrequency {
  String get label {
    switch (this) {
      case HabitFrequency.daily:
        return 'Diaria';
      case HabitFrequency.weekly:
        return 'Semanal';
      case HabitFrequency.monthly:
        return 'Mensual';
    }
  }

  String get storageValue => name;

  static HabitFrequency fromStorage(String? value) {
    switch (value) {
      case 'weekly':
        return HabitFrequency.weekly;
      case 'monthly':
        return HabitFrequency.monthly;
      case 'daily':
      default:
        return HabitFrequency.daily;
    }
  }
}

DateTime normalizeHabitDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

const Set<int> kDefaultActiveWeekdays = {1, 2, 3, 4, 5, 6, 7};

@immutable
class HabitIconOption {
  const HabitIconOption({required this.iconKey, required this.iconData});

  final String iconKey;
  final IconData iconData;
}

const List<HabitIconOption> kHabitIconOptions = [
  HabitIconOption(iconKey: 'spark', iconData: Icons.auto_awesome_rounded),
  HabitIconOption(iconKey: 'water', iconData: Icons.water_drop_rounded),
  HabitIconOption(iconKey: 'breakfast', iconData: Icons.free_breakfast_rounded),
  HabitIconOption(iconKey: 'nutrition', iconData: Icons.eco_rounded),
  HabitIconOption(iconKey: 'read', iconData: Icons.menu_book_rounded),
  HabitIconOption(iconKey: 'workout', iconData: Icons.fitness_center_rounded),
  HabitIconOption(iconKey: 'meditate', iconData: Icons.self_improvement_rounded),
  HabitIconOption(iconKey: 'smile', iconData: Icons.sentiment_satisfied_alt_rounded),
  HabitIconOption(iconKey: 'moon', iconData: Icons.nightlight_round),
  HabitIconOption(iconKey: 'heart', iconData: Icons.favorite_rounded),
  HabitIconOption(iconKey: 'run', iconData: Icons.directions_run_rounded),
  HabitIconOption(iconKey: 'walk', iconData: Icons.directions_walk_rounded),
  HabitIconOption(iconKey: 'bike', iconData: Icons.directions_bike_rounded),
  HabitIconOption(iconKey: 'swim', iconData: Icons.pool_rounded),
  HabitIconOption(iconKey: 'yoga', iconData: Icons.spa_rounded),
  HabitIconOption(iconKey: 'sleep', iconData: Icons.bedtime_rounded),
  HabitIconOption(iconKey: 'alarm', iconData: Icons.alarm_rounded),
  HabitIconOption(iconKey: 'journal', iconData: Icons.edit_note_rounded),
  HabitIconOption(iconKey: 'study', iconData: Icons.school_rounded),
  HabitIconOption(iconKey: 'focus', iconData: Icons.center_focus_strong_rounded),
  HabitIconOption(iconKey: 'steps', iconData: Icons.directions_walk_rounded),
  HabitIconOption(iconKey: 'stretch', iconData: Icons.accessibility_new_rounded),
  HabitIconOption(iconKey: 'meal', iconData: Icons.restaurant_rounded),
  HabitIconOption(iconKey: 'salad', iconData: Icons.local_florist_rounded),
  HabitIconOption(iconKey: 'fruit', iconData: Icons.local_pizza_rounded),
  HabitIconOption(iconKey: 'cook', iconData: Icons.ramen_dining_rounded),
  HabitIconOption(iconKey: 'supplements', iconData: Icons.medication_rounded),
  HabitIconOption(iconKey: 'pill', iconData: Icons.vaccines_rounded),
  HabitIconOption(iconKey: 'mind', iconData: Icons.psychology_rounded),
  HabitIconOption(iconKey: 'brain', iconData: Icons.psychology_alt_rounded),
  HabitIconOption(iconKey: 'music', iconData: Icons.music_note_rounded),
  HabitIconOption(iconKey: 'podcast', iconData: Icons.headset_rounded),
  HabitIconOption(iconKey: 'clean', iconData: Icons.cleaning_services_rounded),
  HabitIconOption(iconKey: 'home', iconData: Icons.home_rounded),
  HabitIconOption(iconKey: 'plan', iconData: Icons.event_note_rounded),
  HabitIconOption(iconKey: 'calendar', iconData: Icons.calendar_month_rounded),
  HabitIconOption(iconKey: 'sun', iconData: Icons.wb_sunny_rounded),
  HabitIconOption(iconKey: 'leaf', iconData: Icons.energy_savings_leaf_rounded),
  HabitIconOption(iconKey: 'drink', iconData: Icons.local_drink_rounded),
  HabitIconOption(iconKey: 'tea', iconData: Icons.emoji_food_beverage_rounded),
  HabitIconOption(iconKey: 'no_sugar', iconData: Icons.no_food_rounded),
  HabitIconOption(iconKey: 'no_smoke', iconData: Icons.smoke_free_rounded),
  HabitIconOption(iconKey: 'hydrate', iconData: Icons.opacity_rounded),
  HabitIconOption(iconKey: 'book', iconData: Icons.auto_stories_rounded),
  HabitIconOption(iconKey: 'language', iconData: Icons.language_rounded),
  HabitIconOption(iconKey: 'code', iconData: Icons.code_rounded),
  HabitIconOption(iconKey: 'laptop', iconData: Icons.laptop_chromebook_rounded),
  HabitIconOption(iconKey: 'pray', iconData: Icons.volunteer_activism_rounded),
  HabitIconOption(iconKey: 'gratitude', iconData: Icons.celebration_rounded),
  HabitIconOption(iconKey: 'target', iconData: Icons.track_changes_rounded),
  HabitIconOption(iconKey: 'timer', iconData: Icons.timer_rounded),
  HabitIconOption(iconKey: 'checklist', iconData: Icons.checklist_rounded),
  HabitIconOption(iconKey: 'brush', iconData: Icons.brush_rounded),
  HabitIconOption(iconKey: 'camera', iconData: Icons.photo_camera_rounded),
  HabitIconOption(iconKey: 'family', iconData: Icons.groups_rounded),
  HabitIconOption(iconKey: 'pet', iconData: Icons.pets_rounded),
  HabitIconOption(iconKey: 'travel', iconData: Icons.flight_takeoff_rounded),
  HabitIconOption(iconKey: 'money', iconData: Icons.savings_rounded),
  HabitIconOption(iconKey: 'work', iconData: Icons.work_rounded),
];

final Map<String, IconData> _iconDataByKey = {
  for (final option in kHabitIconOptions) option.iconKey: option.iconData,
};

@immutable
class HabitEntry {
  HabitEntry({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorArgb,
    required this.category,
    required this.frequency,
    required this.isCountable,
    required this.goalDays,
    required this.isForever,
    required this.createdAt,
    required this.startDate,
    required this.activeWeekdays,
    required this.intervalWeeks,
    required this.dayOfMonth,
    required this.adjustToLastDayIfMissing,
    this.sourceTemplateId,
    this.targetCount,
    this.subtitle,
  });

  factory HabitEntry.create({
    required String name,
    required String iconKey,
    required int colorArgb,
    required String category,
    HabitFrequency frequency = HabitFrequency.daily,
    bool isCountable = false,
    int? goalDays = 21,
    bool isForever = false,
    int? targetCount,
    String? subtitle,
    DateTime? startDate,
    Set<int>? activeWeekdays,
    int intervalWeeks = 1,
    int? dayOfMonth,
    bool adjustToLastDayIfMissing = true,
    String? sourceTemplateId,
  }) {
    final normalizedStartDate = normalizeHabitDay(startDate ?? DateTime.now());
    return HabitEntry(
      id: const Uuid().v4(),
      name: name,
      iconKey: iconKey,
      colorArgb: colorArgb,
      category: category,
      frequency: frequency,
      isCountable: isCountable,
      goalDays: isForever ? null : (goalDays ?? 21),
      isForever: isForever,
      targetCount: targetCount,
      subtitle: subtitle,
      createdAt: DateTime.now().toUtc(),
      startDate: normalizedStartDate,
      activeWeekdays: _sanitizeWeekdays(activeWeekdays),
      intervalWeeks: intervalWeeks.clamp(1, 8),
      dayOfMonth: (dayOfMonth ?? normalizedStartDate.day).clamp(1, 31),
      adjustToLastDayIfMissing: adjustToLastDayIfMissing,
      sourceTemplateId: sourceTemplateId,
    );
  }

  final String id;
  final String name;
  final String iconKey;
  final int colorArgb;
  final String category;
  final HabitFrequency frequency;
  final bool isCountable;
  final int? goalDays;
  final bool isForever;
  final int? targetCount;
  final String? subtitle;
  final DateTime createdAt;
  final DateTime startDate;
  final Set<int> activeWeekdays;
  final int intervalWeeks;
  final int dayOfMonth;
  final bool adjustToLastDayIfMissing;
  final String? sourceTemplateId;

  HabitEntry copyWith({
    String? name,
    String? iconKey,
    int? colorArgb,
    String? category,
    HabitFrequency? frequency,
    bool? isCountable,
    int? goalDays,
    bool? isForever,
    int? targetCount,
    String? subtitle,
    DateTime? startDate,
    Set<int>? activeWeekdays,
    int? intervalWeeks,
    int? dayOfMonth,
    bool? adjustToLastDayIfMissing,
    String? sourceTemplateId,
  }) {
    final forever = isForever ?? this.isForever;
    final nextStartDate = normalizeHabitDay(startDate ?? this.startDate);
    return HabitEntry(
      id: id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorArgb: colorArgb ?? this.colorArgb,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      isCountable: isCountable ?? this.isCountable,
      goalDays: forever ? null : (goalDays ?? this.goalDays ?? 21),
      isForever: forever,
      targetCount: targetCount ?? this.targetCount,
      subtitle: subtitle ?? this.subtitle,
      createdAt: createdAt,
      startDate: nextStartDate,
      activeWeekdays: _sanitizeWeekdays(activeWeekdays ?? this.activeWeekdays),
      intervalWeeks: (intervalWeeks ?? this.intervalWeeks).clamp(1, 8),
      dayOfMonth: (dayOfMonth ?? this.dayOfMonth).clamp(1, 31),
      adjustToLastDayIfMissing: adjustToLastDayIfMissing ?? this.adjustToLastDayIfMissing,
      sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'colorArgb': colorArgb,
        'category': category,
        'frequency': frequency.storageValue,
        'isCountable': isCountable,
        'goalDays': goalDays,
        'isForever': isForever,
        'targetCount': targetCount,
        'subtitle': subtitle,
        'createdAt': createdAt.toIso8601String(),
        'startDate': startDate.toIso8601String(),
        'activeWeekdays': activeWeekdays.toList()..sort(),
        'intervalWeeks': intervalWeeks,
        'dayOfMonth': dayOfMonth,
        'adjustToLastDayIfMissing': adjustToLastDayIfMissing,
        'sourceTemplateId': sourceTemplateId,
      };

  static HabitEntry? tryDecode(Map<String, Object?> map) {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) {
      return null;
    }
    final countFromLegacy = map['targetCount'] is int
        ? map['targetCount'] as int
        : int.tryParse('${map['targetCount'] ?? ''}');
    final isCountable = (map['isCountable'] as bool?) ?? (countFromLegacy != null);
    final startDate = normalizeHabitDay(
      DateTime.tryParse(map['startDate'] as String? ?? '') ?? DateTime.now(),
    );
    final dayOfMonth = (map['dayOfMonth'] is int ? map['dayOfMonth'] as int : null) ?? startDate.day;

    return HabitEntry(
      id: id,
      name: map['name'] as String? ?? '',
      iconKey: map['iconKey'] as String? ?? 'spark',
      colorArgb: (map['colorArgb'] as int?) ?? 0xFF67D1FF,
      category: map['category'] as String? ?? 'Sugerido',
      frequency: HabitFrequencyX.fromStorage(map['frequency'] as String?),
      isCountable: isCountable,
      goalDays: (map['goalDays'] is int ? map['goalDays'] as int : null) ??
          ((map['isForever'] as bool? ?? false) ? null : 21),
      isForever: map['isForever'] as bool? ?? false,
      targetCount: countFromLegacy,
      subtitle: map['subtitle'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
      startDate: startDate,
      activeWeekdays: _sanitizeWeekdays(_decodeWeekdays(map['activeWeekdays'])),
      intervalWeeks: ((map['intervalWeeks'] is int ? map['intervalWeeks'] as int : 1) ?? 1).clamp(1, 8),
      dayOfMonth: dayOfMonth.clamp(1, 31),
      adjustToLastDayIfMissing: map['adjustToLastDayIfMissing'] as bool? ?? true,
      sourceTemplateId: map['sourceTemplateId'] as String?,
    );
  }
}

Set<int> _decodeWeekdays(Object? value) {
  if (value is List) {
    return value
        .map((item) => item is int ? item : int.tryParse('$item'))
        .whereType<int>()
        .toSet();
  }
  return kDefaultActiveWeekdays;
}

Set<int> _sanitizeWeekdays(Set<int>? weekdays) {
  final source = weekdays ?? kDefaultActiveWeekdays;
  final cleaned = source.where((day) => day >= 1 && day <= 7).toSet();
  return cleaned.isEmpty ? kDefaultActiveWeekdays : cleaned;
}

int _lastDayOfMonth(DateTime day) => DateTime(day.year, day.month + 1, 0).day;

bool shouldAppearOn(HabitEntry habit, DateTime day) {
  final targetDay = normalizeHabitDay(day);
  final startDay = normalizeHabitDay(habit.startDate);
  if (targetDay.isBefore(startDay)) {
    return false;
  }

  switch (habit.frequency) {
    case HabitFrequency.daily:
      return habit.activeWeekdays.contains(targetDay.weekday);
    case HabitFrequency.weekly:
      if (targetDay.weekday != startDay.weekday) {
        return false;
      }
      final weeksBetween = targetDay.difference(startDay).inDays ~/ 7;
      return weeksBetween % habit.intervalWeeks == 0;
    case HabitFrequency.monthly:
      final monthLastDay = _lastDayOfMonth(targetDay);
      if (habit.dayOfMonth <= monthLastDay) {
        return targetDay.day == habit.dayOfMonth;
      }
      return habit.adjustToLastDayIfMissing && targetDay.day == monthLastDay;
  }
}

@immutable
class HabitTemplate {
  const HabitTemplate({
    required this.templateId,
    required this.name,
    required this.subtitle,
    required this.iconKey,
    required this.colorArgb,
    required this.category,
    required this.defaultFrequency,
    required this.defaultIsCountable,
    this.defaultGoalDays,
    this.defaultForever = false,
    this.defaultTargetCount,
  });

  final String templateId;
  String get id => templateId;
  final String name;
  final String subtitle;
  final String iconKey;
  final int colorArgb;
  final String category;
  final HabitFrequency defaultFrequency;
  final bool defaultIsCountable;
  final int? defaultGoalDays;
  final bool defaultForever;
  final int? defaultTargetCount;

  HabitCreationConfig defaultConfig() {
    return HabitCreationConfig(
      frequency: defaultFrequency,
      isCountable: defaultIsCountable,
      targetCount: defaultTargetCount ?? 1,
      goalDays: defaultGoalDays,
      isForever: defaultForever,
    );
  }

  HabitEntry buildHabit({HabitCreationConfig? overrideConfig}) {
    final config = overrideConfig ?? defaultConfig();
    return HabitEntry.create(
      name: name,
      iconKey: iconKey,
      colorArgb: colorArgb,
      category: category,
      frequency: config.frequency,
      isCountable: config.isCountable,
      goalDays: config.goalDays,
      isForever: config.isForever,
      targetCount: config.isCountable ? config.targetCount : null,
      subtitle: subtitle,
      sourceTemplateId: templateId,
    );
  }
}

@immutable
class HabitCreationConfig {
  const HabitCreationConfig({
    required this.frequency,
    required this.isCountable,
    required this.targetCount,
    required this.goalDays,
    required this.isForever,
  });

  final HabitFrequency frequency;
  final bool isCountable;
  final int targetCount;
  final int? goalDays;
  final bool isForever;

  HabitCreationConfig copyWith({
    HabitFrequency? frequency,
    bool? isCountable,
    int? targetCount,
    int? goalDays,
    bool? isForever,
  }) {
    final forever = isForever ?? this.isForever;
    return HabitCreationConfig(
      frequency: frequency ?? this.frequency,
      isCountable: isCountable ?? this.isCountable,
      targetCount: targetCount ?? this.targetCount,
      goalDays: forever ? null : (goalDays ?? this.goalDays ?? 21),
      isForever: forever,
    );
  }
}

const List<String> habitCategories = [
  'Sugerido',
  'Vida',
  'Salud',
  'Deportes',
  'Mentalidad',
];

const List<HabitTemplate> kHabitTemplates = [
  HabitTemplate(
    templateId: 'daily_check',
    name: 'Chequeo diario',
    subtitle: 'Reflexión rápida para cerrar el día.',
    iconKey: 'smile',
    colorArgb: 0xFF60D394,
    category: 'Sugerido',
    defaultFrequency: HabitFrequency.daily,
    defaultIsCountable: false,
    defaultGoalDays: 21,
  ),
  HabitTemplate(
    templateId: 'drink_water',
    name: 'Beber agua',
    subtitle: 'Hidratate durante toda la jornada.',
    iconKey: 'water',
    colorArgb: 0xFF4FC3F7,
    category: 'Sugerido',
    defaultFrequency: HabitFrequency.daily,
    defaultIsCountable: true,
    defaultForever: true,
    defaultTargetCount: 8,
  ),
  HabitTemplate(
    templateId: 'daily_breakfast',
    name: 'Desayunar',
    subtitle: 'Comenzá con energía todas las mañanas.',
    iconKey: 'breakfast',
    colorArgb: 0xFFFFCA55,
    category: 'Sugerido',
    defaultFrequency: HabitFrequency.daily,
    defaultIsCountable: false,
    defaultGoalDays: 30,
  ),
  HabitTemplate(
    templateId: 'eat_fruits',
    name: 'Comer frutas',
    subtitle: 'Una porción de fruta por día.',
    iconKey: 'nutrition',
    colorArgb: 0xFF8BC34A,
    category: 'Salud',
    defaultFrequency: HabitFrequency.daily,
    defaultIsCountable: false,
    defaultGoalDays: 30,
  ),
  HabitTemplate(
    templateId: 'daily_reading',
    name: 'Leer',
    subtitle: '15 minutos de lectura sin distracciones.',
    iconKey: 'read',
    colorArgb: 0xFF64B5F6,
    category: 'Vida',
    defaultFrequency: HabitFrequency.daily,
    defaultIsCountable: false,
    defaultGoalDays: 21,
  ),
  HabitTemplate(
    templateId: 'train_workout',
    name: 'Entrenar',
    subtitle: 'Sesiones que eleven tu rendimiento.',
    iconKey: 'workout',
    colorArgb: 0xFF26A69A,
    category: 'Deportes',
    defaultFrequency: HabitFrequency.weekly,
    defaultIsCountable: false,
    defaultGoalDays: 12,
  ),
  HabitTemplate(
    templateId: 'daily_meditation',
    name: 'Meditar',
    subtitle: 'Respiración consciente y foco mental.',
    iconKey: 'meditate',
    colorArgb: 0xFF9C6ADE,
    category: 'Mentalidad',
    defaultFrequency: HabitFrequency.daily,
    defaultIsCountable: false,
    defaultGoalDays: 21,
  ),
];

IconData iconForKey(String key) => _iconDataByKey[key] ?? Icons.auto_awesome_rounded;
