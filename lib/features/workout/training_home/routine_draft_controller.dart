import 'package:flutter/foundation.dart';

import 'template_workout_type.dart';

class RoutineDraftController extends ChangeNotifier {
  RoutineDraftController({
    this.workoutType = TemplateWorkoutType.gym,
    List<String> initialSelectedExerciseIds = const [],
  }) : _selectedExerciseIds = List<String>.from(initialSelectedExerciseIds);

  TemplateWorkoutType workoutType;
  final List<String> _selectedExerciseIds;

  List<String> get selectedExerciseIds => List<String>.unmodifiable(_selectedExerciseIds);
  int get selectedCount => _selectedExerciseIds.length;

  void setWorkoutType(TemplateWorkoutType type) {
    workoutType = type;
    notifyListeners();
  }

  bool contains(String exerciseId) => _selectedExerciseIds.contains(exerciseId);

  void toggleExercise(String exerciseId) {
    if (contains(exerciseId)) {
      _selectedExerciseIds.remove(exerciseId);
    } else {
      _selectedExerciseIds.add(exerciseId);
    }
    notifyListeners();
  }

  void removeExercise(String exerciseId) {
    _selectedExerciseIds.remove(exerciseId);
    notifyListeners();
  }

  void removeExerciseAt(int index) {
    if (index < 0 || index >= _selectedExerciseIds.length) return;
    _selectedExerciseIds.removeAt(index);
    notifyListeners();
  }

  void insertExerciseAt(int index, String exerciseId) {
    final safeIndex = index.clamp(0, _selectedExerciseIds.length) as int;
    _selectedExerciseIds.insert(safeIndex, exerciseId);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = _selectedExerciseIds.removeAt(oldIndex);
    _selectedExerciseIds.insert(newIndex, moved);
    notifyListeners();
  }

  void clear() {
    _selectedExerciseIds.clear();
    notifyListeners();
  }
}
