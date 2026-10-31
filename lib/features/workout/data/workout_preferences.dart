import 'dart:convert';

import '../../../core/data/account_storage_scope.dart';

import 'package:flutter/foundation.dart';

import '../domain/training_units.dart';

class WorkoutPreferences {
  const WorkoutPreferences({
    this.defaultRestEnabled = false,
    this.defaultRestSeconds = 90,
    this.units = const TrainingUnits(),
    this.loadIncrementKg = 2.5,
  });

  static const storageKey = 'workout_preferences_v1';
  final bool defaultRestEnabled;
  final int defaultRestSeconds;
  final TrainingUnits units;
  final double loadIncrementKg;
  static final _notifiers = <String, ValueNotifier<WorkoutPreferences>>{};
  static ValueNotifier<WorkoutPreferences> watch(String owner) => _notifiers
      .putIfAbsent(owner, () => ValueNotifier(const WorkoutPreferences()));

  WorkoutPreferences copyWith({
    bool? defaultRestEnabled,
    int? defaultRestSeconds,
    TrainingUnits? units,
    double? loadIncrementKg,
  }) {
    return WorkoutPreferences(
      defaultRestEnabled: defaultRestEnabled ?? this.defaultRestEnabled,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      units: units ?? this.units,
      loadIncrementKg: loadIncrementKg ?? this.loadIncrementKg,
    );
  }

  static Future<WorkoutPreferences> load({String? scope}) async {
    final owner = scope ?? AccountStorageScope.current;
    final prefs = await ScopedPreferences.getInstance(scope: owner);
    final raw = prefs.getString(storageKey);
    if (raw == null) {
      watch(owner).value = const WorkoutPreferences();
      return const WorkoutPreferences();
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final seconds = json['defaultRestSeconds'] as int? ?? 90;
      final loaded = WorkoutPreferences(
        defaultRestEnabled: json['defaultRestEnabled'] as bool? ?? false,
        defaultRestSeconds: seconds > 0 && seconds <= 3600 ? seconds : 90,
        units: TrainingUnits(
          weight: WeightUnit.values.firstWhere(
            (u) => u.name == json['weightUnit'],
            orElse: () => WeightUnit.kg,
          ),
          distance: DistanceUnit.values.firstWhere(
            (u) => u.name == json['distanceUnit'],
            orElse: () => DistanceUnit.meters,
          ),
        ),
        loadIncrementKg:
            json['loadIncrementKg'] is num &&
                (json['loadIncrementKg'] as num).isFinite &&
                (json['loadIncrementKg'] as num) > 0
            ? (json['loadIncrementKg'] as num).toDouble()
            : 2.5,
      );
      watch(owner).value = loaded;
      return loaded;
    } catch (_) {
      watch(owner).value = const WorkoutPreferences();
      return const WorkoutPreferences();
    }
  }

  Future<void> save({String? scope}) async {
    if (!loadIncrementKg.isFinite ||
        loadIncrementKg <= 0 ||
        defaultRestSeconds < 1 ||
        defaultRestSeconds > 3600) {
      throw ArgumentError('Revisá los ajustes numéricos.');
    }
    final owner = scope ?? AccountStorageScope.current;
    final prefs = await ScopedPreferences.getInstance(scope: owner);
    final raw = prefs.getString(storageKey);
    final previous = raw == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (previous['schemaVersion'] != null && previous['schemaVersion'] != 1) {
      throw const FormatException(
        'Ajustes de una versión posterior; se conservan sin sobrescribir.',
      );
    }
    await prefs.setString(
      storageKey,
      jsonEncode({
        ...previous,
        'schemaVersion': 1,
        'defaultRestEnabled': defaultRestEnabled,
        'defaultRestSeconds': defaultRestSeconds,
        'weightUnit': units.weight.name,
        'distanceUnit': units.distance.name,
        'loadIncrementKg': loadIncrementKg,
      }),
    );
    watch(owner).value = this;
  }
}
