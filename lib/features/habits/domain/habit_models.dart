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
    required this.category,
    required this.title,
    required this.description,
    required this.iconKey,
    required this.defaultColor,
    required this.defaultFrequency,
    required this.isCountable,
    this.defaultGoalDays,
    this.defaultForever = false,
    this.defaultTargetCount,
  });

  final String templateId;
  String get id => templateId;
  final String category;
  final String title;
  final String description;
  final String iconKey;
  final int defaultColor;
  final HabitFrequency defaultFrequency;
  final bool isCountable;
  final int? defaultGoalDays;
  final bool defaultForever;
  final int? defaultTargetCount;

  // Backward-compatible aliases used by existing UI.
  String get name => title;
  String get subtitle => description;
  int get colorArgb => defaultColor;
  bool get defaultIsCountable => isCountable;

  HabitCreationConfig defaultConfig() {
    return HabitCreationConfig(
      frequency: defaultFrequency,
      isCountable: isCountable,
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
      colorArgb: defaultColor,
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

const int _sugeridoColor = 0xFF4FC3F7;
const int _vidaColor = 0xFF7E57C2;
const int _saludColor = 0xFF66BB6A;
const int _deportesColor = 0xFFFF7043;
const int _mentalidadColor = 0xFFAB47BC;

const List<HabitTemplate> kHabitTemplates = [
  // Sugerido (10)
  HabitTemplate(templateId: 'daily_check', category: 'Sugerido', title: 'Chequeo diario', description: 'Reflexión rápida para cerrar el día.', iconKey: 'smile', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'drink_water', category: 'Sugerido', title: 'Beber agua', description: 'Hidratate durante toda la jornada.', iconKey: 'water', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: true, defaultForever: true, defaultTargetCount: 8),
  HabitTemplate(templateId: 'daily_breakfast', category: 'Sugerido', title: 'Desayunar', description: 'Comenzá con energía todas las mañanas.', iconKey: 'breakfast', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'suggested_walk_30', category: 'Sugerido', title: 'Caminar 30 min', description: 'Suma pasos y despejá la mente.', iconKey: 'walk', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'suggested_steps_8k', category: 'Sugerido', title: 'Pasos diarios', description: 'Objetivo de 8.000 pasos al día.', iconKey: 'steps', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: true, defaultForever: true, defaultTargetCount: 8000),
  HabitTemplate(templateId: 'suggested_sleep_7h', category: 'Sugerido', title: 'Dormir 7 horas', description: 'Priorizá descanso de calidad.', iconKey: 'sleep', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'suggested_read_15', category: 'Sugerido', title: 'Leer 15 minutos', description: 'Un bloque corto de lectura diaria.', iconKey: 'read', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'suggested_stretch', category: 'Sugerido', title: 'Estirar', description: 'Movilidad suave para iniciar el día.', iconKey: 'stretch', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'suggested_plan_day', category: 'Sugerido', title: 'Planificar el día', description: 'Definí 3 prioridades claras.', iconKey: 'plan', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'suggested_tidying', category: 'Sugerido', title: 'Orden rápido', description: '10 minutos para ordenar tu espacio.', iconKey: 'clean', defaultColor: _sugeridoColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),

  // Vida (10)
  HabitTemplate(templateId: 'life_daily_reading', category: 'Vida', title: 'Lectura diaria', description: '15 minutos de lectura sin distracciones.', iconKey: 'book', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'life_journal', category: 'Vida', title: 'Escribir diario', description: 'Registrá ideas y aprendizajes del día.', iconKey: 'journal', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'life_study_language', category: 'Vida', title: 'Practicar idioma', description: '10 minutos para expandir vocabulario.', iconKey: 'language', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 60),
  HabitTemplate(templateId: 'life_budget_review', category: 'Vida', title: 'Revisar gastos', description: 'Controlá tus finanzas personales.', iconKey: 'money', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'life_family_time', category: 'Vida', title: 'Tiempo en familia', description: 'Conectá sin pantallas al menos 20 minutos.', iconKey: 'family', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'life_home_order', category: 'Vida', title: 'Casa en orden', description: 'Una tarea doméstica al día.', iconKey: 'home', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'life_focus_block', category: 'Vida', title: 'Bloque de foco', description: '25 minutos de trabajo profundo.', iconKey: 'focus', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'life_digital_cleanup', category: 'Vida', title: 'Limpieza digital', description: 'Borrá archivos o correos innecesarios.', iconKey: 'laptop', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.weekly, isCountable: false, defaultGoalDays: 12),
  HabitTemplate(templateId: 'life_plan_week', category: 'Vida', title: 'Plan semanal', description: 'Organizá objetivos y agenda.', iconKey: 'calendar', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.weekly, isCountable: false, defaultGoalDays: 12),
  HabitTemplate(templateId: 'life_wake_early', category: 'Vida', title: 'Despertar temprano', description: 'Comenzá el día con margen de tiempo.', iconKey: 'alarm', defaultColor: _vidaColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),

  // Salud (10)
  HabitTemplate(templateId: 'health_eat_fruits', category: 'Salud', title: 'Comer frutas', description: 'Una porción de fruta por día.', iconKey: 'fruit', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'health_veggies', category: 'Salud', title: 'Comer verduras', description: 'Incluí vegetales en al menos una comida.', iconKey: 'salad', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'health_hydration_liters', category: 'Salud', title: 'Hidratación', description: 'Tomá 2 litros de agua por día.', iconKey: 'hydrate', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: true, defaultForever: true, defaultTargetCount: 8),
  HabitTemplate(templateId: 'health_sleep_routine', category: 'Salud', title: 'Rutina de sueño', description: 'Acostate a horario regular.', iconKey: 'moon', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'health_no_sugar', category: 'Salud', title: 'Reducir azúcar', description: 'Evitá bebidas y snacks azucarados.', iconKey: 'no_sugar', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'health_no_smoke', category: 'Salud', title: 'Sin fumar', description: 'Sostené un día libre de tabaco.', iconKey: 'no_smoke', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 60),
  HabitTemplate(templateId: 'health_vitamins', category: 'Salud', title: 'Tomar vitaminas', description: 'No olvides tus suplementos.', iconKey: 'supplements', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'health_walk_after_meal', category: 'Salud', title: 'Caminata post comida', description: '10 minutos para mejorar digestión.', iconKey: 'walk', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'health_medical_check', category: 'Salud', title: 'Chequeo médico', description: 'Seguimiento preventivo mensual.', iconKey: 'heart', defaultColor: _saludColor, defaultFrequency: HabitFrequency.monthly, isCountable: false, defaultGoalDays: 12),
  HabitTemplate(templateId: 'health_cook_home', category: 'Salud', title: 'Cocinar en casa', description: 'Prepará una comida casera saludable.', iconKey: 'cook', defaultColor: _saludColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),

  // Deportes (10)
  HabitTemplate(templateId: 'sports_train_workout', category: 'Deportes', title: 'Entrenamiento principal', description: 'Sesión completa para mejorar rendimiento.', iconKey: 'workout', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.weekly, isCountable: false, defaultGoalDays: 12),
  HabitTemplate(templateId: 'sports_run', category: 'Deportes', title: 'Salir a correr', description: 'Cardio suave o moderado.', iconKey: 'run', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'sports_steps_10k', category: 'Deportes', title: '10.000 pasos', description: 'Meta de pasos para mantener actividad.', iconKey: 'steps', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.daily, isCountable: true, defaultForever: true, defaultTargetCount: 10000),
  HabitTemplate(templateId: 'sports_pullups', category: 'Deportes', title: 'Dominadas', description: 'Sumá repeticiones de fuerza de tren superior.', iconKey: 'target', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.daily, isCountable: true, defaultTargetCount: 10, defaultGoalDays: 30),
  HabitTemplate(templateId: 'sports_stretching', category: 'Deportes', title: 'Movilidad y estiramiento', description: 'Prevención de lesiones y recuperación.', iconKey: 'stretch', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'sports_cycling', category: 'Deportes', title: 'Ciclismo', description: 'Pedaleá para ganar resistencia.', iconKey: 'bike', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.weekly, isCountable: false, defaultGoalDays: 16),
  HabitTemplate(templateId: 'sports_swimming', category: 'Deportes', title: 'Natación', description: 'Entrená técnica y capacidad aeróbica.', iconKey: 'swim', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.weekly, isCountable: false, defaultGoalDays: 16),
  HabitTemplate(templateId: 'sports_yoga', category: 'Deportes', title: 'Yoga', description: 'Fuerza, equilibrio y flexibilidad.', iconKey: 'yoga', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'sports_core', category: 'Deportes', title: 'Core 10 minutos', description: 'Trabajo de zona media y postura.', iconKey: 'timer', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'sports_recovery', category: 'Deportes', title: 'Recuperación activa', description: 'Movilidad ligera y descarga muscular.', iconKey: 'heart', defaultColor: _deportesColor, defaultFrequency: HabitFrequency.weekly, isCountable: false, defaultGoalDays: 12),

  // Mentalidad (10)
  HabitTemplate(templateId: 'mind_daily_meditation', category: 'Mentalidad', title: 'Meditar', description: 'Respiración consciente y foco mental.', iconKey: 'meditate', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_gratitude', category: 'Mentalidad', title: 'Gratitud diaria', description: 'Anotá 3 cosas por agradecer.', iconKey: 'gratitude', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_visualization', category: 'Mentalidad', title: 'Visualización', description: 'Visualizá tus objetivos por 5 minutos.', iconKey: 'target', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'mind_affirmations', category: 'Mentalidad', title: 'Afirmaciones', description: 'Reforzá creencias positivas cada mañana.', iconKey: 'sun', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
  HabitTemplate(templateId: 'mind_digital_detox', category: 'Mentalidad', title: 'Detox digital', description: '60 minutos sin redes sociales.', iconKey: 'laptop', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_breathing', category: 'Mentalidad', title: 'Respiración guiada', description: 'Pausa de 5 minutos para regular estrés.', iconKey: 'mind', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_no_complaints', category: 'Mentalidad', title: 'Día sin quejas', description: 'Practicar lenguaje constructivo.', iconKey: 'smile', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_reflection', category: 'Mentalidad', title: 'Reflexión nocturna', description: 'Repasá logros y mejoras del día.', iconKey: 'journal', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_focus_session', category: 'Mentalidad', title: 'Sesión de concentración', description: '25 minutos sin interrupciones.', iconKey: 'focus', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 21),
  HabitTemplate(templateId: 'mind_learn_new', category: 'Mentalidad', title: 'Aprender algo nuevo', description: 'Un micro aprendizaje diario.', iconKey: 'brain', defaultColor: _mentalidadColor, defaultFrequency: HabitFrequency.daily, isCountable: false, defaultGoalDays: 30),
];

IconData iconForKey(String key) => _iconDataByKey[key] ?? Icons.auto_awesome_rounded;
