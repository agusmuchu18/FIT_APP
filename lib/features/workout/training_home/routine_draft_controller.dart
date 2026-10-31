import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/account_storage_scope.dart';
import '../domain/routine_labels.dart';
import '../domain/sport_activity.dart';
import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';
import 'template_workout_type.dart';

class RoutineDraftController extends ChangeNotifier {
  RoutineDraftController({
    this.workoutType = TemplateWorkoutType.gym,
    List<String> initialSelectedExerciseIds = const [],
    this.editingRoutineId,
  }) : _scope = AccountStorageScope.current {
    for (final id in initialSelectedExerciseIds.toSet()) {
      _items.add(_new(_default(id)));
    }
  }
  static const storageKey = 'workout_routine_draft_v2';
  final String? editingRoutineId;
  String get _key => editingRoutineId == null
      ? storageKey
      : '${storageKey}_edit_$editingRoutineId';
  final String _scope;
  final List<WorkoutExercise> _items = [];
  TemplateWorkoutType workoutType;
  FootballMode footballMode = FootballMode.technical;
  String name = '', notes = '';
  String? folderId;
  String draftId = const Uuid().v4();
  Object? persistenceError;
  bool restoreFailed = false;
  bool modeChanged = false;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  List<WorkoutExercise> get items => List.unmodifiable(_items);
  List<String> get selectedExerciseIds =>
      _items.map((e) => e.id).toList(growable: false);
  int get selectedCount => _items.length;
  bool contains(String id) => _items.any((e) => e.id == id);
  WorkoutExercise? configFor(String id) =>
      _items.where((e) => e.id == id).firstOrNull;
  WorkoutExercise _default(String id) {
    final d = exerciseLibrary.where((e) => e.id == id).firstOrNull;
    return d == null
        ? WorkoutExercise(id: id, name: id)
        : RoutineLabels.defaults(d);
  }

  WorkoutExercise _new(WorkoutExercise e) =>
      e.copyWith(instanceId: const Uuid().v4());
  void _changed() {
    if (restoreFailed) {
      throw StateError('El borrador ilegible se conserva sin sobrescribir');
    }
    notifyListeners();
    final payload = jsonEncode(toJson());
    _writes = _writes.then((_) async {
      try {
        final prefs = await ScopedPreferences.getInstance(scope: _scope);
        await prefs.setString(_key, payload);
        persistenceError = null;
      } catch (error) {
        persistenceError = error;
      }
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> flush() async {
    if (restoreFailed) {
      throw StateError('El borrador ilegible se conserva sin sobrescribir');
    }
    await _writes;
    if (persistenceError != null) {
      try {
        final prefs = await ScopedPreferences.getInstance(scope: _scope);
        await prefs.setString(_key, jsonEncode(toJson()));
        persistenceError = null;
      } catch (error) {
        persistenceError = error;
        throw StateError('No se pudo conservar el borrador');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'draftId': draftId,
    'type': workoutType.name,
    'footballMode': footballMode.name,
    'modeChanged': modeChanged,
    'name': name,
    'notes': notes,
    'folderId': folderId,
    'exercises': _items.map((e) => e.toJson()).toList(),
  };
  Future<void> restore({bool force = false}) async {
    try {
      final prefs = await ScopedPreferences.getInstance(scope: _scope);
      final raw = prefs.getString(_key);
      if (raw == null) {
        restoreFailed = false;
        persistenceError = null;
        if (!_disposed) notifyListeners();
        return;
      }
      if (_items.isNotEmpty && !force) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final restored = (json['exercises'] as List)
          .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
          .map((e) => e.instanceId == null ? _new(e) : e)
          .toList();
      if (restored.map((e) => e.instanceId).toSet().length != restored.length) {
        throw const FormatException('Instancias duplicadas en el borrador');
      }
      workoutType = TemplateWorkoutType.values.byName(json['type'] as String);
      footballMode = FootballMode.values.byName(json['footballMode'] as String);
      name = json['name'] as String;
      notes = json['notes'] as String;
      folderId = json['folderId'] as String?;
      draftId = json['draftId'] as String;
      modeChanged = json['modeChanged'] as bool? ?? false;
      _items
        ..clear()
        ..addAll(restored);
      restoreFailed = false;
      persistenceError = null;
      if (!_disposed) notifyListeners();
    } catch (error) {
      restoreFailed = true;
      persistenceError = error;
      if (!_disposed) notifyListeners();
    }
  }

  void hydrate(WorkoutTemplate routine) {
    workoutType = routine.type == WorkoutType.sport
        ? TemplateWorkoutType.sport
        : TemplateWorkoutType.gym;
    footballMode =
        routine.footballMode ??
        (routine.exercises.every((e) => e.sportPlan == null)
            ? FootballMode.gym
            : FootballMode.technical);
    name = routine.name;
    notes = routine.notes ?? '';
    folderId = routine.folderId;
    _items
      ..clear()
      ..addAll(
        routine.exercises.map((e) => e.instanceId == null ? _new(e) : e),
      );
    notifyListeners();
  }

  void updateHeader({
    String? name,
    String? notes,
    String? folderId,
    bool clearFolder = false,
  }) {
    this.name = name ?? this.name;
    this.notes = notes ?? this.notes;
    this.folderId = clearFolder ? null : folderId ?? this.folderId;
    _changed();
  }

  bool compatible(TemplateWorkoutType type, FootballMode mode) => _items.every(
    (e) => type == TemplateWorkoutType.gym || mode == FootballMode.gym
        ? e.sportPlan == null
        : e.sportPlan?.mode == mode,
  );
  void setMode(
    TemplateWorkoutType type,
    FootballMode mode, {
    bool discardIncompatible = false,
  }) {
    if (!compatible(type, mode) && !discardIncompatible) {
      throw StateError('Actividades incompatibles');
    }
    if (discardIncompatible) {
      _items.removeWhere(
        (e) => type == TemplateWorkoutType.gym || mode == FootballMode.gym
            ? e.sportPlan != null
            : e.sportPlan?.mode != mode,
      );
    }
    workoutType = type;
    modeChanged = true;
    footballMode = mode;
    _changed();
  }

  void setWorkoutType(TemplateWorkoutType type) => setMode(type, footballMode);
  bool add(WorkoutExercise e) {
    if (contains(e.id)) return false;
    _items.add(_new(e));
    _changed();
    return true;
  }

  void toggleExercise(String id) {
    if (contains(id)) {
      removeExercise(id);
    } else {
      add(_default(id));
    }
  }

  void update(String instanceId, WorkoutExercise e) {
    final index = _items.indexWhere((item) => item.instanceId == instanceId);
    if (index < 0) return;
    _items[index] = e.copyWith(instanceId: instanceId);
    _changed();
  }

  void removeExercise(String id) {
    _items.removeWhere((e) => e.id == id);
    _changed();
  }

  void removeExerciseAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _changed();
    }
  }

  void insertExerciseAt(int index, String id) {
    _items.insert(index.clamp(0, _items.length), _new(_default(id)));
    _changed();
  }

  void duplicate(int index) {
    _items.insert(index + 1, _new(_items[index]));
    _changed();
  }

  void reorder(int oldIndex, int newIndex) {
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _changed();
  }

  void clear() {
    _items.clear();
    name = '';
    notes = '';
    folderId = null;
    draftId = const Uuid().v4();
    _changed();
  }

  void clearExercises() {
    _items.clear();
    _changed();
  }

  Future<void> clearPersisted() async {
    await flush();
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    await prefs.remove(_key);
    _items.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
