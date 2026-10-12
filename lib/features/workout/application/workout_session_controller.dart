import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart';
import '../data/workout_repository.dart';
import '../data/workout_preferences.dart';
import '../domain/session_models.dart';
import '../domain/workout_live_metrics.dart';
import '../pro/models/workout_models.dart';
import '../pro/data/exercise_library.dart';
import '../pro/data/exercise_definition.dart';
import '../training_home/routines_repository.dart';
import '../workout_in_progress_controller.dart';

class IncompleteWorkoutException implements Exception {
  const IncompleteWorkoutException();
}

class WorkoutSessionController extends ChangeNotifier {
  static final _definitions = {
    for (final exercise in exerciseLibrary) exercise.id: exercise,
  };
  WorkoutSessionController({
    WorkoutRepository? repository,
    this._fitnessRepository,
  }) : _repository = repository ?? WorkoutRepository();

  final WorkoutRepository _repository;
  final FitnessRepository? _fitnessRepository;
  final Uuid _uuid = const Uuid();
  String _sessionId = const Uuid().v4();
  String? _sourceSessionId;

  List<ExerciseInSession> _exercises = [];
  String? _expandedExerciseId;
  Timer? _autosaveTimer;
  Future<void> _pendingAutosave = Future<void>.value();
  String? _routineId;
  String? _routineName;
  WorkoutType _workoutType = WorkoutType.strength;
  DateTime _sessionStart = DateTime.now();
  bool _isPaused = false;
  DateTime? _pausedAt;
  Duration _accumulatedPaused = Duration.zero;
  int? _restStartedAtElapsedSeconds;
  int? _restDurationSeconds;
  String? _restSourceSetId;
  bool _finishing = false;
  bool _finished = false;
  bool _completionRecorded = false;
  DateTime? _completedAt;
  Duration? _completedDuration;
  bool _discarding = false;
  bool _disposed = false;
  bool _initialized = false;
  bool _initializing = false;
  Object? _initializationError;
  Object? _saveError;
  final Map<String, Future<List<PreviousSet>>> _previousRequests = {};
  Map<String, double>? _previousMuscleDistribution;
  WorkoutPreferences _preferences = const WorkoutPreferences();

  List<ExerciseInSession> get exercises => _exercises;
  String? get expandedExerciseId => _expandedExerciseId;
  DateTime get sessionStart => _sessionStart;
  bool get isPaused => _isPaused;
  DateTime? get pausedAt => _pausedAt;
  Duration get accumulatedPaused => _accumulatedPaused;
  bool get isFinishing => _finishing;
  bool get isReady => _initialized && !_finishing && !_finished && !_discarding;
  bool get isLoading => !_initialized && _initializationError == null;
  Object? get initializationError => _initializationError;
  Object? get saveError => _saveError;
  bool get isFinished => _finished;
  bool get completionNeedsRecovery => _completionRecorded && !_finished;
  bool get canEdit => isReady && !_completionRecorded && !_disposed;
  String get sessionId => _sessionId;
  int get programmedSets => _exercises.fold(0, (sum, e) => sum + e.sets.length);
  int get completedSets => _exercises.fold(
    0,
    (sum, e) =>
        sum +
        e.sets
            .where((set) => set.done && set.hasValidResult(isTimed: e.isTimed))
            .length,
  );
  bool get allSetsCompleted =>
      programmedSets > 0 && completedSets == programmedSets;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> reloadPreferences() async {
    final preferences = await WorkoutPreferences.load();
    if (_disposed) return;
    _preferences = preferences;
  }

  Future<void> saveDraft() async {
    if (!canEdit) return;
    _enqueueDraftSave();
    await _pendingAutosave;
  }

  bool get hasActiveRest => _restStartedAtElapsedSeconds != null;
  int get restDurationSeconds => _restDurationSeconds ?? 0;
  String? get restSourceExerciseName {
    for (final exercise in _exercises) {
      if (exercise.sets.any((set) => set.id == _restSourceSetId)) {
        return exercise.name;
      }
    }
    return null;
  }

  Duration restRemainingAt(DateTime now) {
    final started = _restStartedAtElapsedSeconds;
    final duration = _restDurationSeconds;
    if (started == null || duration == null) return Duration.zero;
    final remaining = duration - (elapsedAt(now).inSeconds - started);
    return Duration(seconds: remaining > 0 ? remaining : 0);
  }

  Future<void> togglePause() async {
    if (!canEdit) return;
    await saveDraft();
    final inProgress = WorkoutInProgressController.instance;
    if (_isPaused) {
      await inProgress.resumePausedWorkout();
    } else {
      await inProgress.pause();
    }
    final identity = await _repository.loadDraftIdentity();
    if (_disposed || identity?.sessionId != _sessionId) return;
    _isPaused = identity!.isPaused;
    _pausedAt = identity.pausedAt;
    _accumulatedPaused = identity.accumulatedPaused;
    notifyListeners();
  }

  void skipRest() {
    if (!canEdit) return;
    if (!hasActiveRest) return;
    _clearRest();
    notifyListeners();
    _enqueueDraftSave();
  }

  void extendRest() {
    if (!canEdit) return;
    if (!hasActiveRest) return;
    _restDurationSeconds = (_restDurationSeconds ?? 0) + 30;
    notifyListeners();
    _enqueueDraftSave();
  }

  Duration elapsedAt(DateTime now) {
    final end = _isPaused ? (_pausedAt ?? now) : now;
    final elapsed = end.difference(_sessionStart) - _accumulatedPaused;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  double get totalVolume => WorkoutLiveMetrics.computeTotalVolume(_exercises);
  Map<String, double> get currentMuscleDistribution =>
      WorkoutLiveMetrics.computeCurrentMuscleDistribution(_exercises);
  Map<String, double>? get previousMuscleDistribution =>
      _previousMuscleDistribution;

  Future<void> initialize({
    List<ExerciseInSession>? initialExercises,
    String? templateId,
  }) async {
    if (_initializing || _initialized || _disposed) return;
    _initializing = true;
    _initializationError = null;
    notifyListeners();
    try {
      _preferences = await WorkoutPreferences.load();
      final draft = await _repository.loadDraftExercises();
      if (draft != null) {
        _exercises = draft.map((exercise) {
          final assisted =
              exercise.isAssisted ||
              _definitions[exercise.exerciseId]?.loadType ==
                  LoadType.assistedBodyweight;
          return exercise.copyWith(
            isTimed:
                exercise.isTimed ||
                (_definitions[exercise.exerciseId]?.isTimed ?? false),
            isAssisted: assisted,
            sets: [
              for (final set in exercise.sets)
                assisted && set.kg != null
                    ? set.copyWith(
                        assistanceKg: set.assistanceKg ?? set.kg,
                        clearKg: true,
                      )
                    : set,
            ],
          );
        }).toList();
        final identity = await _repository.loadDraftIdentity();
        _sessionId = identity?.sessionId ?? _sessionId;
        _sourceSessionId = identity?.sourceSessionId;
        _routineId = identity?.routineId;
        _routineName = identity?.routineName;
        _workoutType = identity?.workoutType ?? WorkoutType.strength;
        _isPaused = identity?.isPaused ?? false;
        _pausedAt = identity?.pausedAt;
        _accumulatedPaused = identity?.accumulatedPaused ?? Duration.zero;
        _restStartedAtElapsedSeconds = identity?.restStartedAtElapsedSeconds;
        _restDurationSeconds = identity?.restDurationSeconds;
        _restSourceSetId = identity?.restSourceSetId;
        _sessionStart =
            await _repository.loadDraftStartTime() ?? DateTime.now();
      } else {
        _sessionStart = DateTime.now();
        _routineId = templateId;
        if (templateId != null) {
          final routines = await RoutinesRepository().getAllRoutines();
          for (final routine in routines) {
            if (routine.id == templateId) {
              _routineName = routine.name;
              _workoutType = routine.type;
              break;
            }
          }
        }
        if (initialExercises != null && initialExercises.isNotEmpty) {
          _exercises = initialExercises;
          _expandedExerciseId = initialExercises.first.id;
        }
      }
      final previousExercises = await _repository
          .loadLatestCompletedSessionExercises();
      if (previousExercises != null && previousExercises.isNotEmpty) {
        _previousMuscleDistribution =
            WorkoutLiveMetrics.computeCurrentMuscleDistribution(
              previousExercises,
            );
      }

      if (draft == null && _exercises.isEmpty && templateId != null) {
        final routines = await RoutinesRepository().getAllRoutines();
        WorkoutTemplate? routine;
        for (final item in routines) {
          if (item.id == templateId) {
            routine = item;
            break;
          }
        }
        if (routine != null) {
          _routineName = routine.name;
          _workoutType = routine.type;
          _exercises = routine.exercises.map((exercise) {
            final sets = List.generate(
              exercise.targetSets,
              (index) => SetInSession(
                id: _uuid.v4(),
                index: index + 1,
                kg:
                    exercise.targetLoadType ==
                        RoutineExerciseLoadType.assistedKg
                    ? null
                    : exercise.targetWeightKg,
                assistanceKg:
                    exercise.targetLoadType ==
                        RoutineExerciseLoadType.assistedKg
                    ? exercise.targetWeightKg
                    : null,
                reps: exercise.isTimed
                    ? null
                    : (exercise.targetReps ?? exercise.targetRepsMin),
                durationSeconds: exercise.targetDurationSeconds,
              ),
            );
            return ExerciseInSession(
              id: _uuid.v4(),
              exerciseId: exercise.id,
              name: exercise.name,
              isTimed:
                  exercise.isTimed ||
                  (_definitions[exercise.id]?.isTimed ?? false),
              isAssisted:
                  exercise.targetLoadType == RoutineExerciseLoadType.assistedKg,
              restEnabled:
                  exercise.restSeconds != null ||
                  _preferences.defaultRestEnabled,
              restSeconds:
                  exercise.restSeconds ??
                  (_preferences.defaultRestEnabled
                      ? _preferences.defaultRestSeconds
                      : null),
              sets: sets,
            );
          }).toList();
        }
      }
      if (_disposed) return;
      await _repository.persistDraftWithStartTime(
        _exercises,
        startTime: _sessionStart,
        workoutId: _sessionId,
        sourceSessionId: _sourceSessionId,
        routineId: _routineId,
        routineName: _routineName,
        workoutType: _workoutType,
      );
      if (_repository.isCurrentScope) {
        await WorkoutInProgressController.instance.refresh().catchError(
          (Object _) {},
        );
      }
      _initialized = true;
    } catch (error) {
      _initializationError = error;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> toggleExerciseExpansion(String exerciseId) async {
    if (!canEdit) return;
    _expandedExerciseId = _expandedExerciseId == exerciseId ? null : exerciseId;
    notifyListeners();
    if (_expandedExerciseId != null) {
      await _ensurePreviousForExercise(exerciseId);
    }
  }

  Future<void> addExercise({
    required String exerciseId,
    required String name,
  }) async {
    if (!canEdit) return;
    final newExercise = ExerciseInSession(
      id: _uuid.v4(),
      exerciseId: exerciseId,
      name: name,
      isTimed: _definitions[exerciseId]?.isTimed ?? false,
      isAssisted:
          _definitions[exerciseId]?.loadType == LoadType.assistedBodyweight,
      restEnabled: _preferences.defaultRestEnabled,
      restSeconds: _preferences.defaultRestEnabled
          ? _preferences.defaultRestSeconds
          : null,
      sets: [SetInSession(id: _uuid.v4(), index: 1)],
    );
    _exercises = [..._exercises, newExercise];
    _expandedExerciseId = newExercise.id;
    notifyListeners();
    _scheduleAutosave();
    await _ensurePreviousForExercise(newExercise.id);
    _scheduleAutosave();
  }

  void removeExercise(String exerciseId) {
    if (!canEdit) return;
    final removed = _exercises.where((exercise) => exercise.id == exerciseId);
    if (removed.any(
      (exercise) => exercise.sets.any((set) => set.id == _restSourceSetId),
    )) {
      _clearRest();
    }
    _exercises = _exercises
        .where((exercise) => exercise.id != exerciseId)
        .toList();
    if (_expandedExerciseId == exerciseId) {
      _expandedExerciseId = null;
    }
    notifyListeners();
    _scheduleAutosave();
  }

  void moveExerciseUp(String exerciseId) {
    if (!canEdit) return;
    final index = _exercises.indexWhere(
      (exercise) => exercise.id == exerciseId,
    );
    if (index <= 0) return;
    final updated = [..._exercises];
    final item = updated.removeAt(index);
    updated.insert(index - 1, item);
    _exercises = updated;
    notifyListeners();
    _scheduleAutosave();
  }

  void moveExerciseDown(String exerciseId) {
    if (!canEdit) return;
    final index = _exercises.indexWhere(
      (exercise) => exercise.id == exerciseId,
    );
    if (index == -1 || index >= _exercises.length - 1) return;
    final updated = [..._exercises];
    final item = updated.removeAt(index);
    updated.insert(index + 1, item);
    _exercises = updated;
    notifyListeners();
    _scheduleAutosave();
  }

  void updateExerciseNotes(String exerciseId, String notes) {
    if (!canEdit) return;
    _exercises = _exercises
        .map(
          (exercise) => exercise.id == exerciseId
              ? exercise.copyWith(notes: notes)
              : exercise,
        )
        .toList();
    notifyListeners();
    _scheduleAutosave();
  }

  void updateExerciseRest(
    String exerciseId, {
    required bool enabled,
    int? seconds,
  }) {
    if (!canEdit) return;
    if (enabled && (seconds == null || seconds < 1 || seconds > 3600)) return;
    _exercises = _exercises
        .map(
          (exercise) => exercise.id == exerciseId
              ? exercise.copyWith(
                  restEnabled: enabled,
                  restSeconds: enabled ? seconds : null,
                  clearRestSeconds: !enabled,
                )
              : exercise,
        )
        .toList();
    notifyListeners();
    _scheduleAutosave();
  }

  void updateSet(
    String exerciseId,
    String setId, {
    double? kg,
    bool clearKg = false,
    int? reps,
    bool clearReps = false,
    int? durationSeconds,
    bool clearDuration = false,
    bool? done,
  }) {
    if (!canEdit) return;
    if (kg != null && (!kg.isFinite || kg < 0)) {
      throw ArgumentError.value(kg, 'kg');
    }
    if (reps != null && reps < 1) throw ArgumentError.value(reps, 'reps');
    if (durationSeconds != null && durationSeconds < 1) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final exerciseIndex = _exercises.indexWhere(
      (item) => item.id == exerciseId,
    );
    if (exerciseIndex < 0) return;
    final originalExercise = _exercises[exerciseIndex];
    final setIndex = originalExercise.sets.indexWhere((set) => set.id == setId);
    if (setIndex < 0) return;
    final wasDone = originalExercise.sets[setIndex].done;
    _exercises = _exercises.map((exercise) {
      if (exercise.id != exerciseId) return exercise;
      final sets = exercise.sets
          .map(
            (set) => set.id == setId
                ? set.copyWith(
                    kg: exercise.isAssisted ? null : kg,
                    clearKg: exercise.isAssisted || clearKg,
                    assistanceKg: exercise.isAssisted ? kg : null,
                    clearAssistance: exercise.isAssisted && clearKg,
                    reps: reps,
                    clearReps: clearReps,
                    durationSeconds: durationSeconds,
                    clearDuration: clearDuration,
                    done: done ?? set.done,
                  )
                : set,
          )
          .toList();
      return exercise.copyWith(sets: sets);
    }).toList();
    final updatedSet = _exercises[exerciseIndex].sets[setIndex];
    if (updatedSet.done &&
        !updatedSet.hasValidResult(isTimed: originalExercise.isTimed)) {
      _exercises = _replaceExercise(
        _exercises[exerciseIndex].copyWith(
          sets: [
            for (final set in _exercises[exerciseIndex].sets)
              set.id == setId ? set.copyWith(done: false) : set,
          ],
        ),
      );
      if (_restSourceSetId == setId) _clearRest();
      notifyListeners();
      _scheduleAutosave();
      return;
    }
    if (done == true && !wasDone && originalExercise.restEnabled) {
      _restStartedAtElapsedSeconds = elapsedAt(DateTime.now()).inSeconds;
      _restDurationSeconds = originalExercise.restSeconds ?? 90;
      _restSourceSetId = setId;
    } else if (done == false && wasDone && _restSourceSetId == setId) {
      _clearRest();
    }
    notifyListeners();
    if (done != null) {
      _enqueueDraftSave();
    } else {
      _scheduleAutosave();
    }
  }

  Future<void> addSet(String exerciseId) async {
    if (!canEdit) return;
    // Add synchronously; history is optional and must never delay a user edit.
    final exercise = _findExercise(exerciseId);
    if (exercise == null) return;
    final setNumber = exercise.sets.length + 1;
    final newSet = SetInSession(id: _uuid.v4(), index: setNumber);
    final updatedExercise = exercise.copyWith(sets: [...exercise.sets, newSet]);
    _exercises = _replaceExercise(updatedExercise);
    notifyListeners();
    _scheduleAutosave();
    await _ensurePreviousForExercise(exerciseId, refresh: true);
  }

  void removeSet(String exerciseId, String setId) {
    if (!canEdit) return;
    final exercise = _findExercise(exerciseId);
    if (exercise == null) return;
    final remaining = exercise.sets.where((set) => set.id != setId).toList();
    _exercises = _replaceExercise(
      exercise.copyWith(
        sets: [
          for (var i = 0; i < remaining.length; i++)
            remaining[i].copyWith(index: i + 1),
        ],
      ),
    );
    if (_restSourceSetId == setId) _clearRest();
    notifyListeners();
    _scheduleAutosave();
  }

  ExerciseInSession? _findExercise(String id) {
    for (final exercise in _exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  Future<void> _ensurePreviousForExercise(
    String exerciseId, {
    bool refresh = false,
  }) async {
    final requested = _findExercise(exerciseId);
    if (requested == null || (requested.previousLoaded && !refresh)) return;
    List<PreviousSet> previousSets;
    try {
      previousSets = await _previousRequests.putIfAbsent(
        requested.exerciseId,
        () => _repository.getPreviousSetsForExercise(requested.exerciseId),
      );
    } catch (_) {
      _previousRequests.remove(requested.exerciseId);
      return; // A history failure must not prevent recording the current session.
    }
    if (!canEdit) return;
    final exercise = _findExercise(exerciseId);
    if (exercise == null) return;
    final mappedSets = exercise.sets
        .map(
          (set) => set.copyWith(
            previous: previousSets.length >= set.index
                ? previousSets[set.index - 1]
                : null,
          ),
        )
        .toList();
    _exercises = _replaceExercise(
      exercise.copyWith(previousLoaded: true, sets: mappedSets),
    );
    notifyListeners();
    _scheduleAutosave();
  }

  Future<void> discardWorkout() async {
    if (_completionRecorded) {
      throw StateError(
        'La sesión ya se guardó en el historial. Reintentá el cierre.',
      );
    }
    if (_discarding || _finishing || _finished) return;
    _discarding = true;
    notifyListeners();
    try {
      _autosaveTimer?.cancel();
      await _pendingAutosave.catchError((Object _) {});
      await _repository.clearDraft();
      _clearRest();
      _exercises = [];
      _expandedExerciseId = null;
      _finished = true;
      if (_repository.isCurrentScope) {
        unawaited(
          WorkoutInProgressController.instance.refresh().catchError(
            (Object _) {},
          ),
        );
      }
    } finally {
      _discarding = false;
      notifyListeners();
    }
  }

  Future<bool> finishWorkout() async {
    if (!isReady || _disposed) return false;
    final hasValidCompletedSet = _exercises.any(
      (exercise) => exercise.sets.any(
        (set) => set.done && set.hasValidResult(isTimed: exercise.isTimed),
      ),
    );
    if (!hasValidCompletedSet) throw const IncompleteWorkoutException();
    // Persist the latest keystroke before entering the terminal write sequence.
    _enqueueDraftSave();
    _finishing = true;
    notifyListeners();
    try {
      _autosaveTimer?.cancel();
      await _pendingAutosave;
      final identity = await _repository.loadDraftIdentity();
      if (identity?.sessionId == _sessionId) {
        _isPaused = identity?.isPaused ?? false;
        _pausedAt = identity?.pausedAt;
        _accumulatedPaused = identity?.accumulatedPaused ?? Duration.zero;
      }
      final completedAt = _completedAt ??= DateTime.now();
      final duration = _completedDuration ??= elapsedAt(completedAt);
      await _repository.markCompletionPending(_sessionId);
      if (!_completionRecorded) {
        await _repository.persistCompletedWorkout(
          _exercises,
          sessionId: _sessionId,
          routineId: _routineId,
          routineName: _routineName,
          workoutType: _workoutType,
          duration: duration,
          completedAt: completedAt,
          startedAt: _sessionStart,
          totalDuration: completedAt.isBefore(_sessionStart)
              ? Duration.zero
              : completedAt.difference(_sessionStart),
          sourceSessionId: _sourceSessionId,
          clearDraftAfterSave: false,
        );
      }
      _completionRecorded = true;
      await _fitnessRepository?.saveWorkout(
        WorkoutEntry(
          id: _sessionId,
          name: _routineName ?? 'Entrenamiento libre',
          durationMinutes: duration.inMinutes,
          intensity: 'No registrada',
          template: _routineId,
          meta: EntityMeta(
            createdAt: completedAt.toUtc(),
            updatedAt: completedAt.toUtc(),
            deleted: false,
            revision: 1,
          ),
        ),
      );
      await _repository.clearDraft();
      _clearRest();
      _exercises = [];
      _expandedExerciseId = null;
      _finished = true;
      if (_repository.isCurrentScope) {
        unawaited(
          WorkoutInProgressController.instance.refresh().catchError(
            (Object _) {},
          ),
        );
      }
      notifyListeners();
      return true;
    } finally {
      _finishing = false;
      if (!_completionRecorded) {
        _completedAt = null;
        _completedDuration = null;
      }
      notifyListeners();
    }
  }

  List<ExerciseInSession> _replaceExercise(ExerciseInSession updated) {
    return _exercises
        .map((exercise) => exercise.id == updated.id ? updated : exercise)
        .toList();
  }

  void _clearRest() {
    _restStartedAtElapsedSeconds = null;
    _restDurationSeconds = null;
    _restSourceSetId = null;
  }

  void _scheduleAutosave() {
    if (!canEdit) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 300), () {
      _enqueueDraftSave();
    });
  }

  void _enqueueDraftSave() {
    if (!canEdit) return;
    _autosaveTimer?.cancel();
    final exercises = _exercises;
    final startTime = _sessionStart;
    final sessionId = _sessionId;
    final routineId = _routineId;
    final routineName = _routineName;
    final workoutType = _workoutType;
    final restStartedAtElapsedSeconds = _restStartedAtElapsedSeconds;
    final restDurationSeconds = _restDurationSeconds;
    final restSourceSetId = _restSourceSetId;
    _pendingAutosave = _pendingAutosave
        .catchError((Object _) {})
        .then(
          (_) => _repository.persistDraftWithStartTime(
            exercises,
            startTime: startTime,
            workoutId: sessionId,
            sourceSessionId: _sourceSessionId,
            routineId: routineId,
            routineName: routineName,
            workoutType: workoutType,
            restStartedAtElapsedSeconds: restStartedAtElapsedSeconds,
            restDurationSeconds: restDurationSeconds,
            restSourceSetId: restSourceSetId,
            clearRest: restStartedAtElapsedSeconds == null,
          ),
        )
        .then((_) async {
          if (_repository.isCurrentScope) {
            await WorkoutInProgressController.instance.refresh();
          }
          if (_saveError != null) {
            _saveError = null;
            notifyListeners();
          }
        });
    unawaited(
      _pendingAutosave.catchError((Object error, StackTrace stack) {
        _saveError = error;
        notifyListeners();
      }),
    );
  }

  @override
  void dispose() {
    if (_autosaveTimer?.isActive ?? false) _enqueueDraftSave();
    _autosaveTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
