import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/workout_repository.dart';
import '../domain/session_models.dart';
import '../pro/models/workout_models.dart';
import '../training_home/routines_repository.dart';

class WorkoutSessionController extends ChangeNotifier {
  WorkoutSessionController({WorkoutRepository? repository})
      : _repository = repository ?? WorkoutRepository();

  final WorkoutRepository _repository;
  final Uuid _uuid = const Uuid();

  List<ExerciseInSession> _exercises = [];
  String? _expandedExerciseId;
  Timer? _autosaveTimer;
  String? _routineId;
  String? _routineName;
  DateTime _sessionStart = DateTime.now();

  List<ExerciseInSession> get exercises => _exercises;
  String? get expandedExerciseId => _expandedExerciseId;

  Future<void> initialize({List<ExerciseInSession>? initialExercises, String? templateId}) async {
    _routineId = templateId;
    if (templateId != null) {
      final routines = await RoutinesRepository().getAllRoutines();
      WorkoutTemplate? routine;
      for (final item in routines) {
        if (item.id == templateId) {
          routine = item;
          break;
        }
      }
      if (routine != null) _routineName = routine.name;
    }
    final draft = await _repository.loadDraftExercises();
    if (draft != null && draft.isNotEmpty) {
      _exercises = draft;
    } else if (initialExercises != null && initialExercises.isNotEmpty) {
      _exercises = initialExercises;
      _expandedExerciseId = initialExercises.first.id;
      _scheduleAutosave();
    }
    if (_exercises.isEmpty && templateId != null) {
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
        _exercises = routine.exercises
            .map((exercise) {
              final sets = List.generate(exercise.targetSets, (index) => SetInSession(id: _uuid.v4(), index: index + 1));
              return ExerciseInSession(id: _uuid.v4(), exerciseId: exercise.id, name: exercise.name, sets: sets);
            })
            .toList();
      }
    }
    notifyListeners();
  }

  Future<void> toggleExerciseExpansion(String exerciseId) async {
    _expandedExerciseId = _expandedExerciseId == exerciseId ? null : exerciseId;
    notifyListeners();
    if (_expandedExerciseId != null) {
      await _ensurePreviousForExercise(exerciseId);
    }
  }

  Future<void> addExercise({required String exerciseId, required String name}) async {
    final newExercise = ExerciseInSession(
      id: _uuid.v4(),
      exerciseId: exerciseId,
      name: name,
      sets: [
        SetInSession(id: _uuid.v4(), index: 1),
      ],
    );
    _exercises = [..._exercises, newExercise];
    _expandedExerciseId = newExercise.id;
    notifyListeners();
    await _ensurePreviousForExercise(newExercise.id);
    _scheduleAutosave();
  }

  void removeExercise(String exerciseId) {
    _exercises = _exercises.where((exercise) => exercise.id != exerciseId).toList();
    if (_expandedExerciseId == exerciseId) {
      _expandedExerciseId = null;
    }
    notifyListeners();
    _scheduleAutosave();
  }

  void moveExerciseUp(String exerciseId) {
    final index = _exercises.indexWhere((exercise) => exercise.id == exerciseId);
    if (index <= 0) return;
    final updated = [..._exercises];
    final item = updated.removeAt(index);
    updated.insert(index - 1, item);
    _exercises = updated;
    notifyListeners();
    _scheduleAutosave();
  }

  void moveExerciseDown(String exerciseId) {
    final index = _exercises.indexWhere((exercise) => exercise.id == exerciseId);
    if (index == -1 || index >= _exercises.length - 1) return;
    final updated = [..._exercises];
    final item = updated.removeAt(index);
    updated.insert(index + 1, item);
    _exercises = updated;
    notifyListeners();
    _scheduleAutosave();
  }

  void updateExerciseNotes(String exerciseId, String notes) {
    _exercises = _exercises
        .map((exercise) =>
            exercise.id == exerciseId ? exercise.copyWith(notes: notes) : exercise)
        .toList();
    notifyListeners();
    _scheduleAutosave();
  }

  void updateExerciseRest(String exerciseId, {required bool enabled, int? seconds}) {
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

  void updateSet(String exerciseId, String setId, {double? kg, int? reps, bool? done}) {
    _exercises = _exercises.map((exercise) {
      if (exercise.id != exerciseId) return exercise;
      final sets = exercise.sets
          .map(
            (set) => set.id == setId
                ? set.copyWith(
                    kg: kg ?? set.kg,
                    reps: reps ?? set.reps,
                    done: done ?? set.done,
                  )
                : set,
          )
          .toList();
      return exercise.copyWith(sets: sets);
    }).toList();
    notifyListeners();
    _scheduleAutosave();
  }

  Future<void> addSet(String exerciseId) async {
    final index = _exercises.indexWhere((exercise) => exercise.id == exerciseId);
    if (index == -1) return;
    var exercise = _exercises[index];
    if (!exercise.previousLoaded) {
      await _ensurePreviousForExercise(exerciseId);
      exercise = _exercises[index];
    }
    final setNumber = exercise.sets.length + 1;
    final previousSets = await _repository.getPreviousSetsForExercise(exercise.exerciseId);
    final previous = previousSets.length >= setNumber ? previousSets[setNumber - 1] : null;
    final newSet = SetInSession(id: _uuid.v4(), index: setNumber, previous: previous);
    final updatedExercise = exercise.copyWith(sets: [...exercise.sets, newSet]);
    _exercises = _replaceExercise(updatedExercise);
    notifyListeners();
    _scheduleAutosave();
  }

  Future<void> _ensurePreviousForExercise(String exerciseId) async {
    final exercise = _exercises.firstWhere((item) => item.id == exerciseId);
    if (exercise.previousLoaded) return;

    final previousSets = await _repository.getPreviousSetsForExercise(exercise.exerciseId);
    final mappedSets = exercise.sets
        .map(
          (set) => set.copyWith(
            previous: previousSets.length >= set.index ? previousSets[set.index - 1] : null,
          ),
        )
        .toList();
    _exercises = _replaceExercise(
      exercise.copyWith(
        previousLoaded: true,
        sets: mappedSets,
      ),
    );
    notifyListeners();
    _scheduleAutosave();
  }

  Future<void> discardWorkout() async {
    _autosaveTimer?.cancel();
    _exercises = [];
    _expandedExerciseId = null;
    await _repository.clearDraft();
    notifyListeners();
  }

  Future<void> finishWorkout() async {
    _autosaveTimer?.cancel();
    await _repository.persistCompletedWorkout(
      _exercises,
      routineId: _routineId,
      routineName: _routineName,
      duration: DateTime.now().difference(_sessionStart),
    );
    _exercises = [];
    _expandedExerciseId = null;
    notifyListeners();
  }

  List<ExerciseInSession> _replaceExercise(ExerciseInSession updated) {
    return _exercises
        .map((exercise) => exercise.id == updated.id ? updated : exercise)
        .toList();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 300), () {
      _repository.persistDraft(_exercises);
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
