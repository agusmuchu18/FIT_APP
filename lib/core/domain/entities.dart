import 'package:meta/meta.dart';

/// World-class domain entities for an offline-first, multi-device, conflict-safe app.
///
/// Key upgrades vs “simple entities”:
/// - Standard sync metadata on every entity (createdAt, updatedAt, deleted, revision, deviceId)
/// - Stable JSON serialization (toJson/fromJson) for remote sync + local persistence
/// - Immutability + copyWith everywhere
/// - Tombstone deletes (deleted=true) to sync deletions safely
///
/// Notes:
/// - I kept your existing field types to avoid breaking your UI (e.g. bedtime/wakeTime are still String?).
/// - If you later want “perfect” typing (bedtime/wakeTime as DateTime?), we can migrate safely with adapters.

@immutable
class EntityMeta {
  const EntityMeta({
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    required this.revision,
    this.deviceId,
  });

  /// When the entity was first created (client-side or server-side).
  final DateTime createdAt;

  /// When the entity was last modified.
  final DateTime updatedAt;

  /// Tombstone flag (for delete sync without losing history).
  final bool deleted;

  /// Monotonic version. Increment on each mutation.
  /// In a real backend you can replace or augment this with ETag / serverRevision.
  final int revision;

  /// Optional device id (useful for debugging/conflict inspection).
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

  /// “Touch” the metadata for a local update.
  EntityMeta touched({String? deviceId}) {
    return copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: revision + 1,
      deviceId: deviceId ?? this.deviceId,
    );
  }

  /// Mark as deleted (tombstone) for sync.
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
    return EntityMeta(
      createdAt: _readDate(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: _readDate(json['updatedAt']) ?? DateTime.now().toUtc(),
      deleted: _readBool(json['deleted']) ?? false,
      revision: _readInt(json['revision']) ?? 1,
      deviceId: json['deviceId'] as String?,
    );
  }
}

/// Base contract for all syncable entities.
abstract class SyncEntity {
  String get id;
  EntityMeta get meta;

  /// Convenience: used by adapters.
  DateTime get updatedAt => meta.updatedAt;
  bool get deleted => meta.deleted;
}

/// ------------------------------
/// Workout
/// ------------------------------

@immutable
class WorkoutEntry implements SyncEntity {
  const WorkoutEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.intensity,
    this.notes,
    this.template,
    required this.meta,
  });

  /// Create a brand new entity with fresh metadata.
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

  @override
  bool operator ==(Object other) {
    return other is WorkoutEntry &&
        other.id == id &&
        other.name == name &&
        other.durationMinutes == durationMinutes &&
        other.intensity == intensity &&
        other.notes == notes &&
        other.template == template &&
        other.meta.createdAt == meta.createdAt &&
        other.meta.updatedAt == meta.updatedAt &&
        other.meta.deleted == meta.deleted &&
        other.meta.revision == meta.revision &&
        other.meta.deviceId == meta.deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        durationMinutes,
        intensity,
        notes,
        template,
        meta.createdAt,
        meta.updatedAt,
        meta.deleted,
        meta.revision,
        meta.deviceId,
      );
}

/// ------------------------------
/// Meal + Macros
/// ------------------------------

@immutable
class MealEntry implements SyncEntity {
  const MealEntry({
    required this.id,
    required this.title,
    required this.calories,
    required this.macros,
    this.template,
    this.notes,
    required this.meta,
  });

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

  @override
  bool operator ==(Object other) {
    return other is MealEntry &&
        other.id == id &&
        other.title == title &&
        other.calories == calories &&
        other.macros == macros &&
        other.template == template &&
        other.notes == notes &&
        other.meta.createdAt == meta.createdAt &&
        other.meta.updatedAt == meta.updatedAt &&
        other.meta.deleted == meta.deleted &&
        other.meta.revision == meta.revision &&
        other.meta.deviceId == meta.deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        calories,
        macros,
        template,
        notes,
        meta.createdAt,
        meta.updatedAt,
        meta.deleted,
        meta.revision,
        meta.deviceId,
      );
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

  @override
  bool operator ==(Object other) {
    return other is Macros && other.carbs == carbs && other.protein == protein && other.fat == fat;
  }

  @override
  int get hashCode => Object.hash(carbs, protein, fat);
}

/// ------------------------------
/// Sleep
/// ------------------------------

@immutable
class SleepEntry implements SyncEntity {
  const SleepEntry({
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
    required this.meta,
  });

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
      meta: EntityMeta.now(deviceId: deviceId),
    );
  }

  @override
  final String id;
  final double hours;
  final String quality;
  final String? notes;
  final String? template;

  /// Keep as String? for compatibility. Recommended format: ISO 8601.
  final String? bedtime;
  final String? wakeTime;

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
      screenUsageBeforeSleep: screenUsageBeforeSleep ?? this.screenUsageBeforeSleep,
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
        'screenUsageBeforeSleep': screenUsageBeforeSleep,
        'stressLevel': stressLevel,
        'wakeEnergy': wakeEnergy,
        '_meta': meta.toJson(),
      };

  factory SleepEntry.fromJson(Map<String, Object?> json) {
    return SleepEntry(
      id: (json['id'] as String?) ?? '',
      hours: _readDouble(json['hours']) ?? 0.0,
      quality: (json['quality'] as String?) ?? '',
      notes: json['notes'] as String?,
      template: json['template'] as String?,
      bedtime: json['bedtime'] as String?,
      wakeTime: json['wakeTime'] as String?,
      screenUsageBeforeSleep: _readBool(json['screenUsageBeforeSleep']),
      stressLevel: _readInt(json['stressLevel']),
      wakeEnergy: _readInt(json['wakeEnergy']),
      meta: EntityMeta.fromJson(_readMap(json['_meta'])),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SleepEntry &&
        other.id == id &&
        other.hours == hours &&
        other.quality == quality &&
        other.notes == notes &&
        other.template == template &&
        other.bedtime == bedtime &&
        other.wakeTime == wakeTime &&
        other.screenUsageBeforeSleep == screenUsageBeforeSleep &&
        other.stressLevel == stressLevel &&
        other.wakeEnergy == wakeEnergy &&
        other.meta.createdAt == meta.createdAt &&
        other.meta.updatedAt == meta.updatedAt &&
        other.meta.deleted == meta.deleted &&
        other.meta.revision == meta.revision &&
        other.meta.deviceId == meta.deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        hours,
        quality,
        notes,
        template,
        bedtime,
        wakeTime,
        screenUsageBeforeSleep,
        stressLevel,
        wakeEnergy,
        meta.createdAt,
        meta.updatedAt,
        meta.deleted,
        meta.revision,
        meta.deviceId,
      );
}

/// ------------------------------
/// User Preferences
/// ------------------------------

@immutable
class UserPreferences implements SyncEntity {
  const UserPreferences({
    required this.id,
    required this.primaryGoal,
    required this.experienceLevel,
    required this.targetSessionsPerWeek,
    required this.modePreference,
    this.dailyStepGoal,
    this.targetCalories,
    this.preferredSleep,
    required this.meta,
  });

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
      targetSessionsPerWeek: targetSessionsPerWeek ?? this.targetSessionsPerWeek,
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

  @override
  bool operator ==(Object other) {
    return other is UserPreferences &&
        other.id == id &&
        other.primaryGoal == primaryGoal &&
        other.experienceLevel == experienceLevel &&
        other.targetSessionsPerWeek == targetSessionsPerWeek &&
        other.modePreference == modePreference &&
        other.dailyStepGoal == dailyStepGoal &&
        other.targetCalories == targetCalories &&
        other.preferredSleep == preferredSleep &&
        other.meta.createdAt == meta.createdAt &&
        other.meta.updatedAt == meta.updatedAt &&
        other.meta.deleted == meta.deleted &&
        other.meta.revision == meta.revision &&
        other.meta.deviceId == meta.deviceId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        primaryGoal,
        experienceLevel,
        targetSessionsPerWeek,
        modePreference,
        dailyStepGoal,
        targetCalories,
        preferredSleep,
        meta.createdAt,
        meta.updatedAt,
        meta.deleted,
        meta.revision,
        meta.deviceId,
      );
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
  if (v is String) {
    final s = v.toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  if (v is num) return v != 0;
  return null;
}

DateTime? _readDate(Object? v) {
  if (v is DateTime) return v.toUtc();
  if (v is String) return DateTime.tryParse(v)?.toUtc();
  return null;
}
