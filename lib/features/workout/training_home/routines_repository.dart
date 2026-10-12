import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/account_storage_scope.dart';

import 'package:uuid/uuid.dart';

import '../pro/models/workout_models.dart';

class RoutinesRepository {
  RoutinesRepository({SharedPreferences? prefs})
    : _scope = AccountStorageScope.current,
      _prefs = prefs == null ? null : ScopedPreferences(prefs);
  final String _scope;

  static const templatesKey = 'pro_workout_templates';
  static final Map<String, ValueNotifier<List<WorkoutTemplate>>> _notifiers =
      {};
  ValueNotifier<List<WorkoutTemplate>> get _routinesNotifier => _notifiers
      .putIfAbsent(_scope, () => ValueNotifier<List<WorkoutTemplate>>([]));
  static final Map<String, Future<void>> _writes = {};

  Future<T> _serialize<T>(Future<T> Function() action) async {
    final previous = _writes[_scope];
    final gate = Completer<void>();
    _writes[_scope] = gate.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      if (identical(_writes[_scope], gate.future)) _writes.remove(_scope);
      gate.complete();
    }
  }

  final Uuid _uuid = const Uuid();
  ScopedPreferences? _prefs;

  Future<List<WorkoutTemplate>> getAllRoutines() async {
    await _ensurePrefs();
    final decoded = _readTemplates();
    _routinesNotifier.value = decoded;
    return decoded;
  }

  ValueListenable<List<WorkoutTemplate>> watchRoutines() => _routinesNotifier;

  Future<WorkoutTemplate> saveRoutine({
    required String name,
    required WorkoutType workoutType,
    required List<WorkoutExercise> exercises,
    String? activityName,
    String? folderId,
  }) => _serialize(() async {
    await _ensurePrefs();
    final routines = _readTemplates();
    final template = WorkoutTemplate(
      id: _uuid.v4(),
      name: name,
      type: workoutType,
      origin: TemplateOrigin.user,
      activityName: activityName,
      folderId: folderId,
      exercises: exercises,
    );
    routines.add(template);
    await _persistTemplates(routines);
    return template;
  });

  Future<void> replaceRoutines(List<WorkoutTemplate> routines) =>
      _serialize(() async {
        await _ensurePrefs();
        await _persistTemplates(routines);
      });

  Future<void> _ensurePrefs() async {
    _prefs ??= await ScopedPreferences.getInstance(scope: _scope);
  }

  List<WorkoutTemplate> _readTemplates() {
    final raw = _prefs?.getString(templatesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persistTemplates(List<WorkoutTemplate> routines) async {
    final payload = jsonEncode(routines.map((e) => e.toJson()).toList());
    await _prefs?.setString(templatesKey, payload);
    _routinesNotifier.value = List<WorkoutTemplate>.unmodifiable(routines);
  }
}
