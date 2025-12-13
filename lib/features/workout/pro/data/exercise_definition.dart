
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
}

class ExerciseLibraryIndex {
  ExerciseLibraryIndex(this.exercises);

  final List<ExerciseDefinition> exercises;
  Map<String, ExerciseDefinition> get _byName => {
        for (final e in exercises) e.name.toLowerCase(): e,
        for (final e in exercises)
          for (final alias in e.aliases)
            alias.toLowerCase(): e,
      };

  ExerciseDefinition? findByQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return _byName[normalized];
  }

  List<ExerciseDefinition> search(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return exercises;
    return exercises
        .where(
          (e) => e.name.toLowerCase().contains(normalized) ||
              e.aliases.any((a) => a.toLowerCase().contains(normalized)),
        )
        .toList();
  }

  List<ExerciseDefinition> filterByPrimary(String muscle) => exercises
      .where((e) => e.primaryMuscles.contains(muscle.toLowerCase()))
      .toList();

  List<ExerciseDefinition> filterByEquipment(String equipment) =>
      exercises.where((e) => e.equipment == equipment).toList();

  List<ExerciseDefinition> filterByPattern(String pattern) =>
      exercises.where((e) => e.movementPattern == pattern).toList();
}
