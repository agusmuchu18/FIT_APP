import '../domain/training_program.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/repositories.dart';
import '../../../core/domain/entities.dart';
import '../data/workout_repository.dart';
import '../data/workout_preferences.dart';
import '../domain/session_models.dart';
import '../domain/workout_live_metrics.dart';
import '../domain/workout_analytics.dart';
import '../domain/exercise_load_policy.dart';
import '../pro/models/workout_models.dart';
import '../pro/data/exercise_library.dart';
import '../pro/data/exercise_definition.dart';
import '../training_home/routines_repository.dart';
import '../domain/sport_activity.dart';
import '../workout_in_progress_controller.dart';
import 'routine_update_from_session.dart';

class IncompleteWorkoutException implements Exception {
  const IncompleteWorkoutException();
}

/// What the user chose to do with sets that are still unchecked at the end.
enum PendingSetsResolution { keepPending, completeFilled, discardPending }

/// Enough to put a removed exercise or set back exactly where it was.
class RemovedExercise {
  const RemovedExercise(this.exercise, this.index);
  final ExerciseInSession exercise;
  final int index;
}

class RemovedSet {
  const RemovedSet(this.exerciseId, this.set, this.index);
  final String exerciseId;
  final SetInSession set;
  final int index;
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
  ProgramExecutionRef? _programExecution;

  List<ExerciseInSession> _exercises = [];
  String? _expandedExerciseId;
  String? _expandedSetId;
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
  final Set<String> _touchedSetFields = {};
  Map<String, double>? _previousMuscleDistribution;
  WorkoutPreferences _preferences = const WorkoutPreferences();

  /// Heaviest saved external load per `exerciseId|loadKey`.
  Map<String, double>? _bestLoads;
  List<String> _recentExerciseIds = const [];
  String? _autoAdvancedExerciseId;

  String? get routineId => _routineId;
  String? get routineName => _routineName;

  /// Most recently trained exercise ids (newest first), for quick adding.
  List<String> get recentExerciseIds => _recentExerciseIds;

  /// The exercise opened automatically after finishing the previous one.
  /// Reading it clears it, so the UI scrolls to it only once.
  String? consumeAutoAdvance() {
    final id = _autoAdvancedExerciseId;
    _autoAdvancedExerciseId = null;
    return id;
  }

  List<ExerciseInSession> get exercises => _exercises;
  String? get expandedExerciseId => _expandedExerciseId;
  String? get expandedSetId => _expandedSetId;
  void toggleSetExpansion(String id) {
    _expandedSetId = _expandedSetId == id ? null : id;
    notifyListeners();
  }

  void updateSetDetails(String exerciseId, SetInSession details) {
    if (!canEdit) return;
    final exercise = _findExercise(exerciseId);
    final original = exercise?.sets
        .where((s) => s.id == details.id)
        .firstOrNull;
    if (exercise == null || original == null || original.done) return;
    if (details.rir != null && (details.rir! < 0 || details.rir! > 10)) {
      throw ArgumentError('RIR inválido');
    }
    if (details.implementCount != null &&
        details.implementCount != 1 &&
        details.implementCount != 2) {
      throw ArgumentError('Cantidad de implementos inválida');
    }
    _exercises = _replaceExercise(
      exercise.copyWith(
        sets: [
          for (final s in exercise.sets)
            s.id == details.id
                ? s.copyWith(
                    loadConvention: details.loadConvention,
                    implementCount: details.implementCount,
                    rir: details.rir,
                    clearRir: details.rir == null,
                    note: details.note,
                  )
                : s,
        ],
      ),
    );
    notifyListeners();
    _scheduleAutosave();
  }

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
            .where(
              (set) =>
                  set.done &&
                  set.hasValidResult(
                    isTimed: e.isTimed,
                    isDistance: e.isDistance,
                  ),
            )
            .length,
  );
  bool get allSetsCompleted =>
      programmedSets > 0 && completedSets == programmedSets;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> reloadPreferences() async {
    final preferences = await WorkoutPreferences.load(
      scope: _repository.storageScope,
    );
    if (_disposed) return;
    _preferences = preferences;
  }

  Future<void> saveDraft() async {
    if (!canEdit) return;
    _enqueueDraftSave();
    await _pendingAutosave;
  }

  bool get hasActiveRest => _restStartedAtElapsedSeconds != null;

  /// Identifies the running rest, so a finished one alerts only once.
  String get restKey =>
      '${_restSourceSetId ?? ''}|${_restStartedAtElapsedSeconds ?? ''}';
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

  void extendRest() => adjustRest(30);

  /// Adds or removes seconds from the running rest. Shortening it past the
  /// time already rested finishes the rest.
  void adjustRest(int deltaSeconds) {
    if (!canEdit) return;
    final started = _restStartedAtElapsedSeconds;
    if (started == null) return;
    final rested = elapsedAt(DateTime.now()).inSeconds - started;
    final next = (_restDurationSeconds ?? 0) + deltaSeconds;
    if (next <= rested || next < 1) {
      _clearRest();
    } else {
      _restDurationSeconds = next.clamp(1, 3600 + rested);
    }
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
    ProgramExecutionRef? programExecution,
  }) async {
    if (_initializing || _initialized || _disposed) return;
    _initializing = true;
    _initializationError = null;
    notifyListeners();
    try {
      _preferences = await WorkoutPreferences.load(
        scope: _repository.storageScope,
      );
      final draft = await _repository.loadDraftExercises();
      if (draft != null) {
        _exercises = draft.map(_adaptLoadModes).toList();
        final identity = await _repository.loadDraftIdentity();
        _sessionId = identity?.sessionId ?? _sessionId;
        _sourceSessionId = identity?.sourceSessionId;
        _programExecution = identity?.programExecution;
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
        _programExecution = programExecution;
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
          _exercises = initialExercises.map(_adaptLoadModes).toList();
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
            final sets = List.generate(exercise.targetSets, (index) {
              final target = index < exercise.setTargets.length
                  ? exercise.setTargets[index]
                  : null;
              final intended = target?.loadType ?? exercise.targetLoadType;
              final body = ExerciseLoadPolicy.isBodyweight(
                _definitions[exercise.id],
                equipment: exercise.equipment,
              );
              final mode =
                  body && !ExerciseLoadPolicy.bodyweightModes.contains(intended)
                  ? RoutineExerciseLoadType.bodyweight
                  : intended;
              return SetInSession(
                id: _uuid.v4(),
                index: index + 1,
                loadType: mode,
                loadTypeOverride: target?.loadType != null,
                kg:
                    mode == RoutineExerciseLoadType.bodyweight ||
                        mode == RoutineExerciseLoadType.assistedKg
                    ? null
                    : target?.weightKg ?? exercise.targetWeightKg,
                assistanceKg: mode == RoutineExerciseLoadType.assistedKg
                    ? target?.loadFor(exercise.targetLoadType) ??
                          exercise.plannedLoad
                    : null,
                reps: exercise.isTimed
                    ? null
                    : (target?.reps ??
                          target?.repsMin ??
                          exercise.targetReps ??
                          exercise.targetRepsMin),
                durationSeconds: exercise.sportPlan == null
                    ? target?.durationSeconds ?? exercise.targetDurationSeconds
                    : null,
              );
            });
            return ExerciseInSession(
              id: _uuid.v4(),
              exerciseId: exercise.id,
              plan: exercise,
              notes: exercise.notes,
              name: exercise.name,
              isTimed:
                  exercise.isTimed ||
                  (_definitions[exercise.id]?.isTimed ?? false),
              isAssisted:
                  exercise.targetLoadType == RoutineExerciseLoadType.assistedKg,
              restEnabled:
                  exercise.restEnabled ??
                  (exercise.restSeconds != null ||
                      _preferences.defaultRestEnabled),
              restSeconds:
                  exercise.restSeconds ??
                  (_preferences.defaultRestEnabled
                      ? _preferences.defaultRestSeconds
                      : null),
              supersetId: exercise.sportPlan == null
                  ? exercise.supersetId
                  : null,
              sets: sets,
            );
          }).toList();
          _exercises = _normalizedSupersets(_exercises);
        }
      }
      if (_disposed) return;
      _expandedExerciseId ??= _firstIncompleteExercise()?.id;
      await _repository.persistDraftWithStartTime(
        _exercises,
        startTime: _sessionStart,
        workoutId: _sessionId,
        sourceSessionId: _sourceSessionId,
        programExecution: _programExecution,
        routineId: _routineId,
        routineName: _routineName,
        workoutType: _workoutType,
      );
      if (_repository.isCurrentScope) {
        await WorkoutInProgressController.instance.refresh().catchError(
          (Object _) {},
        );
      }
      _exercises = _exercises.map(_adaptLoadModes).toList();
      _initialized = true;
      final expanded = _expandedExerciseId;
      // Read-only warm-up: nothing is persisted until the user edits.
      if (expanded != null) {
        unawaited(_ensurePreviousForExercise(expanded, persist: false));
      }
      unawaited(_loadPerformanceIndex());
    } catch (error) {
      _initializationError = error;
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  ExerciseInSession? _firstIncompleteExercise({int after = -1}) {
    for (var i = after + 1; i < _exercises.length; i++) {
      final exercise = _exercises[i];
      if (exercise.sets.isEmpty || exercise.sets.any((set) => !set.done)) {
        return exercise;
      }
    }
    return null;
  }

  Future<void> _loadPerformanceIndex() async {
    try {
      final index = await _repository.performanceIndex();
      if (_disposed) return;
      final best = <String, double>{};
      for (final record in index.records) {
        if (record.kind != RecordKind.load) continue;
        final key = '${record.exerciseId}|${record.loadKey}';
        final current = best[key];
        if (current == null || record.value > current) {
          best[key] = record.value;
        }
      }
      _bestLoads = best;
      final recent = <String>[];
      for (final report in index.reports.reversed) {
        for (final exercise in report.session.exercises) {
          final id = exercise.id;
          if (!recent.contains(id)) recent.add(id);
        }
        if (recent.length >= 12) break;
      }
      _recentExerciseIds = List.unmodifiable(recent.take(12));
      notifyListeners();
    } catch (_) {
      // Records and recents are optional; recording must never depend on them.
    }
  }

  /// True when this completed set lifts more external load than any saved
  /// session for the same exercise and load convention. A first-ever session
  /// has nothing to beat, so it never shows a record.
  bool isLiveRecord(String exerciseId, String setId) {
    final bestLoads = _bestLoads;
    final live = _findExercise(exerciseId);
    if (bestLoads == null || live == null || live.sportPlan != null) {
      return false;
    }
    final source = live.sets.where((s) => s.id == setId).firstOrNull;
    if (source == null || !source.done || source.kg == null) return false;
    final exercise = WorkoutAnalytics.fromLive([live]).single;
    final set = exercise.sets.firstWhere((s) => s.id == setId);
    final mode = WorkoutAnalytics.setLoadType(exercise, set);
    if (mode == null ||
        mode == RoutineExerciseLoadType.bodyweight ||
        mode == RoutineExerciseLoadType.assistedKg ||
        WorkoutAnalytics.externalLoadForVolume(set, exercise: exercise) ==
            null) {
      return false;
    }
    final id = WorkoutAnalytics.definition(exercise)?.id ?? exercise.id;
    final best = bestLoads['$id|${exerciseLoadKey(exercise, set)}'];
    return best != null && (set.externalLoadKg ?? 0) > best;
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
      isDistance: _definitions[exerciseId]?.defaultMeasurement == 'distance',
      isAssisted:
          _definitions[exerciseId]?.loadType == LoadType.assistedBodyweight,
      restEnabled: _preferences.defaultRestEnabled,
      restSeconds: _preferences.defaultRestEnabled
          ? _preferences.defaultRestSeconds
          : null,
      isBodyweight: ExerciseLoadPolicy.isBodyweight(_definitions[exerciseId]),
      defaultLoadType: ExerciseLoadPolicy.defaultFor(_definitions[exerciseId]),
      sets: [
        SetInSession(
          id: _uuid.v4(),
          index: 1,
          loadType: ExerciseLoadPolicy.defaultFor(_definitions[exerciseId]),
        ),
      ],
    );
    _exercises = [..._exercises, newExercise];
    _expandedExerciseId = newExercise.id;
    notifyListeners();
    _scheduleAutosave();
    await _ensurePreviousForExercise(newExercise.id);
    _scheduleAutosave();
  }

  void duplicateExercise(String exerciseId) {
    if (!canEdit) return;
    final original = _findExercise(exerciseId);
    if (original == null) return;
    final duplicate = ExerciseInSession(
      id: _uuid.v4(),
      exerciseId: original.exerciseId,
      name: original.name,
      isTimed: original.isTimed,
      isDistance: original.isDistance,
      isAssisted: original.isAssisted,
      isBodyweight: original.isBodyweight,
      defaultLoadType: original.defaultMode,
      restEnabled: original.restEnabled,
      restSeconds: original.restSeconds,
      plan: original.plan?.copyWith(instanceId: _uuid.v4(), sets: []),
      sets: [
        for (var i = 0; i < original.sets.length; i++)
          SetInSession(
            id: _uuid.v4(),
            index: i + 1,
            kg: original.sets[i].kg,
            loadType: original.modeFor(original.sets[i]),
            loadTypeOverride: original.sets[i].loadTypeOverride,
            loadIsAmbiguous: original.sets[i].loadIsAmbiguous,
            assistanceKg: original.sets[i].assistanceKg,
            bodyweightKg: original.sets[i].bodyweightKg,
            bodyweightFactor: original.sets[i].bodyweightFactor,
            reps: original.sets[i].reps,
            durationSeconds: original.sets[i].durationSeconds,
            distanceMeters: original.sets[i].distanceMeters,
            loadConvention: original.sets[i].loadConvention,
            implementCount: original.sets[i].implementCount,
            kind: original.sets[i].kind,
          ),
      ],
    );
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    _exercises = _normalizedSupersets(
      [..._exercises]..insert(index + 1, duplicate),
    );
    _expandedExerciseId = duplicate.id;
    _expandedSetId = null;
    notifyListeners();
    _scheduleAutosave();
    unawaited(_ensurePreviousForExercise(duplicate.id));
  }

  void replaceExercise(
    String instanceId, {
    required String exerciseId,
    required String name,
  }) {
    if (!canEdit) return;
    final original = _findExercise(instanceId);
    if (original == null) return;
    final definition = _definitions[exerciseId];
    final replacement = ExerciseInSession(
      id: _uuid.v4(),
      exerciseId: exerciseId,
      name: name,
      notes: original.notes,
      restEnabled: original.restEnabled,
      restSeconds: original.restSeconds,
      isTimed: definition?.isTimed ?? false,
      isDistance: definition?.defaultMeasurement == 'distance',
      isAssisted: definition?.loadType == LoadType.assistedBodyweight,
      isBodyweight: ExerciseLoadPolicy.isBodyweight(_definitions[exerciseId]),
      defaultLoadType: ExerciseLoadPolicy.defaultFor(_definitions[exerciseId]),
      sets: [
        SetInSession(
          id: _uuid.v4(),
          index: 1,
          loadType: ExerciseLoadPolicy.defaultFor(_definitions[exerciseId]),
        ),
      ],
    );
    if (original.sets.any((s) => s.id == _restSourceSetId)) _clearRest();
    _exercises = [
      for (final e in _exercises) e.id == instanceId ? replacement : e,
    ];
    _expandedExerciseId = replacement.id;
    _expandedSetId = null;
    notifyListeners();
    _scheduleAutosave();
    unawaited(_ensurePreviousForExercise(replacement.id));
  }

  ExerciseInSession _adaptLoadModes(ExerciseInSession exercise) {
    final definition = _definitions[exercise.exerciseId];
    final body =
        exercise.isBodyweight ||
        ExerciseLoadPolicy.isBodyweight(
          definition,
          equipment: exercise.plan?.equipment,
        );
    final planned = exercise.plan?.targetLoadType;
    final mode =
        exercise.defaultLoadType ??
        (exercise.isAssisted
            ? RoutineExerciseLoadType.assistedKg
            : planned != null &&
                  (!body ||
                      ExerciseLoadPolicy.bodyweightModes.contains(planned))
            ? planned
            : ExerciseLoadPolicy.defaultFor(definition));
    return exercise.copyWith(
      isBodyweight: body,
      defaultLoadType: mode,
      isAssisted: mode == RoutineExerciseLoadType.assistedKg,
      sets: [
        for (final set in exercise.sets)
          set.copyWith(
            loadType: set.loadType ?? mode,
            assistanceKg:
                set.loadType == null &&
                    mode == RoutineExerciseLoadType.assistedKg
                ? set.assistanceKg ?? set.kg
                : null,
            loadIsAmbiguous:
                set.loadIsAmbiguous ||
                (set.loadType == null &&
                    body &&
                    mode == RoutineExerciseLoadType.bodyweight &&
                    (set.kg ?? 0) > 0),
          ),
      ],
    );
  }

  void updateLoadType(String exerciseId, RoutineExerciseLoadType type) {
    if (!canEdit) return;
    final exercise = _findExercise(exerciseId);
    if (exercise == null ||
        (exercise.isBodyweight &&
            !ExerciseLoadPolicy.bodyweightModes.contains(type))) {
      return;
    }
    final originalPlan =
        exercise.plan ??
        WorkoutExercise(id: exercise.exerciseId, name: exercise.name);
    final legacyAssistance =
        originalPlan.targetLoadType == RoutineExerciseLoadType.assistedKg &&
        originalPlan.loadSchemaVersion == 0;
    final plan = originalPlan.copyWith(
      loadSchemaVersion: 1,
      targetAssistanceKg: legacyAssistance ? originalPlan.plannedLoad : null,
      clearTargetWeightKg: legacyAssistance,
    );
    _exercises = _replaceExercise(
      exercise.copyWith(
        defaultLoadType: type,
        isAssisted: type == RoutineExerciseLoadType.assistedKg,
        plan: plan.copyWith(targetLoadType: type),
        sets: [
          for (final s in exercise.sets)
            s.done || s.loadTypeOverride ? s : s.copyWith(loadType: type),
        ],
      ),
    );
    notifyListeners();
    _scheduleAutosave();
  }

  void updateSetLoadType(
    String exerciseId,
    String setId,
    RoutineExerciseLoadType type,
  ) {
    if (!canEdit) return;
    final exercise = _findExercise(exerciseId);
    if (exercise == null ||
        !exercise.isBodyweight ||
        !ExerciseLoadPolicy.bodyweightModes.contains(type)) {
      return;
    }
    _exercises = _replaceExercise(
      exercise.copyWith(
        sets: [
          for (final s in exercise.sets)
            if (s.id != setId)
              s
            else
              s.copyWith(
                loadType: type,
                loadTypeOverride: true,
                done:
                    s.done &&
                    s
                        .copyWith(loadType: type)
                        .hasValidResult(
                          isTimed: exercise.isTimed,
                          isDistance: exercise.isDistance,
                        ),
              ),
        ],
      ),
    );
    final updated = _findExercise(exerciseId)!.sets
        .firstWhere((s) => s.id == setId);
    if (!updated.done && _restSourceSetId == setId) _clearRest();
    _touchedSetFields.add('$exerciseId|$setId|load');
    notifyListeners();
    _scheduleAutosave();
  }

  void applyPreviousSet(String exerciseId, String setId) {
    final exercise = _findExercise(exerciseId);
    final set = exercise?.sets.where((s) => s.id == setId).firstOrNull;
    final previous = set?.previous;
    if (!canEdit ||
        exercise == null ||
        set == null ||
        set.done ||
        previous == null) {
      return;
    }
    if (exercise.isBodyweight &&
        !previous.loadIsAmbiguous &&
        previous.loadType != null &&
        ExerciseLoadPolicy.bodyweightModes.contains(previous.loadType)) {
      updateSetLoadType(exerciseId, setId, previous.loadType!);
    }
    final current = _findExercise(exerciseId)!;
    final mode = current.modeFor(current.sets.firstWhere((s) => s.id == setId));
    final compatible = previous.compatibleWith(
      mode,
      bodyweight: current.isBodyweight,
    );
    updateSet(
      exerciseId,
      setId,
      kg: compatible && mode != RoutineExerciseLoadType.bodyweight
          ? mode == RoutineExerciseLoadType.assistedKg
                ? previous.assistanceKg
                : previous.kg
          : null,
      reps: current.isTimed ? null : previous.reps,
      durationSeconds: current.isTimed ? previous.durationSeconds : null,
    );
  }

  RemovedExercise? removeExercise(String exerciseId) {
    if (!canEdit) return null;
    final index = _exercises.indexWhere(
      (exercise) => exercise.id == exerciseId,
    );
    if (index < 0) return null;
    final removed = _exercises[index];
    if (removed.sets.any((set) => set.id == _restSourceSetId)) {
      _clearRest();
    }
    _exercises = _normalizedSupersets(
      _exercises.where((exercise) => exercise.id != exerciseId).toList(),
    );
    if (_expandedExerciseId == exerciseId) {
      _expandedExerciseId = null;
    }
    notifyListeners();
    _scheduleAutosave();
    return RemovedExercise(removed, index);
  }

  /// Undo for [removeExercise]; the original identity and results return.
  void restoreExercise(RemovedExercise removed) {
    if (!canEdit || _findExercise(removed.exercise.id) != null) return;
    final index = removed.index.clamp(0, _exercises.length);
    _exercises = _normalizedSupersets(
      [..._exercises]..insert(index, removed.exercise),
    );
    _expandedExerciseId = removed.exercise.id;
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
    _exercises = _normalizedSupersets(updated);
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
    _exercises = _normalizedSupersets(updated);
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

  void updateSportResult(String exerciseId, SportMeasurements? result) {
    if (!canEdit) return;
    _exercises = _exercises.map((e) {
      if (e.id != exerciseId || e.sportPlan == null) return e;
      final valid = e.sportPlan!.resultValid(result);
      return e.copyWith(
        sportResult: result,
        clearSportResult: result == null,
        sets: [
          for (final s in e.sets)
            s.copyWith(
              durationSeconds: result?.values[SportMetric.durationSeconds]
                  ?.toInt(),
              clearDuration:
                  result?.values[SportMetric.durationSeconds] == null,
              done: valid && s.done,
            ),
        ],
      );
    }).toList();
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
    double? distanceMeters,
    bool clearDistance = false,
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
    if (distanceMeters != null &&
        (!distanceMeters.isFinite || distanceMeters <= 0)) {
      throw ArgumentError.value(distanceMeters, 'distanceMeters');
    }
    final exerciseIndex = _exercises.indexWhere(
      (item) => item.id == exerciseId,
    );
    if (exerciseIndex < 0) return;
    final originalExercise = _exercises[exerciseIndex];
    final setIndex = originalExercise.sets.indexWhere((set) => set.id == setId);
    if (setIndex < 0) return;
    final prefix = '$exerciseId|$setId|';
    if (kg != null || clearKg) _touchedSetFields.add('${prefix}load');
    if (reps != null || clearReps) _touchedSetFields.add('${prefix}reps');
    if (durationSeconds != null || clearDuration) {
      _touchedSetFields.add('${prefix}duration');
    }
    if (distanceMeters != null || clearDistance) {
      _touchedSetFields.add('${prefix}distance');
    }
    final wasDone = originalExercise.sets[setIndex].done;
    _exercises = _exercises.map((exercise) {
      if (exercise.id != exerciseId) return exercise;
      final sets = exercise.sets
          .map(
            (set) => set.id == setId
                ? set.copyWith(
                    kg:
                        exercise.modeFor(set) ==
                            RoutineExerciseLoadType.assistedKg
                        ? null
                        : kg,
                    clearKg:
                        exercise.modeFor(set) !=
                            RoutineExerciseLoadType.assistedKg &&
                        clearKg,
                    assistanceKg:
                        exercise.modeFor(set) ==
                            RoutineExerciseLoadType.assistedKg
                        ? kg
                        : null,
                    clearAssistance:
                        exercise.modeFor(set) ==
                            RoutineExerciseLoadType.assistedKg &&
                        clearKg,
                    loadIsAmbiguous: kg != null || clearKg ? false : null,
                    reps: reps,
                    clearReps: clearReps,
                    durationSeconds: durationSeconds,
                    clearDuration: clearDuration,
                    distanceMeters: distanceMeters,
                    clearDistance: clearDistance,
                    performedAt: done == true && !set.done
                        ? DateTime.now().toUtc()
                        : null,
                    done: done ?? set.done,
                  )
                : set,
          )
          .toList();
      return exercise.copyWith(sets: sets);
    }).toList();
    final updatedSet = _exercises[exerciseIndex].sets[setIndex];
    if (updatedSet.done &&
        (!updatedSet.hasValidResult(
              isTimed: originalExercise.isTimed,
              isDistance: originalExercise.isDistance,
            ) ||
            (originalExercise.sportPlan != null &&
                !originalExercise.sportPlan!.resultValid(
                  originalExercise.sportResult,
                )))) {
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
    final group = supersetRange(exerciseId);
    final lastInGroup = group == null || exerciseIndex == group.end;
    if (done == true &&
        !wasDone &&
        originalExercise.restEnabled &&
        lastInGroup) {
      _restStartedAtElapsedSeconds = elapsedAt(DateTime.now()).inSeconds;
      _restDurationSeconds = originalExercise.restSeconds ?? 90;
      _restSourceSetId = setId;
    } else if (done == true && !wasDone && !lastInGroup) {
      // Inside a superset the next exercise follows without rest.
      _clearRest();
    } else if (done == false && wasDone && _restSourceSetId == setId) {
      _clearRest();
    }
    if (done == true && !wasDone && _expandedExerciseId == exerciseId) {
      final next = group != null
          ? _nextInSuperset(exerciseIndex, group)
          : _exercises[exerciseIndex].sets.every((set) => set.done)
          ? _firstIncompleteExercise(after: exerciseIndex)
          : null;
      if (next != null && next.id != exerciseId) {
        _expandedExerciseId = next.id;
        _expandedSetId = null;
        _autoAdvancedExerciseId = next.id;
        unawaited(_ensurePreviousForExercise(next.id));
      }
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
    final previous = exercise.sets.lastOrNull;
    final mode = exercise.defaultMode;
    final compatible =
        previous != null &&
        exercise.modeFor(previous) == mode &&
        !previous.loadIsAmbiguous;
    final newSet = SetInSession(
      id: _uuid.v4(),
      index: setNumber,
      loadType: mode,
      kg:
          compatible &&
              mode != RoutineExerciseLoadType.bodyweight &&
              mode != RoutineExerciseLoadType.assistedKg &&
              previous.kg != null &&
              previous.kg!.isFinite &&
              previous.kg! >= 0
          ? previous.kg
          : null,
      assistanceKg:
          compatible &&
              mode == RoutineExerciseLoadType.assistedKg &&
              previous.assistanceKg != null &&
              previous.assistanceKg!.isFinite &&
              previous.assistanceKg! >= 0
          ? previous.assistanceKg
          : null,
      reps: (previous?.reps ?? 0) > 0 ? previous!.reps : null,
      durationSeconds: (previous?.durationSeconds ?? 0) > 0
          ? previous!.durationSeconds
          : null,
      distanceMeters:
          previous?.distanceMeters != null &&
              previous!.distanceMeters!.isFinite &&
              previous.distanceMeters! > 0
          ? previous.distanceMeters
          : null,
      loadConvention: previous?.loadConvention ?? LoadConvention.recorded,
      implementCount: previous?.implementCount,
    );
    final updatedExercise = exercise.copyWith(sets: [...exercise.sets, newSet]);
    _exercises = _replaceExercise(updatedExercise);
    notifyListeners();
    _scheduleAutosave();
    await _ensurePreviousForExercise(exerciseId, refresh: true);
  }

  RemovedSet? removeSet(String exerciseId, String setId) {
    if (!canEdit) return null;
    final exercise = _findExercise(exerciseId);
    if (exercise == null) return null;
    final index = exercise.sets.indexWhere((set) => set.id == setId);
    if (index < 0) return null;
    final removed = exercise.sets[index];
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
    return RemovedSet(exerciseId, removed, index);
  }

  /// Undo for [removeSet]; sets are renumbered around the restored one.
  void restoreSet(RemovedSet removed) {
    if (!canEdit) return;
    final exercise = _findExercise(removed.exerciseId);
    if (exercise == null || exercise.sets.any((s) => s.id == removed.set.id)) {
      return;
    }
    final sets = [...exercise.sets]
      ..insert(removed.index.clamp(0, exercise.sets.length), removed.set);
    _exercises = _replaceExercise(
      exercise.copyWith(
        sets: [
          for (var i = 0; i < sets.length; i++) sets[i].copyWith(index: i + 1),
        ],
      ),
    );
    notifyListeners();
    _scheduleAutosave();
  }

  /// Checks a set, filling empty fields from the previous session or the
  /// plan first. Returns false when there is still nothing valid to record.
  bool completeSet(String exerciseId, String setId) {
    if (!canEdit) return false;
    final exercise = _findExercise(exerciseId);
    final set = exercise?.sets.where((s) => s.id == setId).firstOrNull;
    if (exercise == null || set == null) return false;
    if (set.done) return true;
    if (set.hasValidResult(
      isTimed: exercise.isTimed,
      isDistance: exercise.isDistance,
    )) {
      updateSet(exerciseId, setId, done: true);
      return _findExercise(exerciseId)?.sets
              .where((s) => s.id == setId)
              .firstOrNull
              ?.done ??
          false;
    }
    final previous = set.previous;
    final plan = exercise.plan;
    final target = plan != null && set.index - 1 < plan.setTargets.length
        ? plan.setTargets[set.index - 1]
        : null;
    final mode = exercise.modeFor(set);
    final currentLoad = mode == RoutineExerciseLoadType.assistedKg
        ? set.assistanceKg
        : set.kg;
    final compatible =
        previous?.compatibleWith(mode, bodyweight: exercise.isBodyweight) ??
        false;
    final previousLoad = !compatible
        ? null
        : mode == RoutineExerciseLoadType.assistedKg
        ? previous?.assistanceKg
        : previous?.kg;
    final targetMode = target?.loadType ?? plan?.targetLoadType;
    final plannedLoad = targetMode == mode
        ? target?.loadFor(plan?.targetLoadType ?? mode)
        : null;
    final load = mode == RoutineExerciseLoadType.bodyweight
        ? null
        : currentLoad ??
              previousLoad ??
              plannedLoad ??
              (plan?.targetLoadType == mode ? plan?.plannedLoad : null);
    if (exercise.isDistance) return false;
    if (exercise.isTimed) {
      final seconds =
          set.durationSeconds ??
          previous?.durationSeconds ??
          target?.durationSeconds ??
          plan?.targetDurationSeconds;
      if (seconds == null || seconds < 1) return false;
      updateSet(
        exerciseId,
        setId,
        kg: load,
        durationSeconds: seconds,
        done: true,
      );
    } else {
      final reps =
          set.reps ??
          previous?.reps ??
          target?.reps ??
          target?.repsMin ??
          plan?.targetReps;
      if (reps == null || reps < 1) return false;
      updateSet(
        exerciseId,
        setId,
        kg: load != null && load.isFinite && load >= 0 ? load : null,
        reps: reps,
        done: true,
      );
    }
    return _findExercise(exerciseId)?.sets
            .where((s) => s.id == setId)
            .firstOrNull
            ?.done ??
        false;
  }

  /// Unchecked sets at the end of a session.
  int get pendingSets => _exercises
      .where((e) => e.sportPlan == null)
      .fold(0, (sum, e) => sum + e.sets.where((s) => !s.done).length);

  /// Unchecked sets that already hold a valid value (typed or prefilled).
  int get fillablePendingSets => _exercises
      .where((e) => e.sportPlan == null)
      .fold(
        0,
        (sum, e) =>
            sum +
            e.sets
                .where(
                  (s) =>
                      !s.done &&
                      s.hasValidResult(
                        isTimed: e.isTimed,
                        isDistance: e.isDistance,
                      ),
                )
                .length,
      );

  /// Applies the end-of-session choice for unchecked sets. Exercises left
  /// without sets are removed; sport activities are never touched.
  void resolvePendingSets(PendingSetsResolution resolution) {
    if (!canEdit || resolution == PendingSetsResolution.keepPending) return;
    final now = DateTime.now().toUtc();
    final next = <ExerciseInSession>[];
    for (final exercise in _exercises) {
      if (exercise.sportPlan != null) {
        next.add(exercise);
        continue;
      }
      final sets = <SetInSession>[];
      for (final set in exercise.sets) {
        if (set.done) {
          sets.add(set);
        } else if (resolution == PendingSetsResolution.completeFilled &&
            set.hasValidResult(
              isTimed: exercise.isTimed,
              isDistance: exercise.isDistance,
            )) {
          sets.add(set.copyWith(done: true, performedAt: now));
        }
      }
      if (sets.isEmpty) continue;
      next.add(
        exercise.copyWith(
          sets: [
            for (var i = 0; i < sets.length; i++)
              sets[i].copyWith(index: i + 1),
          ],
        ),
      );
    }
    _exercises = next;
    if (_findExercise(_expandedExerciseId ?? '') == null) {
      _expandedExerciseId = null;
    }
    if (!_exercises.any((e) => e.sets.any((s) => s.id == _restSourceSetId))) {
      _clearRest();
    }
    notifyListeners();
    _enqueueDraftSave();
  }

  /// Proposal to keep today's completed values as the routine's new targets.
  /// Must be read before [finishWorkout], which clears the session.
  Future<RoutineUpdateProposal?> routineUpdateCandidate() async {
    final id = _routineId;
    if (id == null) return null;
    try {
      final routines = await RoutinesRepository().getAllRoutines();
      final routine = routines.where((r) => r.id == id).firstOrNull;
      if (routine == null || routine.footballMode != null) return null;
      final exercises = RoutineUpdateFromSession.build(routine, _exercises);
      if (exercises == null) return null;
      return RoutineUpdateProposal(routine: routine, exercises: exercises);
    } catch (_) {
      return null;
    }
  }

  /// Marks a set as warm-up, drop, failure or normal. Allowed on completed
  /// sets too: the label does not change what was lifted.
  void updateSetKind(String exerciseId, String setId, SetKind kind) {
    if (!canEdit) return;
    final exercise = _findExercise(exerciseId);
    if (exercise == null || !exercise.sets.any((s) => s.id == setId)) return;
    _exercises = _replaceExercise(
      exercise.copyWith(
        sets: [
          for (final s in exercise.sets)
            s.id == setId ? s.copyWith(kind: kind) : s,
        ],
      ),
    );
    notifyListeners();
    _scheduleAutosave();
  }

  /// First and last index of the superset that contains [exerciseId].
  ({int start, int end})? supersetRange(String exerciseId) {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0) return null;
    final id = _exercises[index].supersetId;
    if (id == null) return null;
    var start = index, end = index;
    while (start > 0 && _exercises[start - 1].supersetId == id) {
      start--;
    }
    while (end < _exercises.length - 1 &&
        _exercises[end + 1].supersetId == id) {
      end++;
    }
    return end > start ? (start: start, end: end) : null;
  }

  /// "A", "B"… in order of appearance, or null outside a superset.
  String? supersetLabel(String exerciseId) {
    final target = _findExercise(exerciseId)?.supersetId;
    if (target == null || supersetRange(exerciseId) == null) return null;
    final order = <String>[];
    for (final e in _exercises) {
      final id = e.supersetId;
      if (id != null && !order.contains(id)) order.add(id);
    }
    final position = order.indexOf(target);
    return String.fromCharCode(65 + position % 26);
  }

  bool canLinkWithNext(String exerciseId) {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0 || index >= _exercises.length - 1) return false;
    final current = _exercises[index], next = _exercises[index + 1];
    if (current.sportPlan != null || next.sportPlan != null) return false;
    return current.supersetId == null || current.supersetId != next.supersetId;
  }

  /// Joins this exercise and the following one (and their groups).
  void linkWithNext(String exerciseId) {
    if (!canEdit || !canLinkWithNext(exerciseId)) return;
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    final current = _exercises[index], next = _exercises[index + 1];
    final id = current.supersetId ?? next.supersetId ?? _uuid.v4();
    final merged = {?current.supersetId, ?next.supersetId};
    _exercises = _normalizedSupersets([
      for (var i = 0; i < _exercises.length; i++)
        i == index ||
                i == index + 1 ||
                (_exercises[i].supersetId != null &&
                    merged.contains(_exercises[i].supersetId))
            ? _exercises[i].copyWith(supersetId: id)
            : _exercises[i],
    ]);
    notifyListeners();
    _scheduleAutosave();
  }

  /// Takes the exercise out of its superset; a group left with one member
  /// stops being a superset.
  void unlinkSuperset(String exerciseId) {
    if (!canEdit) return;
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0 || _exercises[index].supersetId == null) return;
    final range = supersetRange(exerciseId);
    var updated = [..._exercises];
    updated[index] = updated[index].copyWith(clearSuperset: true);
    // Members after the removed one form their own group.
    if (range != null && index > range.start && index < range.end) {
      final newId = _uuid.v4();
      for (var i = index + 1; i <= range.end; i++) {
        updated[i] = updated[i].copyWith(supersetId: newId);
      }
    }
    _exercises = _normalizedSupersets(updated);
    notifyListeners();
    _scheduleAutosave();
  }

  /// A superset is a contiguous run of two or more exercises. Single members
  /// lose the id, and a repeated id in a separate run becomes a new group.
  List<ExerciseInSession> _normalizedSupersets(List<ExerciseInSession> list) {
    final result = [...list];
    final seen = <String>{};
    var i = 0;
    while (i < result.length) {
      final id = result[i].supersetId;
      if (id == null || result[i].sportPlan != null) {
        if (id != null) result[i] = result[i].copyWith(clearSuperset: true);
        i++;
        continue;
      }
      var end = i;
      while (end + 1 < result.length &&
          result[end + 1].supersetId == id &&
          result[end + 1].sportPlan == null) {
        end++;
      }
      if (end == i) {
        result[i] = result[i].copyWith(clearSuperset: true);
      } else if (seen.contains(id)) {
        final fresh = _uuid.v4();
        for (var k = i; k <= end; k++) {
          result[k] = result[k].copyWith(supersetId: fresh);
        }
      } else {
        seen.add(id);
      }
      i = end + 1;
    }
    return result;
  }

  /// Next exercise to do inside a superset: the following member, or after
  /// the last one, the first member that still has sets; when the whole
  /// group is done, the first pending exercise after it.
  ExerciseInSession? _nextInSuperset(int index, ({int start, int end}) group) {
    bool pending(ExerciseInSession e) => e.sets.any((s) => !s.done);
    for (var i = index + 1; i <= group.end; i++) {
      if (pending(_exercises[i])) return _exercises[i];
    }
    for (var i = group.start; i <= index; i++) {
      if (pending(_exercises[i])) return _exercises[i];
    }
    return _firstIncompleteExercise(after: group.end);
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
    bool persist = true,
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
    if (persist) _scheduleAutosave();
    await _suggestHistoryValues(exerciseId, persist: persist);
  }

  Future<void> _suggestHistoryValues(
    String exerciseId, {
    bool persist = true,
  }) async {
    final requested = _findExercise(exerciseId);
    if (requested == null) return;
    try {
      final suggestionsByMode = <String, List<SetEntry>>{};
      final requestedHistory = WorkoutAnalytics.fromLive([requested]).single;
      for (final set in requested.sets) {
        final key = exerciseLoadKey(
          requestedHistory,
          requestedHistory.sets.firstWhere((s) => s.id == set.id),
        );
        suggestionsByMode[key] ??= await _repository.getCompatibleSuggestions(
          requested.copyWith(sets: [set]),
        );
      }
      if (!canEdit) return;
      final current = _findExercise(exerciseId);
      if (current == null) return;
      final currentHistory = WorkoutAnalytics.fromLive([current]).single;
      final sets = <SetInSession>[];
      for (var i = 0; i < current.sets.length; i++) {
        final set = current.sets[i];
        final mode = current.modeFor(set);
        final key = exerciseLoadKey(currentHistory, currentHistory.sets[i]);
        final suggestions = suggestionsByMode[key] ?? const <SetEntry>[];
        if (suggestions.isEmpty) {
          sets.add(set);
          continue;
        }
        final source =
            suggestions[i < suggestions.length ? i : suggestions.length - 1];
        final prefix = '$exerciseId|${set.id}|';
        final load = mode == RoutineExerciseLoadType.assistedKg
            ? source.assistanceKg
            : source.externalLoadKg;
        final safeLoad =
            mode != RoutineExerciseLoadType.bodyweight &&
            !source.loadIsAmbiguous &&
            load != null &&
            load.isFinite &&
            load >= 0;
        final fillLoad =
            !set.done &&
            !_touchedSetFields.contains('${prefix}load') &&
            safeLoad;
        sets.add(
          set.done
              ? set
              : set.copyWith(
                  kg:
                      fillLoad &&
                          mode != RoutineExerciseLoadType.assistedKg &&
                          set.kg == null
                      ? load
                      : null,
                  assistanceKg:
                      fillLoad &&
                          mode == RoutineExerciseLoadType.assistedKg &&
                          set.assistanceKg == null
                      ? load
                      : null,
                  reps:
                      !current.isTimed &&
                          !current.isDistance &&
                          set.reps == null &&
                          !_touchedSetFields.contains('${prefix}reps') &&
                          (source.reps ?? 0) > 0
                      ? source.reps
                      : null,
                  durationSeconds:
                      current.isTimed &&
                          set.durationSeconds == null &&
                          !_touchedSetFields.contains('${prefix}duration') &&
                          (source.durationSeconds ?? 0) > 0
                      ? source.durationSeconds
                      : null,
                  distanceMeters:
                      current.isDistance &&
                          set.distanceMeters == null &&
                          !_touchedSetFields.contains('${prefix}distance') &&
                          source.distanceMeters != null &&
                          source.distanceMeters!.isFinite &&
                          source.distanceMeters! > 0
                      ? source.distanceMeters
                      : null,
                ),
        );
      }
      _exercises = _replaceExercise(current.copyWith(sets: sets));
      notifyListeners();
      if (persist) _scheduleAutosave();
    } catch (_) {
      /* Optional suggestions cannot block recording or clear edits. */
    }
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
        (set) =>
            set.done &&
            set.hasValidResult(
              isTimed: exercise.isTimed,
              isDistance: exercise.isDistance,
            ),
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
          programExecution: _programExecution,
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
            programExecution: _programExecution,
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
