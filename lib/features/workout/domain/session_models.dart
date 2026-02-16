class PreviousSet {
  const PreviousSet({
    required this.kg,
    required this.reps,
  });

  final double? kg;
  final int? reps;

  String get label {
    if (kg == null || reps == null) return '—';
    final kgLabel = kg == kg!.roundToDouble() ? kg!.toStringAsFixed(0) : kg!.toStringAsFixed(1);
    return '$kgLabel x $reps';
  }

  Map<String, dynamic> toJson() => {
        'kg': kg,
        'reps': reps,
      };

  factory PreviousSet.fromJson(Map<String, dynamic> json) {
    return PreviousSet(
      kg: (json['kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
    );
  }
}

class SetInSession {
  const SetInSession({
    required this.id,
    required this.index,
    this.kg,
    this.reps,
    this.done = false,
    this.previous,
  });

  final String id;
  final int index;
  final double? kg;
  final int? reps;
  final bool done;
  final PreviousSet? previous;

  SetInSession copyWith({
    String? id,
    int? index,
    double? kg,
    bool clearKg = false,
    int? reps,
    bool clearReps = false,
    bool? done,
    PreviousSet? previous,
  }) {
    return SetInSession(
      id: id ?? this.id,
      index: index ?? this.index,
      kg: clearKg ? null : (kg ?? this.kg),
      reps: clearReps ? null : (reps ?? this.reps),
      done: done ?? this.done,
      previous: previous ?? this.previous,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'index': index,
        'kg': kg,
        'reps': reps,
        'done': done,
        'previous': previous?.toJson(),
      };

  factory SetInSession.fromJson(Map<String, dynamic> json) {
    final previousJson = json['previous'];
    return SetInSession(
      id: json['id'] as String,
      index: (json['index'] as int?) ?? 1,
      kg: (json['kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      done: json['done'] as bool? ?? false,
      previous: previousJson is Map<String, dynamic> ? PreviousSet.fromJson(previousJson) : null,
    );
  }
}

class ExerciseInSession {
  const ExerciseInSession({
    required this.id,
    required this.exerciseId,
    required this.name,
    this.notes,
    this.restEnabled = false,
    this.restSeconds,
    this.previousLoaded = false,
    this.sets = const [],
  });

  final String id;
  final String exerciseId;
  final String name;
  final String? notes;
  final bool restEnabled;
  final int? restSeconds;
  final bool previousLoaded;
  final List<SetInSession> sets;

  ExerciseInSession copyWith({
    String? id,
    String? exerciseId,
    String? name,
    String? notes,
    bool clearNotes = false,
    bool? restEnabled,
    int? restSeconds,
    bool clearRestSeconds = false,
    bool? previousLoaded,
    List<SetInSession>? sets,
  }) {
    return ExerciseInSession(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      restEnabled: restEnabled ?? this.restEnabled,
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      previousLoaded: previousLoaded ?? this.previousLoaded,
      sets: sets ?? this.sets,
    );
  }

  int get doneSets => sets.where((set) => set.done).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'name': name,
        'notes': notes,
        'restEnabled': restEnabled,
        'restSeconds': restSeconds,
        'previousLoaded': previousLoaded,
        'sets': sets.map((set) => set.toJson()).toList(),
      };

  factory ExerciseInSession.fromJson(Map<String, dynamic> json) {
    return ExerciseInSession(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String? ?? json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      restEnabled: json['restEnabled'] as bool? ?? false,
      restSeconds: json['restSeconds'] as int?,
      previousLoaded: json['previousLoaded'] as bool? ?? false,
      sets: (json['sets'] as List<dynamic>? ?? [])
          .map((item) => SetInSession.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
