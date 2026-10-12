import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/data/account_storage_scope.dart';
import '../../../../core/data/repositories.dart';
import '../../../../core/domain/entities.dart';
import '../../data/workout_repository.dart';
import '../../domain/workout_analytics.dart';

import 'package:uuid/uuid.dart';

import '../data/exercise_definition.dart';
import '../models/workout_models.dart';
import '../../workout_in_progress_controller.dart';

class WorkoutProProvider extends ChangeNotifier {
  WorkoutProProvider({this.fitnessRepository});
  final FitnessRepository? fitnessRepository;
  final WorkoutRepository _repository = WorkoutRepository();
  String _sessionId = const Uuid().v4();
  WorkoutSession? _pendingSession;
  String? _lastSavedSessionId;
  bool _saving = false, _disposed = false;
  Object? _initializationError, _saveError;
  Future<void> _draftWrites = Future.value();
  bool get isSaving => _saving;
  bool get completionPending => _pendingSession != null;
  String? get lastSavedSessionId => _lastSavedSessionId;
  Object? get initializationError => _initializationError;
  Object? get saveError => _saveError;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static const _templatesKey = 'pro_workout_templates';
  static const _recentExercisesKey = 'pro_recent_exercises';
  static const _draftKey = 'pro_workout_draft';

  final Uuid _uuid = const Uuid();
  ScopedPreferences? _prefs;
  DateTime _sessionStart = DateTime.now();
  bool _isPaused = false;
  DateTime? _pausedAt;
  Duration _accumulatedPaused = Duration.zero;

  WorkoutType _selectedType = WorkoutType.strength;
  String? _customTypeName;
  WorkoutTemplate? _selectedTemplate;
  String? _draftTemplateId;
  String? _draftTemplateName;
  String? _sourceSessionId;
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
  int? _closingFatigue;
  int? _closingPerformance;
  String? _finalNotes;

  List<String> _recentExercises = [];
  List<WorkoutSession> _storedSessions = [];

  String? _draftRaw;

  bool _initialized = false;
  bool get initialized => _initialized;
  bool get hasDraft => _draftRaw != null;

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
  int? get closingFatigue => _closingFatigue;
  int? get closingPerformance => _closingPerformance;
  String? get finalNotes => _finalNotes;
  List<String> get recentExercises => _recentExercises;
  List<String> get mostUsedExercises {
    final counter = <String, int>{};
    for (final session in _storedSessions) {
      for (final exercise in session.exercises) {
        counter.update(exercise.name, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(10).map((e) => e.key).toList();
  }

  List<WorkoutSession> get storedSessions => _storedSessions;
  DateTime get sessionStart => _sessionStart;
  bool get isPaused => _isPaused;
  DateTime? get pausedAt => _pausedAt;
  Duration get accumulatedPaused => _accumulatedPaused;

  bool get canSaveDraft => _initialized && !_saving && !completionPending;
  bool get canFinish =>
      _initialized &&
      !_saving &&
      (completionPending || _validationState().canFinish);
  String? get validationHint => _validationState().message;

  Future<void> applyEntryArgs({
    String? templateId,
    String? trainingContext,
  }) async {
    if (!_initialized) return;
    if (templateId != null) {
      final template = [..._standardTemplates, ..._userTemplates]
          .cast<WorkoutTemplate?>()
          .firstWhere(
            (element) => element?.id == templateId,
            orElse: () => null,
          );
      if (template != null) {
        _applyTemplate(template);
      }
    }
    if (trainingContext != null && trainingContext.isNotEmpty) {
      _notes = ((_notes ?? '').trim().isEmpty)
          ? 'Contexto: $trainingContext'
          : _notes;
    }
    await _persistDraft();
    notifyListeners();
  }

  Future<void> initialize() async {
    _initializationError = null;
    try {
      _prefs ??= await ScopedPreferences.getInstance(
        scope: _repository.storageScope,
      );
      await _loadTemplates();
      await _loadRecentExercises();
      await _loadSessions();
      await _loadDraft();
      if (_repository.isCurrentScope) {
        WorkoutInProgressController.instance.syncFromRaw(_draftRaw);
      }
      _initialized = true;
    } catch (error) {
      _initializationError = error;
    }
    notifyListeners();
  }

  void setType(WorkoutType type, {bool force = false}) {
    if (!force &&
        _selectedType == WorkoutType.strength &&
        type != WorkoutType.strength &&
        _exercises.isNotEmpty) {
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
    _persistDraft();
    notifyListeners();
  }

  void setCustomTypeName(String value) {
    _customTypeName = value;
    _persistDraft();
    notifyListeners();
  }

  void setActivityName(String? value) {
    _activityName = value;
    _persistDraft();
    notifyListeners();
  }

  void setDuration(int? value) {
    _durationMinutes = value;
    _persistDraft();
    notifyListeners();
  }

  void setDistance(double? value) {
    _distanceKm = value;
    _persistDraft();
    notifyListeners();
  }

  void setPace(String? value) {
    _pace = value;
    _persistDraft();
    notifyListeners();
  }

  void setRpe(int value) {
    _rpe = value;
    _persistDraft();
    notifyListeners();
  }

  void setFatigue(int value) {
    _fatigue = value;
    _persistDraft();
    notifyListeners();
  }

  void setNotes(String? value) {
    _notes = value;
    _persistDraft();
    notifyListeners();
  }

  void setClosingDuration(int? value) {
    _closingDuration = value;
    _persistDraft();
    notifyListeners();
  }

  void setClosingFatigue(int? value) {
    _closingFatigue = value;
    _persistDraft();
    notifyListeners();
  }

  void setClosingPerformance(int? value) {
    _closingPerformance = value;
    _persistDraft();
    notifyListeners();
  }

  void setFinalNotes(String? value) {
    _finalNotes = value;
    _persistDraft();
    notifyListeners();
  }

  void clearClosing() {
    _closingDuration = null;
    _closingFatigue = null;
    _closingPerformance = null;
    _finalNotes = null;
    _persistDraft();
    notifyListeners();
  }

  void addExercise(WorkoutExercise exercise) {
    _exercises = [..._exercises, exercise];
    _rememberExercise(exercise.name);
    _persistDraft();
    notifyListeners();
  }

  void reorderExercise(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _exercises.length) return;
    final updated = [..._exercises];
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex.clamp(0, updated.length), item);
    _exercises = updated;
    _persistDraft();
    notifyListeners();
  }

  void addExerciseWithDefaults(WorkoutExercise exercise) {
    final prepared = exercise.sets.isEmpty
        ? exercise.copyWith(sets: [SetEntry(id: _uuid.v4())])
        : exercise;
    addExercise(prepared);
  }

  WorkoutExercise fromDefinition(ExerciseDefinition definition) {
    return WorkoutExercise(
      id: _uuid.v4(),
      name: definition.name,
      muscleGroup: definition.primaryMuscles.isNotEmpty
          ? definition.primaryMuscles.first
          : null,
      measurement: definition.defaultMeasurement,
      sets: [],
    );
  }

  void duplicateExercise(String exerciseId) {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;
    final original = _exercises[index];
    final duplicated = original.copyWith(
      id: _uuid.v4(),
      name: '${original.name} (copy)',
      sets: original.sets.map((set) => set.copyWith(id: _uuid.v4())).toList(),
    );
    _exercises = [..._exercises]..insert(index + 1, duplicated);
    _persistDraft();
    notifyListeners();
  }

  void removeExercise(String exerciseId) {
    _exercises = _exercises.where((e) => e.id != exerciseId).toList();
    _persistDraft();
    notifyListeners();
  }

  void updateExerciseNotes(String exerciseId, String? notes) {
    _exercises = _exercises
        .map((e) => e.id == exerciseId ? e.copyWith(notes: notes) : e)
        .toList();
    _persistDraft();
    notifyListeners();
  }

  void addSet(String exerciseId) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId) {
        final newSet = e.sets.isEmpty
            ? SetEntry(id: _uuid.v4())
            : e.sets.last.copyWith(id: _uuid.v4());
        return e.copyWith(sets: [...e.sets, newSet]);
      }
      return e;
    }).toList();
    _persistDraft();
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
    _persistDraft();
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
    _persistDraft();
    notifyListeners();
  }

  void bumpReps(String exerciseId, int delta) {
    _exercises = _exercises.map((e) {
      if (e.id != exerciseId) return e;
      final updated = e.sets
          .map((s) => s.copyWith(reps: (s.reps ?? 0) + delta))
          .toList();
      return e.copyWith(sets: updated);
    }).toList();
    _persistDraft();
    notifyListeners();
  }

  void bumpWeight(String exerciseId, double delta) {
    final target = _exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => WorkoutExercise(id: '', name: ''),
    );
    if (target.id.isEmpty ||
        target.sets.every((s) => s.externalLoadKg == null)) {
      return;
    }
    _exercises = _exercises.map((e) {
      if (e.id != exerciseId) return e;
      final updated = e.sets
          .map(
            (s) => s.externalLoadKg == null
                ? s
                : s.copyWith(externalLoadKg: (s.externalLoadKg ?? 0) + delta),
          )
          .toList();
      return e.copyWith(sets: updated);
    }).toList();
    _persistDraft();
    notifyListeners();
  }

  void removeSet(String exerciseId, String setId) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId) {
        return e.copyWith(sets: e.sets.where((s) => s.id != setId).toList());
      }
      return e;
    }).toList();
    _persistDraft();
    notifyListeners();
  }

  void insertSet(String exerciseId, int index, SetEntry set) {
    _exercises = _exercises.map((e) {
      if (e.id == exerciseId) {
        final updatedSets = [...e.sets];
        final targetIndex = index.clamp(0, updatedSets.length);
        updatedSets.insert(targetIndex, set);
        return e.copyWith(sets: updatedSets);
      }
      return e;
    }).toList();
    _persistDraft();
    notifyListeners();
  }

  void selectTemplate(WorkoutTemplate template) {
    _selectedTemplate = template;
    _applyTemplate(template);
    _persistDraft();
    notifyListeners();
  }

  void clearTemplate() {
    _selectedTemplate = null;
    _persistDraft();
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
    _persistDraft();
    notifyListeners();
  }

  Future<void> reset() async {
    if (_saving || completionPending) return;
    await _clearDraft();
    _sessionId = _uuid.v4();
    _lastSavedSessionId = null;
    _selectedType = WorkoutType.strength;
    _customTypeName = null;
    _selectedTemplate = null;
    _draftTemplateId = null;
    _draftTemplateName = null;
    _draftTemplateId = null;
    _draftTemplateName = null;
    _sourceSessionId = null;
    _exercises = [];
    _activityName = null;
    _durationMinutes = null;
    _distanceKm = null;
    _pace = null;
    _rpe = 6;
    _fatigue = 3;
    _notes = null;
    _closingDuration = null;
    _closingFatigue = null;
    _closingPerformance = null;
    _finalNotes = null;
    _sessionStart = DateTime.now();
    _isPaused = false;
    _pausedAt = null;
    _accumulatedPaused = Duration.zero;
    notifyListeners();
  }

  Future<void> saveDraft() async {
    if (!canSaveDraft) {
      throw StateError('La sesión no permite editar el borrador.');
    }
    await _persistDraft(requiredWrite: true);
  }

  Future<bool> saveSession() async {
    if (_saving || !_initialized) return false;
    if (_lastSavedSessionId != null && !hasDraft) return true;
    final validation = _validationState();
    if (_pendingSession == null && !validation.canFinish) return false;
    _saving = true;
    notifyListeners();
    try {
      final completedAt = DateTime.now();
      final manualMinutes = _closingDuration ?? _durationMinutes;

      final session = _pendingSession ??= WorkoutSession(
        id: _sessionId,
        type: _selectedType,
        customTypeName: _customTypeName,
        templateId: _selectedTemplate?.id ?? _draftTemplateId,
        templateName: _selectedTemplate?.name ?? _draftTemplateName,
        sourceSessionId: _sourceSessionId,
        date: completedAt.toUtc(),
        activityName: _activityName,
        durationMinutes: manualMinutes ?? elapsed.inMinutes,
        durationSeconds: manualMinutes == null
            ? elapsed.inSeconds
            : manualMinutes * 60,
        durationIsActive: manualMinutes == null,
        startedAt: _sessionStart,
        totalDurationSeconds: completedAt
            .difference(_sessionStart)
            .inSeconds
            .clamp(0, 1 << 31),
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

      await _persistDraft(requiredWrite: true);
      await _repository.persistLegacySession(session);
      await fitnessRepository?.saveWorkout(
        WorkoutEntry(
          id: session.id,
          name:
              session.templateName ??
              session.activityName ??
              'Entrenamiento libre',
          durationMinutes: session.durationMinutes ?? 0,
          intensity: 'No registrada',
          template: session.templateId,
          meta: EntityMeta(
            createdAt: session.date.toUtc(),
            updatedAt: session.date.toUtc(),
            deleted: false,
            revision: 1,
          ),
        ),
      );
      await _clearDraft();
      _storedSessions = [
        ..._storedSessions.where((s) => s.id != session.id),
        session,
      ];
      _lastSavedSessionId = session.id;
      _pendingSession = null;
      _saveError = null;
      if (_repository.isCurrentScope) {
        await WorkoutInProgressController.instance.refresh().catchError(
          (Object _) {},
        );
      }
      return true;
    } catch (error) {
      _saveError = error;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> pauseWorkout() async {
    if (_isPaused || !hasDraft || !canSaveDraft) return;
    _isPaused = true;
    _pausedAt = DateTime.now();
    try {
      await _persistDraft(requiredWrite: true);
    } catch (_) {
      _isPaused = false;
      _pausedAt = null;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> resumeWorkout() async {
    if (!_isPaused || !hasDraft || !canSaveDraft) return;
    final previousPausedAt = _pausedAt;
    final previousAccumulated = _accumulatedPaused;
    final now = DateTime.now();
    if (_pausedAt != null) {
      _accumulatedPaused += now.difference(_pausedAt!);
    }
    _isPaused = false;
    _pausedAt = null;
    try {
      await _persistDraft(requiredWrite: true);
    } catch (_) {
      _isPaused = true;
      _pausedAt = previousPausedAt;
      _accumulatedPaused = previousAccumulated;
      rethrow;
    }
    notifyListeners();
  }

  Duration get elapsed {
    final effectiveNow = _isPaused
        ? (_pausedAt ?? DateTime.now())
        : DateTime.now();
    final value = effectiveNow.difference(_sessionStart) - _accumulatedPaused;
    return value.isNegative ? Duration.zero : value;
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
    0,
    (sum, e) => sum + e.sets.fold(0, (s, set) => s + (set.reps ?? 0)),
  );
  double get totalVolume => WorkoutAnalytics.totalExternalVolume(_exercises);
  double? get averageRir {
    final all = _exercises.expand((e) => e.sets).where((s) => s.rir != null);
    if (all.isEmpty) return null;
    final total = all.fold<int>(0, (sum, s) => sum + (s.rir ?? 0));
    return total / all.length;
  }

  String? get topSetLabel {
    final sets = _exercises
        .expand((e) => e.sets)
        .where((s) => s.externalLoadKg != null && s.reps != null);
    if (sets.isEmpty) return null;
    final top = sets.reduce(
      (a, b) => (a.externalLoadKg ?? 0) >= (b.externalLoadKg ?? 0) ? a : b,
    );
    return '${top.externalLoadKg?.toStringAsFixed(1)}kg x ${top.reps ?? 0}';
  }

  WorkoutSession? get lastSession =>
      _storedSessions.isEmpty ? null : _storedSessions.last;

  _ValidationState _validationState() {
    if (_closingDuration != null && _closingDuration! <= 0) {
      return const _ValidationState(
        canSave: false,
        canFinish: false,
        message: 'La duración debe ser mayor que cero.',
      );
    }
    if (_selectedType == WorkoutType.strength) {
      final hasExercise = _exercises.isNotEmpty;
      final hasSetWithData = _exercises.any(
        (e) => e.sets.any((s) => WorkoutAnalytics.isRecordedSet(e, s)),
      );
      if (!hasExercise) {
        return const _ValidationState(
          canSave: false,
          canFinish: false,
          message: 'Agregá al menos 1 ejercicio',
        );
      }
      if (!hasSetWithData) {
        return const _ValidationState(
          canSave: false,
          canFinish: false,
          message: 'Completá reps, peso o tiempo en alguna serie',
        );
      }
      return const _ValidationState(canSave: true, canFinish: true);
    }

    if (_durationMinutes == null || _durationMinutes! <= 0) {
      return const _ValidationState(
        canSave: false,
        canFinish: false,
        message: 'Ingresá la duración para guardar',
      );
    }

    return const _ValidationState(canSave: true, canFinish: true);
  }

  List<WorkoutTemplate> suggestedTemplates() {
    final List<WorkoutTemplate> options = [];
    WorkoutSession? last;
    try {
      last = _storedSessions.reversed.firstWhere(
        (s) => s.type == _selectedType && s.templateId != null,
      );
    } catch (_) {
      last = _storedSessions.isNotEmpty ? _storedSessions.last : null;
    }
    if (last != null && last.templateId != null) {
      final lastTemplateId = last.templateId!;
      final template = [..._standardTemplates, ..._userTemplates].firstWhere(
        (t) => t.id == lastTemplateId,
        orElse: () => _standardTemplates.firstWhere(
          (t) => t.type == _selectedType,
          orElse: () => _standardTemplates.first,
        ),
      );
      options.add(template);
    }

    options.addAll(
      _standardTemplates.where((t) => t.type == _selectedType).take(3),
    );

    final unique = <String>{};
    return options.where((t) => unique.add(t.id)).toList();
  }

  String getDurationLabel({int? elapsedSeconds}) {
    final minutes = _closingDuration ?? _durationMinutes;
    if (minutes == null || minutes == 0) {
      return _liveDurationLabel(elapsedSeconds);
    }
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  String _liveDurationLabel(int? elapsedSeconds) {
    final diff = elapsedSeconds != null
        ? Duration(seconds: elapsedSeconds)
        : elapsed;
    final minutes = diff.inMinutes;
    final hours = diff.inHours;
    if (hours > 0) {
      final remainder = minutes - hours * 60;
      return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
    }
    return '${minutes}m';
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
    _storedSessions = await _repository.listAllSessions();
  }

  Future<void> _persistDraft({bool requiredWrite = false}) async {
    final map = {
      'type': _selectedType.name,
      'workoutId': _sessionId,
      'pendingCompletedSessionId': _pendingSession?.id,
      'pendingCompletedSession': _pendingSession?.toJson(),
      'customTypeName': _customTypeName,
      'templateId': _selectedTemplate?.id ?? _draftTemplateId,
      'templateName': _selectedTemplate?.name ?? _draftTemplateName,
      'sourceSessionId': _sourceSessionId,
      'activityName': _activityName,
      'durationMinutes': _durationMinutes,
      'distanceKm': _distanceKm,
      'pace': _pace,
      'rpe': _rpe,
      'fatigue': _fatigue,
      'notes': _notes,
      'closingDuration': _closingDuration,
      'closingFatigue': _closingFatigue,
      'closingPerformance': _closingPerformance,
      'finalNotes': _finalNotes,
      'sessionStart': _sessionStart.toIso8601String(),
      'isPaused': _isPaused,
      'pausedAt': _pausedAt?.toIso8601String(),
      'accumulatedPausedSeconds': _accumulatedPaused.inSeconds,
      'lastUpdated': DateTime.now().toIso8601String(),
      'exercises': _exercises.map((e) => e.toJson()).toList(),
    };
    final snapshot = _draftRaw = jsonEncode(map);
    final preferences = _prefs!;
    _draftWrites = _draftWrites.catchError((Object _) {}).then((_) async {
      await preferences.setString(_draftKey, snapshot);
    });
    try {
      await _draftWrites;
      _saveError = null;
    } catch (error) {
      _saveError = error;
      if (requiredWrite) rethrow;
    } finally {
      notifyListeners();
    }
    if (_repository.isCurrentScope) {
      WorkoutInProgressController.instance.syncFromRaw(_draftRaw);
    }
  }

  Future<void> _loadDraft() async {
    _draftRaw = _prefs?.getString(_draftKey);
    if (_draftRaw == null) return;
    try {
      final json = jsonDecode(_draftRaw!) as Map<String, dynamic>;
      _sessionId = json['workoutId'] as String? ?? _sessionId;
      final pending = json['pendingCompletedSession'];
      if (pending is Map) {
        _pendingSession = WorkoutSession.fromJson(
          Map<String, dynamic>.from(pending),
        );
      }
      final typeName = json['type'] as String?;
      if (typeName != null) {
        _selectedType = WorkoutType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => WorkoutType.strength,
        );
      }
      _customTypeName = json['customTypeName'] as String?;
      final templateId = json['templateId'] as String?;
      _draftTemplateId = templateId;
      _draftTemplateName = json['templateName'] as String?;
      _sourceSessionId = json['sourceSessionId'] as String?;
      if (templateId != null) {
        _selectedTemplate = [..._standardTemplates, ..._userTemplates]
            .cast<WorkoutTemplate?>()
            .firstWhere(
              (element) => element?.id == templateId,
              orElse: () => null,
            );
      }
      _activityName = json['activityName'] as String?;
      _durationMinutes = json['durationMinutes'] as int?;
      _distanceKm = (json['distanceKm'] as num?)?.toDouble();
      _pace = json['pace'] as String?;
      _rpe = json['rpe'] as int? ?? 6;
      _fatigue = json['fatigue'] as int? ?? 3;
      _notes = json['notes'] as String?;
      _closingDuration = json['closingDuration'] as int?;
      _closingFatigue = json['closingFatigue'] as int?;
      _closingPerformance = json['closingPerformance'] as int?;
      _finalNotes = json['finalNotes'] as String?;
      final startRaw = json['sessionStart'] as String?;
      if (startRaw != null) {
        _sessionStart = DateTime.tryParse(startRaw) ?? DateTime.now();
      }
      _isPaused = json['isPaused'] as bool? ?? false;
      _pausedAt = DateTime.tryParse(json['pausedAt'] as String? ?? '');
      _accumulatedPaused = Duration(
        seconds: json['accumulatedPausedSeconds'] as int? ?? 0,
      );
      final exercisesJson = json['exercises'] as List<dynamic>?;
      if (exercisesJson != null) {
        _exercises = exercisesJson
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      throw const FormatException(
        'No se pudo leer la sesión Pro. El borrador se conserva.',
      );
    }
  }

  Future<void> _clearDraft() async {
    await _draftWrites.catchError((Object _) {});
    await _prefs!.remove(_draftKey);
    _draftRaw = null;
    _isPaused = false;
    _pausedAt = null;
    _accumulatedPaused = Duration.zero;
    if (_repository.isCurrentScope) {
      WorkoutInProgressController.instance.syncFromRaw(null);
    }
  }

  List<SetEntry> _buildTemplateSets(WorkoutExercise exercise) {
    return List<SetEntry>.generate(exercise.targetSets, (index) {
      final baseReps = exercise.targetReps ?? exercise.targetRepsMin;
      final load =
          exercise.targetLoadType == RoutineExerciseLoadType.weightedKg ||
              exercise.targetLoadType == RoutineExerciseLoadType.machineKg
          ? exercise.targetWeightKg
          : null;
      final assistance =
          exercise.targetLoadType == RoutineExerciseLoadType.assistedKg
          ? exercise.targetWeightKg
          : null;
      return SetEntry(
        id: _uuid.v4(),
        reps: baseReps,
        externalLoadKg: load,
        assistanceKg: assistance,
        restSeconds: exercise.restSeconds,
        rir: exercise.rir,
      );
    });
  }

  void _applyTemplate(WorkoutTemplate template) {
    setType(template.type, force: true);
    _selectedTemplate = template;
    _draftTemplateId = template.id;
    _activityName = template.activityName;
    if (template.type == WorkoutType.strength) {
      _exercises = template.exercises
          .map(
            (e) => WorkoutExercise(
              id: _uuid.v4(),
              name: e.name,
              muscleGroup: e.muscleGroup,
              equipment: e.equipment,
              measurement: e.measurement,
              notes: e.notes,
              targetSets: e.targetSets,
              targetReps: e.targetReps,
              targetRepsMin: e.targetRepsMin,
              targetRepsMax: e.targetRepsMax,
              targetLoadType: e.targetLoadType,
              targetWeightKg: e.targetWeightKg,
              restSeconds: e.restSeconds,
              rir: e.rir,
              sets: e.sets.isNotEmpty
                  ? e.sets.map((s) => s.copyWith(id: _uuid.v4())).toList()
                  : _buildTemplateSets(e),
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
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Press banca',
            muscleGroup: 'Pecho',
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Fondos',
            muscleGroup: 'Tríceps',
          ),
        ],
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Espalda + bíceps',
        type: WorkoutType.strength,
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Dominadas',
            muscleGroup: 'Espalda',
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Remo con barra',
            muscleGroup: 'Espalda',
          ),
        ],
      ),
      WorkoutTemplate(
        id: uuid.v4(),
        name: 'Piernas',
        type: WorkoutType.strength,
        exercises: [
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Sentadilla',
            muscleGroup: 'Piernas',
          ),
          WorkoutExercise(
            id: uuid.v4(),
            name: 'Peso muerto rumano',
            muscleGroup: 'Posterior',
          ),
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

class _ValidationState {
  const _ValidationState({
    required this.canSave,
    required this.canFinish,
    this.message,
  });

  final bool canSave;
  final bool canFinish;
  final String? message;
}
