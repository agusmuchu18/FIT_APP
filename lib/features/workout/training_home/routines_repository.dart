import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../pro/models/workout_models.dart';

class RoutinesRepository {
  RoutinesRepository({SharedPreferences? prefs}) : _prefs = prefs;

  static const templatesKey = 'pro_workout_templates';
  static final ValueNotifier<List<WorkoutTemplate>> _routinesNotifier = ValueNotifier<List<WorkoutTemplate>>([]);

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;

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
  }) async {
    await _ensurePrefs();
    final routines = _readTemplates();
    final template = WorkoutTemplate(
      id: _uuid.v4(),
      name: name,
      type: workoutType,
      origin: TemplateOrigin.user,
      activityName: activityName,
      exercises: exercises,
    );
    routines.add(template);
    await _persistTemplates(routines);
    return template;
  }

  Future<void> replaceRoutines(List<WorkoutTemplate> routines) async {
    await _ensurePrefs();
    await _persistTemplates(routines);
  }

  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  List<WorkoutTemplate> _readTemplates() {
    final raw = _prefs?.getString(templatesKey);
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _persistTemplates(List<WorkoutTemplate> routines) async {
    final payload = jsonEncode(routines.map((e) => e.toJson()).toList());
    await _prefs?.setString(templatesKey, payload);
    _routinesNotifier.value = List<WorkoutTemplate>.unmodifiable(routines);
  }
}
