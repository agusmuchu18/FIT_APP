
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

  bool get isBodyweightEffective => loadType == LoadType.bodyweight_effective;

  bool get needsUserWeight =>
      loadType == LoadType.bodyweight_effective ||
      loadType == LoadType.bodyweight_plus_external ||
      loadType == LoadType.assisted_bodyweight;
}

class ExerciseLibraryIndex {
  ExerciseLibraryIndex(this.exercises)
      : _byKey = _buildIndex(exercises),
        _primaryById = _buildPrimaryIndex(exercises),
        _normalizedNameById = _buildNameIndex(exercises),
        _normalizedAliasesById = _buildAliasIndex(exercises);

  final List<ExerciseDefinition> exercises;

  final Map<String, ExerciseDefinition> _byKey;
  final Map<String, Set<String>> _primaryById;
  final Map<String, String> _normalizedNameById;
  final Map<String, List<String>> _normalizedAliasesById;

  static String _normalizeNullable(String? value) =>
      (value ?? '').trim().toLowerCase();

  static String _normalize(String value) => _normalizeNullable(value);

  static Map<String, ExerciseDefinition> _buildIndex(
    List<ExerciseDefinition> exercises,
  ) {
    final map = <String, ExerciseDefinition>{};

    for (final exercise in exercises) {
      final normalizedName = _normalize(exercise.name);
      if (normalizedName.isNotEmpty) {
        _insertIndexEntry(map, normalizedName, exercise);
      }

      for (final alias in exercise.aliases) {
        final normalizedAlias = _normalizeNullable(alias);
        if (normalizedAlias.isEmpty) continue;
        _insertIndexEntry(map, normalizedAlias, exercise);
      }
    }

    return map;
  }

  static void _insertIndexEntry(
    Map<String, ExerciseDefinition> map,
    String key,
    ExerciseDefinition exercise,
  ) {
    final existing = map[key];
    if (existing == null) {
      map[key] = exercise;
      return;
    }

    // Duplicated normalized keys keep the first registered exercise.
    assert(
      () {
        // ignore: avoid_print
        print(
          'ExerciseLibraryIndex duplicate key "$key": '
          '${existing.id} kept, ${exercise.id} ignored',
        );
        return true;
      }(),
    );
  }

  static Map<String, Set<String>> _buildPrimaryIndex(
    List<ExerciseDefinition> exercises,
  ) {
    final map = <String, Set<String>>{};

    for (final exercise in exercises) {
      final normalizedMuscles = exercise.primaryMuscles
          .map(_normalizeNullable)
          .where((muscle) => muscle.isNotEmpty)
          .toSet();
      map[exercise.id] = normalizedMuscles;
    }

    return map;
  }

  static Map<String, String> _buildNameIndex(List<ExerciseDefinition> exercises) {
    final map = <String, String>{};
    for (final exercise in exercises) {
      map[exercise.id] = _normalize(exercise.name);
    }
    return map;
  }

  static Map<String, List<String>> _buildAliasIndex(
    List<ExerciseDefinition> exercises,
  ) {
    final map = <String, List<String>>{};
    for (final exercise in exercises) {
      map[exercise.id] = exercise.aliases
          .map(_normalizeNullable)
          .where((alias) => alias.isNotEmpty)
          .toList();
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
          (e) =>
              (_normalizedNameById[e.id]?.contains(normalized) ?? false) ||
              (_normalizedAliasesById[e.id]?.any(
                    (alias) => alias.contains(normalized),
                  ) ??
                  false),
        )
        .toList();
  }

  List<ExerciseDefinition> filterByPrimary(String muscle) {
    final normalizedMuscle = _normalize(muscle);

    return exercises
        .where(
          (e) => _primaryById[e.id]?.contains(normalizedMuscle) ?? false,
        )
        .toList();
  }

  List<ExerciseDefinition> filterByEquipment(String equipment) {
    final normalizedEquipment = _normalize(equipment);

    return exercises
        .where((e) => _normalize(e.equipment) == normalizedEquipment)
        .toList();
  }

  List<ExerciseDefinition> filterByPattern(String pattern) {
    final normalizedPattern = _normalize(pattern);

    return exercises
        .where((e) => _normalize(e.movementPattern) == normalizedPattern)
        .toList();
  }
}
