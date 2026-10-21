import '../pro/models/workout_models.dart';
import 'sport_activity.dart';
import 'training_units.dart';

class PreviousSet {
  const PreviousSet({
    required this.kg,
    required this.reps,
    this.durationSeconds,
    this.assistanceKg,
  });

  final double? kg;
  final int? reps;
  final int? durationSeconds;
  final double? assistanceKg;

  String get label => labelFor(const TrainingUnits());
  String labelFor(TrainingUnits units) {
    if (durationSeconds != null) return '${durationSeconds}s';
    if (assistanceKg != null && reps != null) {
      return '${units.valueWithUnit('kg', assistanceKg!)} asist. × $reps';
    }
    if (reps == null) return '—';
    if (kg == null || kg == 0) return '$reps reps';
    return '${units.valueWithUnit('kg', kg!)} × $reps';
  }

  Map<String, dynamic> toJson() => {
    'kg': kg,
    'reps': reps,
    'durationSeconds': durationSeconds,
    'assistanceKg': assistanceKg,
  };

  factory PreviousSet.fromJson(Map<String, dynamic> json) {
    return PreviousSet(
      kg: (json['kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      durationSeconds: json['durationSeconds'] as int?,
      assistanceKg: (json['assistanceKg'] as num?)?.toDouble(),
    );
  }
}

class SetInSession {
  const SetInSession({
    required this.id,
    required this.index,
    this.kg,
    this.reps,
    this.durationSeconds,
    this.assistanceKg,
    this.done = false,
    this.previous,
    this.loadConvention = LoadConvention.recorded,
    this.implementCount,
    this.distanceMeters,
    this.rir,
    this.note,
    this.performedAt,
  });

  final String id;
  final LoadConvention loadConvention;
  final int? implementCount, rir;
  final double? distanceMeters;
  final String? note;
  final DateTime? performedAt;
  final int index;
  final double? kg;
  final int? reps;
  final int? durationSeconds;
  final double? assistanceKg;
  final bool done;
  final PreviousSet? previous;

  SetInSession copyWith({
    String? id,
    int? index,
    double? kg,
    bool clearKg = false,
    int? reps,
    bool clearReps = false,
    int? durationSeconds,
    bool clearDuration = false,
    double? assistanceKg,
    bool clearAssistance = false,
    bool? done,
    PreviousSet? previous,
    LoadConvention? loadConvention,
    int? implementCount,
    double? distanceMeters,
    bool clearDistance = false,
    int? rir,
    bool clearRir = false,
    String? note,
    DateTime? performedAt,
  }) {
    return SetInSession(
      id: id ?? this.id,
      loadConvention: loadConvention ?? this.loadConvention,
      implementCount: implementCount ?? this.implementCount,
      distanceMeters: clearDistance
          ? null
          : distanceMeters ?? this.distanceMeters,
      rir: clearRir ? null : rir ?? this.rir,
      note: note ?? this.note,
      performedAt: performedAt ?? this.performedAt,
      index: index ?? this.index,
      kg: clearKg ? null : (kg ?? this.kg),
      reps: clearReps ? null : (reps ?? this.reps),
      durationSeconds: clearDuration
          ? null
          : (durationSeconds ?? this.durationSeconds),
      assistanceKg: clearAssistance
          ? null
          : (assistanceKg ?? this.assistanceKg),
      done: done ?? this.done,
      previous: previous ?? this.previous,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'loadConvention': loadConvention.name,
    'implementCount': implementCount,
    'distanceMeters': distanceMeters,
    'rir': rir,
    'note': note,
    'performedAt': performedAt?.toUtc().toIso8601String(),
    'index': index,
    'kg': kg,
    'reps': reps,
    'durationSeconds': durationSeconds,
    'assistanceKg': assistanceKg,
    'done': done,
    'previous': previous?.toJson(),
  };

  factory SetInSession.fromJson(Map<String, dynamic> json) {
    final previousJson = json['previous'];
    return SetInSession(
      id: json['id'] as String,
      loadConvention: decodeLoadConvention(json['loadConvention']),
      implementCount: json['implementCount'] as int?,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      rir: json['rir'] as int?,
      note: json['note'] as String?,
      performedAt: DateTime.tryParse(json['performedAt'] as String? ?? ''),
      index: (json['index'] as int?) ?? 1,
      kg: (json['kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      durationSeconds: json['durationSeconds'] as int?,
      assistanceKg: (json['assistanceKg'] as num?)?.toDouble(),
      done: json['done'] as bool? ?? false,
      previous: previousJson is Map<String, dynamic>
          ? PreviousSet.fromJson(previousJson)
          : null,
    );
  }

  bool hasValidResult({required bool isTimed, bool isDistance = false}) =>
      (loadConvention != LoadConvention.perImplement ||
          implementCount == 1 ||
          implementCount == 2) &&
      (kg == null || (kg!.isFinite && kg! >= 0)) &&
      (assistanceKg == null ||
          (assistanceKg!.isFinite && assistanceKg! >= 0)) &&
      (isDistance
          ? distanceMeters != null &&
                distanceMeters!.isFinite &&
                distanceMeters! > 0
          : isTimed
          ? (durationSeconds ?? 0) > 0
          : (reps ?? 0) > 0);
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
    this.isTimed = false,
    this.isDistance = false,
    this.isAssisted = false,
    this.sets = const [],
    this.plan,
    this.sportResult,
  });

  final String id;
  final String exerciseId;
  final String name;
  final String? notes;
  final bool restEnabled;
  final int? restSeconds;
  final bool previousLoaded;
  final bool isTimed;
  final bool isDistance;
  final bool isAssisted;
  final List<SetInSession> sets;
  final WorkoutExercise? plan;
  SportActivityPlan? get sportPlan => plan?.sportPlan;
  final SportMeasurements? sportResult;

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
    bool? isTimed,
    bool? isDistance,
    bool? isAssisted,
    List<SetInSession>? sets,
    WorkoutExercise? plan,
    SportMeasurements? sportResult,
    bool clearSportResult = false,
  }) {
    return ExerciseInSession(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      notes: clearNotes ? null : (notes ?? this.notes),
      restEnabled: restEnabled ?? this.restEnabled,
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      previousLoaded: previousLoaded ?? this.previousLoaded,
      isTimed: isTimed ?? this.isTimed,
      isDistance: isDistance ?? this.isDistance,
      isAssisted: isAssisted ?? this.isAssisted,
      sets: sets ?? this.sets,
      plan: plan ?? this.plan,
      sportResult: clearSportResult ? null : sportResult ?? this.sportResult,
    );
  }

  int get doneSets => sets.where((set) => set.done).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'plan': plan?.toJson(),
    'sportResult': sportResult?.toJson(),
    'name': name,
    'notes': notes,
    'restEnabled': restEnabled,
    'restSeconds': restSeconds,
    'previousLoaded': previousLoaded,
    'isTimed': isTimed,
    'isDistance': isDistance,
    'isAssisted': isAssisted,
    'sets': sets.map((set) => set.toJson()).toList(),
  };

  factory ExerciseInSession.fromJson(Map<String, dynamic> json) {
    return ExerciseInSession(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String? ?? json['id'] as String,
      plan: json['plan'] is Map<String, dynamic>
          ? WorkoutExercise.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      sportResult: json['sportResult'] is Map<String, dynamic>
          ? SportMeasurements.fromJson(
              json['sportResult'] as Map<String, dynamic>,
            )
          : null,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      restEnabled: json['restEnabled'] as bool? ?? false,
      restSeconds: json['restSeconds'] as int?,
      previousLoaded: json['previousLoaded'] as bool? ?? false,
      isTimed: json['isTimed'] as bool? ?? false,
      isDistance: json['isDistance'] as bool? ?? false,
      isAssisted: json['isAssisted'] as bool? ?? false,
      sets: (json['sets'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                SetInSession.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}
