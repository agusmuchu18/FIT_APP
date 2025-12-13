
enum LoadType {
  external,
  bodyweight_effective,
  bodyweight_plus_external,
  assisted_bodyweight,
}

class ExerciseDefinition {
  ExerciseDefinition({
    required this.id,
    required this.name,
    required this.aliases,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.movementPattern,
    required this.defaultMeasurement,
    required this.loadType,
    this.bodyweightFactor,
    this.allowExternalLoad = false,
    this.isUnilateral = false,
    this.isTimed = false,
  });

  final String id;
  final String name;
  final List<String> aliases;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String equipment;
  final String movementPattern;
  final String defaultMeasurement;
  final LoadType loadType;
  final double? bodyweightFactor;
  final bool allowExternalLoad;
  final bool isUnilateral;
  final bool isTimed;

  bool get needsUserWeight =>
      loadType == LoadType.bodyweight_effective ||
      loadType == LoadType.bodyweight_plus_external ||
      loadType == LoadType.assisted_bodyweight;
}

class ExerciseLibraryIndex {
  ExerciseLibraryIndex(this.exercises)
      : _byKey = _buildIndex(exercises),
        _normalizedPrimary = _buildPrimaryIndex(exercises);

  final List<ExerciseDefinition> exercises;

  final Map<String, ExerciseDefinition> _byKey;
  final Map<ExerciseDefinition, List<String>> _normalizedPrimary;

  static String _normalize(String value) => value.trim().toLowerCase();

  static Map<String, ExerciseDefinition> _buildIndex(
    List<ExerciseDefinition> exercises,
  ) {
    final map = <String, ExerciseDefinition>{};

    for (final exercise in exercises) {
      map[_normalize(exercise.name)] = exercise;
      for (final alias in exercise.aliases) {
        map[_normalize(alias)] = exercise;
      }
    }

    return map;
  }

  static Map<ExerciseDefinition, List<String>> _buildPrimaryIndex(
    List<ExerciseDefinition> exercises,
  ) {
    final map = <ExerciseDefinition, List<String>>{};

    for (final exercise in exercises) {
      map[exercise] = exercise.primaryMuscles.map(_normalize).toList();
    }

    return map;
  }

  ExerciseDefinition? findByQuery(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return null;
    return _byKey[normalized];
  }

  List<ExerciseDefinition> search(String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return exercises;
    return exercises
        .where(
          (e) => e.name.toLowerCase().contains(normalized) ||
              e.aliases.any((a) => a.toLowerCase().contains(normalized)),
        )
        .toList();
  }

  List<ExerciseDefinition> filterByPrimary(String muscle) {
    final normalizedMuscle = _normalize(muscle);

    return exercises
        .where(
          (e) =>
              _normalizedPrimary[e]?.any((primary) => primary == normalizedMuscle) ??
              false,
        )
        .toList();
  }

  List<ExerciseDefinition> filterByEquipment(String equipment) =>
      exercises.where((e) => e.equipment == equipment).toList();

  List<ExerciseDefinition> filterByPattern(String pattern) =>
      exercises.where((e) => e.movementPattern == pattern).toList();
}
