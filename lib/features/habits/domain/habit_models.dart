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
  }) {
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
  }) {
    final forever = isForever ?? this.isForever;
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
    );
  }
}

@immutable
class HabitTemplate {
  const HabitTemplate({
    required this.id,
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

  final String id;
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
    id: 'daily-check',
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
    id: 'water',
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
    id: 'breakfast',
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
    id: 'fruits',
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
    id: 'read',
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
    id: 'train',
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
    id: 'meditate',
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

IconData iconForKey(String key) {
  switch (key) {
    case 'water':
      return Icons.water_drop_rounded;
    case 'breakfast':
      return Icons.free_breakfast_rounded;
    case 'nutrition':
      return Icons.eco_rounded;
    case 'read':
      return Icons.menu_book_rounded;
    case 'workout':
      return Icons.fitness_center_rounded;
    case 'meditate':
      return Icons.self_improvement_rounded;
    case 'smile':
      return Icons.sentiment_satisfied_alt_rounded;
    case 'moon':
      return Icons.nightlight_round;
    case 'heart':
      return Icons.favorite_rounded;
    case 'spark':
    default:
      return Icons.auto_awesome_rounded;
  }
}
