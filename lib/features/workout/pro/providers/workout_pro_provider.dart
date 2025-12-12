import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/workout_models.dart';

class WorkoutProProvider extends ChangeNotifier {
  WorkoutProProvider();

  static const _sessionsKey = 'pro_workout_sessions';
  static const _templatesKey = 'pro_workout_templates';
  static const _recentExercisesKey = 'pro_recent_exercises';

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;

  WorkoutType _selectedType = WorkoutType.strength;
  String? _customTypeName;
  WorkoutTemplate? _selectedTemplate;
  List<WorkoutTemplate> _userTemplates = [];
  final List<WorkoutTemplate> _standardTemplates = _buildStandardTemplates();

  // Strength specific
  List<WorkoutExercise> _exercises = [];

  // Simple modalities
  String? _activityName;
  int? _durationMinutes;
  double? _distanceKm;
  String? _pace;
  int _rpe = 6;
  int _fatigue = 3;
  String? _notes;

  // Closing
  int? _closingDuration;
  int _closingFatigue = 3;
  int _closingPerformance = 3;
  String? _finalNotes;

  List<String> _recentExercises = [];
  List<WorkoutSession> _storedSessions = [];

  bool _initialized = false;
  bool get initialized => _initialized;

  WorkoutType get selectedType => _selectedType;
  String? get customTypeName => _customTypeName;
  WorkoutTemplate? get selectedTemplate => _selectedTemplate;
  List<WorkoutTemplate> get userTemplates => _userTemplates;
  List<WorkoutTemplate> get standardTemplates => _standardTemplates;
  List<WorkoutExercise> get exercises => _exercises;
  String? get activityName => _activityName;
  int? get durationMinutes => _durationMinutes;
  double? get distanceKm => _distanceKm;
  String? get pace => _pace;
  int get rpe => _rpe;
  int get fatigue => _fatigue;
  String? get notes => _notes;
  int? get closingDuration => _closingDuration;
  int get closingFatigue => _closingFatigue;
  int get closingPerformance => _closingPerformance;
  String? get finalNotes => _finalNotes;
  List<String> get recentExercises => _recentExercises;
  List<WorkoutSession> get storedSessions => _storedSessions;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadTemplates();
    await _loadRecentExercises();
    await _loadSessions();
    _initialized = true;
    notifyListeners();
  }

  void setType(WorkoutType type, {bool force = false}) {
    if (!force && _selectedType == WorkoutType.strength && type != WorkoutType.strength && _exercises.isNotEmpty) {
      return;
    }
    _selectedType = type;
    if (type != WorkoutType.custom) {
      _customTypeName = null;
    }
    if (type != WorkoutType.strength) {
      _exercises = [];
    }
    _selectedTemplate = null;
    notifyListeners();
  }

  void setCustomTypeName(String value) {
    _customTypeName = value;
    notifyListeners();
  }

  void setActivityName(String? value) {
    _activityName = value;
    notifyListeners();
  }

  void setDuration(int? value) {
    _durationMinutes = value;
    notifyListeners();
  }

  void setDistance(double? value) {
    _distanceKm = value;
    notifyListeners();
  }

  void setPace(String? value) {
    _pace = value;
    notifyListeners();
  }

  void setRpe(int value) {
    _rpe = value;
    notifyListeners();
  }

  void setFatigue(int value) {
    _fatigue = value;
    notifyListeners();
  }

  void setNotes(String? value) {
    _notes = value;
    notifyListeners();
  }

  void setClosingDuration(int? value) {
    _closingDuration = value;
    notifyListeners();
  }

  void setClosingFatigue(int value) {
    _closingFatigue = value;
    notifyListeners();
  }

  void setClosingPerformance(int value) {
    _closingPerformance = value;
    notifyListeners();
  }

  void setFinalNotes(String? value) {
    _finalNotes = value;
    notifyListeners();
  }

  void addExercise(WorkoutExercise exercise) {
    _exercises = [..._exercises, exercise];
    _rememberExercise(exercise.name);
    notifyListeners();
  }

  void duplicateExercise(String exerciseId) {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;
    final original = _exercises[index];
    final duplicated = original.copyWith(
      id: _uuid.v4(),
      name: '${original.name} (copy)',
      sets: original.sets
          .map((set) => set.copyWith(id: _uuid.v4()))
          .toList(),
    );
    _exercises = [..._exercises]..insert(index + 1, duplicated);
    notifyListeners();
  }

  void removeExercise(String exerciseId) {
    _exercises = _exercises.where((e) => e.id != exerciseId).toList();
    notifyListeners();
  }

  void updateExerciseNotes(String exerciseId, String? notes) {
    _exercises = _exercises
        .map((e) => e.id == exerciseId ? e.copyWith(notes: notes) : e)
        .toList();
    notifyListeners();
  }

  void addSet(String exerciseId) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId) {
        final newSet = SetEntry(id: _uuid.v4());
        return e.copyWith(sets: [...e.sets, newSet]);
      }
      return e;
    }).toList();
    notifyListeners();
  }

  void copyPreviousSet(String exerciseId) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId && e.sets.isNotEmpty) {
        final last = e.sets.last;
        final copied = last.copyWith(id: _uuid.v4());
        return e.copyWith(sets: [...e.sets, copied]);
      }
      return e;
    }).toList();
    notifyListeners();
  }

  void updateSet(String exerciseId, String setId, SetEntry updated) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId) {
        final updatedSets = e.sets
            .map((s) => s.id == setId ? updated : s)
            .toList();
        return e.copyWith(sets: updatedSets);
      }
      return e;
    }).toList();
    notifyListeners();
  }

  void removeSet(String exerciseId, String setId) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId) {
        return e.copyWith(
          sets: e.sets.where((s) => s.id != setId).toList(),
        );
      }
      return e;
    }).toList();
    notifyListeners();
  }

  void selectTemplate(WorkoutTemplate template) {
    _selectedTemplate = template;
    _applyTemplate(template);
    notifyListeners();
  }

  void clearTemplate() {
    _selectedTemplate = null;
    notifyListeners();
  }

  Future<void> saveTemplate(String name) async {
    final template = WorkoutTemplate(
      id: _uuid.v4(),
      name: name,
      type: _selectedType,
      origin: TemplateOrigin.user,
      activityName: _activityName,
      exercises: _selectedType == WorkoutType.strength
          ? _exercises
              .map(
                (e) => e.copyWith(
                  sets: e.sets
                      .map((s) => s.copyWith(id: _uuid.v4()))
                      .toList(),
                ),
              )
              .toList()
          : [],
    );
    _userTemplates = [..._userTemplates, template];
    await _persistTemplates();
    notifyListeners();
  }

  Future<void> reset() async {
    _selectedType = WorkoutType.strength;
    _customTypeName = null;
    _selectedTemplate = null;
    _exercises = [];
    _activityName = null;
    _durationMinutes = null;
    _distanceKm = null;
    _pace = null;
    _rpe = 6;
    _fatigue = 3;
    _notes = null;
    _closingDuration = null;
    _closingFatigue = 3;
    _closingPerformance = 3;
    _finalNotes = null;
    notifyListeners();
  }

  Future<bool> saveSession() async {
    if (_selectedType == WorkoutType.strength) {
      final hasExercise = _exercises.isNotEmpty;
      final hasSetWithData = _exercises.any(
        (e) => e.sets.any((s) => s.reps != null || s.durationSeconds != null),
      );
      if (!hasExercise || !hasSetWithData) {
        return false;
      }
    } else {
      if (_durationMinutes == null || _durationMinutes == 0) {
        return false;
      }
    }

    final session = WorkoutSession(
      id: _uuid.v4(),
      type: _selectedType,
      customTypeName: _customTypeName,
      templateId: _selectedTemplate?.id,
      templateName: _selectedTemplate?.name,
      date: DateTime.now(),
      activityName: _activityName,
      durationMinutes: _durationMinutes,
      distanceKm: _distanceKm,
      pace: _pace,
      rpe: _rpe,
      fatigue: _fatigue,
      notes: _notes,
      exercises: _selectedType == WorkoutType.strength ? _exercises : [],
      closingDuration: _closingDuration,
      closingFatigue: _closingFatigue,
      closingPerformance: _closingPerformance,
      finalNotes: _finalNotes,
    );

    _storedSessions = [..._storedSessions, session];
    await _persistSessions();
    return true;
  }

  String exportDebugJson() {
    final payload = {
      'sessions': _storedSessions.map((e) => e.toJson()).toList(),
      'templates': _userTemplates.map((e) => e.toJson()).toList(),
      'recentExercises': _recentExercises,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  int get totalExercises => _exercises.length;
  int get totalSets => _exercises.fold(0, (sum, e) => sum + e.sets.length);
  int get totalReps => _exercises.fold(
      0, (sum, e) => sum + e.sets.fold(0, (s, set) => s + (set.reps ?? 0)));
  double get totalVolume => _exercises.fold(
        0,
        (sum, e) =>
            sum +
            e.sets.fold(
                0,
                (s, set) =>
                    s + ((set.weight ?? 0) * (set.reps != null ? set.reps! : 0))),
      );
  double? get averageRir {
    final all = _exercises.expand((e) => e.sets).where((s) => s.rir != null);
    if (all.isEmpty) return null;
    final total = all.fold<int>(0, (sum, s) => sum + (s.rir ?? 0));
    return total / all.length;
  }

  String getDurationLabel() {
    final minutes = _closingDuration ?? _durationMinutes;
    if (minutes == null || minutes == 0) return '0m';
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  Future<void> _loadTemplates() async {
    final raw = _prefs?.getString(_templatesKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _userTemplates = decoded
          .map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _persistTemplates() async {
    final payload = jsonEncode(_userTemplates.map((e) => e.toJson()).toList());
    await _prefs?.setString(_templatesKey, payload);
  }

  Future<void> _loadRecentExercises() async {
    final stored = _prefs?.getStringList(_recentExercisesKey);
    if (stored != null) {
      _recentExercises = stored;
    }
  }

  Future<void> _rememberExercise(String name) async {
    final updated = [name, ..._recentExercises];
    _recentExercises = updated.toSet().take(10).toList();
    await _prefs?.setStringList(_recentExercisesKey, _recentExercises);
  }

  Future<void> _loadSessions() async {
    final raw = _prefs?.getString(_sessionsKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _storedSessions = decoded
          .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _persistSessions() async {
    final payload = jsonEncode(_storedSessions.map((e) => e.toJson()).toList());
    await _prefs?.setString(_sessionsKey, payload);
  }

  void _applyTemplate(WorkoutTemplate template) {
    setType(template.type, force: true);
    _selectedTemplate = template;
    _activityName = template.activityName;
    if (template.type == WorkoutType.strength) {
      _exercises = template.exercises
          .map(
            (e) => WorkoutExercise(
              id: _uuid.v4(),
              name: e.name,
              muscleGroup: e.muscleGroup,
              measurement: e.measurement,
              notes: e.notes,
              sets: e.sets
                  .map((s) => s.copyWith(id: _uuid.v4()))
                  .toList(),
            ),
          )
          .toList();
    }
    notifyListeners();
  }

  static List<WorkoutTemplate> _buildStandardTemplates() {
    final uuid = const Uuid();
    return [
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Pecho + tríceps',
        type: WorkoutType.strength,
        exercises: [
          WorkoutExercise(id: uuid.v4(), name: 'Press banca', muscleGroup: 'Pecho'),
          WorkoutExercise(id: uuid.v4(), name: 'Fondos', muscleGroup: 'Tríceps'),
        ],
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Espalda + bíceps',
        type: WorkoutType.strength,
        exercises: [
          WorkoutExercise(id: uuid.v4(), name: 'Dominadas', muscleGroup: 'Espalda'),
          WorkoutExercise(id: uuid.v4(), name: 'Remo con barra', muscleGroup: 'Espalda'),
        ],
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Piernas',
        type: WorkoutType.strength,
        exercises: [
          WorkoutExercise(id: uuid.v4(), name: 'Sentadilla', muscleGroup: 'Piernas'),
          WorkoutExercise(id: uuid.v4(), name: 'Peso muerto rumano', muscleGroup: 'Posterior'),
        ],
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Full body',
        type: WorkoutType.strength,
        exercises: [
          WorkoutExercise(id: uuid.v4(), name: 'Press banca'),
          WorkoutExercise(id: uuid.v4(), name: 'Sentadilla frontal'),
          WorkoutExercise(id: uuid.v4(), name: 'Remo en máquina'),
        ],
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Running suave',
        type: WorkoutType.cardio,
        activityName: 'Running',
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Intervalos',
        type: WorkoutType.cardio,
        activityName: 'Intervalos en pista',
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Entrenamiento fútbol',
        type: WorkoutType.sport,
        activityName: 'Fútbol',
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Metcon full body',
        type: WorkoutType.functional,
        activityName: 'Metcon',
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Sesión general',
        type: WorkoutType.custom,
        activityName: 'Sesión general',
      ),
    ];
  }
}
