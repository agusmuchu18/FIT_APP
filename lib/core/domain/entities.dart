import 'package:flutter/foundation.dart';

/// ------------------------------
/// Sync metadata (offline-first / multi-device / conflict-safe)
/// ------------------------------

@immutable
class EntityMeta {
  const EntityMeta({
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.revision,
    this.deviceId,
  });

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  /// Monotonic version for conflict resolution / audit.
  final int revision;

  /// Optional device identifier for debugging / conflict inspection.
  final String? deviceId;

  factory EntityMeta.now({String? deviceId}) {
    final now = DateTime.now().toUtc();
    return EntityMeta(
      createdAt: now,
      updatedAt: now,
      deleted: false,
      revision: 1,
      deviceId: deviceId,
    );
  }

  EntityMeta copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? deleted,
    int? revision,
    String? deviceId,
  }) {
    return EntityMeta(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      revision: revision ?? this.revision,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  EntityMeta touched({String? deviceId}) {
    return copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: revision + 1,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  EntityMeta tombstoned({String? deviceId}) {
    return copyWith(
      updatedAt: DateTime.now().toUtc(),
      deleted: true,
      revision: revision + 1,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deleted': deleted,
        'revision': revision,
        'deviceId': deviceId,
      };

  factory EntityMeta.fromJson(Map<String, Object?> json) {
    final createdAt = _readDate(json['createdAt']) ?? DateTime.now().toUtc();
    final updatedAt = _readDate(json['updatedAt']) ?? createdAt;
    return EntityMeta(
      createdAt: createdAt,
      updatedAt: updatedAt,
      deleted: _readBool(json['deleted']) ?? false,
      revision: _readInt(json['revision']) ?? 1,
      deviceId: json['deviceId'] as String?,
    );
  }
}

/// Interface de entidad sincronizable.
/// Importante: si usás `implements`, tenés que implementar todo.
/// Para no repetir código, usamos el mixin SyncEntityMetaMixin.
abstract class SyncEntity {
  String get id;
  EntityMeta get meta;

  DateTime get updatedAt;
  bool get deleted;
}

/// Mixin que implementa updatedAt/deleted basado en meta.
/// Esto evita el error que viste (porque `implements` no hereda implementaciones).
mixin SyncEntityMetaMixin implements SyncEntity {
  @override
  DateTime get updatedAt => meta.updatedAt;

  @override
  bool get deleted => meta.deleted;
}

/// ------------------------------
/// WorkoutEntry
/// ------------------------------

@immutable
class WorkoutEntry with SyncEntityMetaMixin implements SyncEntity {
  /// Constructor compatible con tu código actual:
  /// - `meta` es opcional (si no lo pasás, se genera automáticamente).
  WorkoutEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.intensity,
    this.notes,
    this.template,
    EntityMeta? meta,
  }) : meta = meta ?? EntityMeta.now();

  /// Opcional: factory “semántica” para crear nuevo registro (idéntico al ctor).
  factory WorkoutEntry.create({
    required String id,
    required String name,
    required int durationMinutes,
    required String intensity,
    String? notes,
    String? template,
    String? deviceId,
  }) {
    return WorkoutEntry(
      id: id,
      name: name,
      durationMinutes: durationMinutes,
      intensity: intensity,
      notes: notes,
      template: template,
      meta: EntityMeta.now(deviceId: deviceId),
    );
  }

  @override
  final String id;
  final String name;
  final int durationMinutes;
  final String intensity;
  final String? notes;
  final String? template;

  @override
  final EntityMeta meta;

  WorkoutEntry copyWith({
    String? name,
    int? durationMinutes,
    String? intensity,
    String? notes,
    String? template,
    EntityMeta? meta,
    String? deviceIdForTouch,
  }) {
    return WorkoutEntry(
      id: id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      intensity: intensity ?? this.intensity,
      notes: notes ?? this.notes,
      template: template ?? this.template,
      meta: meta ?? this.meta.touched(deviceId: deviceIdForTouch),
    );
  }

  WorkoutEntry markDeleted({String? deviceId}) {
    return WorkoutEntry(
      id: id,
      name: name,
      durationMinutes: durationMinutes,
      intensity: intensity,
      notes: notes,
      template: template,
      meta: meta.tombstoned(deviceId: deviceId),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'durationMinutes': durationMinutes,
        'intensity': intensity,
        'notes': notes,
        'template': template,
        '_meta': meta.toJson(),
      };

  factory WorkoutEntry.fromJson(Map<String, Object?> json) {
    return WorkoutEntry(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      durationMinutes: _readInt(json['durationMinutes']) ?? 0,
      intensity: (json['intensity'] as String?) ?? '',
      notes: json['notes'] as String?,
      template: json['template'] as String?,
      meta: EntityMeta.fromJson(_readMap(json['_meta'])),
    );
  }
}

/// ------------------------------
/// MealEntry + Macros
/// ------------------------------

@immutable
class MealEntry with SyncEntityMetaMixin implements SyncEntity {
  MealEntry({
    required this.id,
    required this.title,
    required this.calories,
    required this.macros,
    this.template,
    this.notes,
    EntityMeta? meta,
  }) : meta = meta ?? EntityMeta.now();

  factory MealEntry.create({
    required String id,
    required String title,
    required int calories,
    required Macros macros,
    String? template,
    String? notes,
    String? deviceId,
  }) {
    return MealEntry(
      id: id,
      title: title,
      calories: calories,
      macros: macros,
      template: template,
      notes: notes,
      meta: EntityMeta.now(deviceId: deviceId),
    );
  }

  @override
  final String id;
  final String title;
  final int calories;
  final Macros macros;
  final String? template;
  final String? notes;

  @override
  final EntityMeta meta;

  MealEntry copyWith({
    String? title,
    int? calories,
    Macros? macros,
    String? template,
    String? notes,
    EntityMeta? meta,
    String? deviceIdForTouch,
  }) {
    return MealEntry(
      id: id,
      title: title ?? this.title,
      calories: calories ?? this.calories,
      macros: macros ?? this.macros,
      template: template ?? this.template,
      notes: notes ?? this.notes,
      meta: meta ?? this.meta.touched(deviceId: deviceIdForTouch),
    );
  }

  MealEntry markDeleted({String? deviceId}) {
    return MealEntry(
      id: id,
      title: title,
      calories: calories,
      macros: macros,
      template: template,
      notes: notes,
      meta: meta.tombstoned(deviceId: deviceId),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'calories': calories,
        'macros': macros.toJson(),
        'template': template,
        'notes': notes,
        '_meta': meta.toJson(),
      };

  factory MealEntry.fromJson(Map<String, Object?> json) {
    return MealEntry(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      calories: _readInt(json['calories']) ?? 0,
      macros: Macros.fromJson(_readMap(json['macros'])),
      template: json['template'] as String?,
      notes: json['notes'] as String?,
      meta: EntityMeta.fromJson(_readMap(json['_meta'])),
    );
  }
}

@immutable
class Macros {
  const Macros({
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  final int carbs;
  final int protein;
  final int fat;

  Macros copyWith({
    int? carbs,
    int? protein,
    int? fat,
  }) {
    return Macros(
      carbs: carbs ?? this.carbs,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'carbs': carbs,
        'protein': protein,
        'fat': fat,
      };

  factory Macros.fromJson(Map<String, Object?> json) {
    return Macros(
      carbs: _readInt(json['carbs']) ?? 0,
      protein: _readInt(json['protein']) ?? 0,
      fat: _readInt(json['fat']) ?? 0,
    );
  }
}

/// ------------------------------
/// SleepEntry
/// ------------------------------

@immutable
class SleepEntry with SyncEntityMetaMixin implements SyncEntity {
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
    this.napMinutes,
    this.sleepLatencyMinutes,
    this.awakenings,
    this.source,
    this.sleepDate,
    this.tags,
    this.qualityScore,
    EntityMeta? meta,
  }) : meta = meta ?? EntityMeta.now();

  factory SleepEntry.create({
    required String id,
    required double hours,
    required String quality,
    String? notes,
    String? template,
    String? bedtime,
    String? wakeTime,
    bool? screenUsageBeforeSleep,
    int? stressLevel,
    int? wakeEnergy,
    int? napMinutes,
    int? sleepLatencyMinutes,
    int? awakenings,
    String? source,
    String? sleepDate,
    List<String>? tags,
    int? qualityScore,
    String? deviceId,
  }) {
    return SleepEntry(
      id: id,
      hours: hours,
      quality: quality,
      notes: notes,
      template: template,
      bedtime: bedtime,
      wakeTime: wakeTime,
      screenUsageBeforeSleep: screenUsageBeforeSleep,
      stressLevel: stressLevel,
      wakeEnergy: wakeEnergy,
      napMinutes: napMinutes,
      sleepLatencyMinutes: sleepLatencyMinutes,
      awakenings: awakenings,
      source: source,
      sleepDate: sleepDate,
      tags: tags,
      qualityScore: qualityScore,
      meta: EntityMeta.now(deviceId: deviceId),
    );
  }

  @override
  final String id;
  final double hours;
  final String quality;
  final String? notes;
  final String? template;

  /// Mantengo String? para compatibilidad (ideal: ISO 8601).
  final String? bedtime;
  final String? wakeTime;

  /// ISO date (yyyy-MM-dd) representing wake-up day.
  final String? sleepDate;

  /// Minutes spent on naps.
  final int? napMinutes;

  /// Minutes it took to fall asleep.
  final int? sleepLatencyMinutes;

  /// Number of awakenings during the night.
  final int? awakenings;

  /// Source of the entry.
  final String? source;

  /// Quick habit tags.
  final List<String>? tags;

  /// Numerical quality score for calculations (1..5).
  final int? qualityScore;

  final bool? screenUsageBeforeSleep;
  final int? stressLevel;
  final int? wakeEnergy;

  @override
  final EntityMeta meta;

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
    int? napMinutes,
    int? sleepLatencyMinutes,
    int? awakenings,
    String? source,
    String? sleepDate,
    List<String>? tags,
    int? qualityScore,
    EntityMeta? meta,
    String? deviceIdForTouch,
  }) {
    return SleepEntry(
      id: id,
      hours: hours ?? this.hours,
      quality: quality ?? this.quality,
      notes: notes ?? this.notes,
      template: template ?? this.template,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      napMinutes: napMinutes ?? this.napMinutes,
      sleepLatencyMinutes: sleepLatencyMinutes ?? this.sleepLatencyMinutes,
      awakenings: awakenings ?? this.awakenings,
      source: source ?? this.source,
      sleepDate: sleepDate ?? this.sleepDate,
      tags: tags ?? this.tags,
      qualityScore: qualityScore ?? this.qualityScore,
      screenUsageBeforeSleep:
          screenUsageBeforeSleep ?? this.screenUsageBeforeSleep,
      stressLevel: stressLevel ?? this.stressLevel,
      wakeEnergy: wakeEnergy ?? this.wakeEnergy,
      meta: meta ?? this.meta.touched(deviceId: deviceIdForTouch),
    );
  }

  SleepEntry markDeleted({String? deviceId}) {
    return SleepEntry(
      id: id,
      hours: hours,
      quality: quality,
      notes: notes,
      template: template,
      bedtime: bedtime,
      wakeTime: wakeTime,
      napMinutes: napMinutes,
      sleepLatencyMinutes: sleepLatencyMinutes,
      awakenings: awakenings,
      source: source,
      sleepDate: sleepDate,
      tags: tags,
      qualityScore: qualityScore,
      screenUsageBeforeSleep: screenUsageBeforeSleep,
      stressLevel: stressLevel,
      wakeEnergy: wakeEnergy,
      meta: meta.tombstoned(deviceId: deviceId),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'hours': hours,
        'quality': quality,
        'notes': notes,
        'template': template,
        'bedtime': bedtime,
        'wakeTime': wakeTime,
        'sleepDate': sleepDate,
        'napMinutes': napMinutes,
        'sleepLatencyMinutes': sleepLatencyMinutes,
        'awakenings': awakenings,
        'source': source,
        'tags': tags,
        'qualityScore': qualityScore,
        'screenUsageBeforeSleep': screenUsageBeforeSleep,
        'stressLevel': stressLevel,
        'wakeEnergy': wakeEnergy,
        '_meta': meta.toJson(),
      };

  factory SleepEntry.fromJson(Map<String, Object?> json) {
    final id = (json['id'] as String?) ?? '';
    final meta = EntityMeta.fromJson(_readMap(json['_meta']));
    final parsedSleepDate = json['sleepDate'] as String?;
    final derivedDate = parsedSleepDate ??
        _deriveSleepDate(
          id: id,
          meta: meta,
        );
    final tagsJson = json['tags'];
    final tags = tagsJson is List
        ? tagsJson.whereType<String>().toList()
        : <String>[];
    final quality = (json['quality'] as String?) ?? '';
    final qualityScore = _readInt(json['qualityScore']) ??
        _mapQualityToScore(quality: quality);

    return SleepEntry(
      id: id,
      hours: _readDouble(json['hours']) ?? 0.0,
      quality: quality,
      notes: json['notes'] as String?,
      template: json['template'] as String?,
      bedtime: json['bedtime'] as String?,
      wakeTime: json['wakeTime'] as String?,
      napMinutes: _readInt(json['napMinutes']),
      sleepLatencyMinutes: _readInt(json['sleepLatencyMinutes']),
      awakenings: _readInt(json['awakenings']),
      source: json['source'] as String?,
      sleepDate: derivedDate,
      tags: tags,
      qualityScore: qualityScore,
      screenUsageBeforeSleep: _readBool(json['screenUsageBeforeSleep']),
      stressLevel: _readInt(json['stressLevel']),
      wakeEnergy: _readInt(json['wakeEnergy']),
      meta: meta,
    );
  }
}

String? _deriveSleepDate({required String id, required EntityMeta meta}) {
  final fromId = DateTime.tryParse(id);
  if (fromId != null) {
    final normalized = DateTime(fromId.year, fromId.month, fromId.day);
    return normalized.toIso8601String().split('T').first;
  }

  final updated = meta.updatedAt;
  return DateTime(updated.year, updated.month, updated.day)
      .toIso8601String()
      .split('T')
      .first;
}

int _mapQualityToScore({required String quality}) {
  final normalized = quality.toLowerCase();
  if (normalized.contains('excel')) return 5;
  if (normalized.contains('muy') || normalized.contains('buena')) return 4;
  if (normalized.contains('ok') || normalized.contains('normal')) return 3;
  if (normalized.contains('lig')) return 2;
  if (normalized.contains('mala')) return 1;
  return 3;
}

/// ------------------------------
/// UserPreferences
/// ------------------------------

@immutable
class UserPreferences with SyncEntityMetaMixin implements SyncEntity {
  UserPreferences({
    required this.id,
    required this.primaryGoal,
    required this.experienceLevel,
    required this.targetSessionsPerWeek,
    required this.modePreference,
    this.dailyStepGoal,
    this.targetCalories,
    this.preferredSleep,
    EntityMeta? meta,
  }) : meta = meta ?? EntityMeta.now();

  factory UserPreferences.create({
    required String id,
    required String primaryGoal,
    required String experienceLevel,
    required int targetSessionsPerWeek,
    required String modePreference,
    int? dailyStepGoal,
    int? targetCalories,
    double? preferredSleep,
    String? deviceId,
  }) {
    return UserPreferences(
      id: id,
      primaryGoal: primaryGoal,
      experienceLevel: experienceLevel,
      targetSessionsPerWeek: targetSessionsPerWeek,
      modePreference: modePreference,
      dailyStepGoal: dailyStepGoal,
      targetCalories: targetCalories,
      preferredSleep: preferredSleep,
      meta: EntityMeta.now(deviceId: deviceId),
    );
  }

  @override
  final String id;
  final String primaryGoal;
  final String experienceLevel;
  final int targetSessionsPerWeek;
  final String modePreference;
  final int? dailyStepGoal;
  final int? targetCalories;
  final double? preferredSleep;

  @override
  final EntityMeta meta;

  UserPreferences copyWith({
    String? primaryGoal,
    String? experienceLevel,
    int? targetSessionsPerWeek,
    String? modePreference,
    int? dailyStepGoal,
    int? targetCalories,
    double? preferredSleep,
    EntityMeta? meta,
    String? deviceIdForTouch,
  }) {
    return UserPreferences(
      id: id,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      targetSessionsPerWeek:
          targetSessionsPerWeek ?? this.targetSessionsPerWeek,
      modePreference: modePreference ?? this.modePreference,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      targetCalories: targetCalories ?? this.targetCalories,
      preferredSleep: preferredSleep ?? this.preferredSleep,
      meta: meta ?? this.meta.touched(deviceId: deviceIdForTouch),
    );
  }

  UserPreferences markDeleted({String? deviceId}) {
    return UserPreferences(
      id: id,
      primaryGoal: primaryGoal,
      experienceLevel: experienceLevel,
      targetSessionsPerWeek: targetSessionsPerWeek,
      modePreference: modePreference,
      dailyStepGoal: dailyStepGoal,
      targetCalories: targetCalories,
      preferredSleep: preferredSleep,
      meta: meta.tombstoned(deviceId: deviceId),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'primaryGoal': primaryGoal,
        'experienceLevel': experienceLevel,
        'targetSessionsPerWeek': targetSessionsPerWeek,
        'modePreference': modePreference,
        'dailyStepGoal': dailyStepGoal,
        'targetCalories': targetCalories,
        'preferredSleep': preferredSleep,
        '_meta': meta.toJson(),
      };

  factory UserPreferences.fromJson(Map<String, Object?> json) {
    return UserPreferences(
      id: (json['id'] as String?) ?? '',
      primaryGoal: (json['primaryGoal'] as String?) ?? '',
      experienceLevel: (json['experienceLevel'] as String?) ?? '',
      targetSessionsPerWeek: _readInt(json['targetSessionsPerWeek']) ?? 0,
      modePreference: (json['modePreference'] as String?) ?? '',
      dailyStepGoal: _readInt(json['dailyStepGoal']),
      targetCalories: _readInt(json['targetCalories']),
      preferredSleep: _readDouble(json['preferredSleep']),
      meta: EntityMeta.fromJson(_readMap(json['_meta'])),
    );
  }
}

/// ------------------------------
/// JSON helpers (defensive parsing)
/// ------------------------------

Map<String, Object?> _readMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return const <String, Object?>{};
}

int? _readInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _readDouble(Object? v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool? _readBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}

DateTime? _readDate(Object? v) {
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}
