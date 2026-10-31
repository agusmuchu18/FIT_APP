import '../../domain/training_program.dart';

import 'dart:convert';

import '../../domain/sport_activity.dart';

enum LoadConvention { recorded, total, perImplement }

LoadConvention decodeLoadConvention(Object? raw) {
  if (raw == null) return LoadConvention.recorded;
  for (final value in LoadConvention.values) {
    if (value.name == raw) return value;
  }
  throw const FormatException(
    'Convención de carga desconocida; se conserva el registro original.',
  );
}

enum WorkoutType { strength, cardio, functional, sport, custom }

/// What a set is for. Warm-up sets are recorded but excluded from volume,
/// records and muscle counts; drop and failure sets count normally.
enum SetKind {
  normal('Normal', ''),
  warmup('Calentamiento', 'C'),
  drop('Drop set', 'D'),
  failure('Al fallo', 'F');

  const SetKind(this.label, this.badge);
  final String label;

  /// Short letter shown instead of the set number; empty for normal sets.
  final String badge;

  static SetKind decode(Object? raw) {
    for (final value in SetKind.values) {
      if (value.name == raw) return value;
    }
    return SetKind.normal;
  }
}

enum RoutineExerciseLoadType {
  bodyweight,
  weightedKg,
  assistedKg,
  machineKg,
  addedWeightKg,
}

RoutineExerciseLoadType? decodeSetLoadType(Object? raw) {
  if (raw == null) return null; // Unknown historical semantics stay unknown.
  for (final type in RoutineExerciseLoadType.values) {
    if (type.name == raw) return type;
  }
  throw const FormatException(
    'Modalidad desconocida; se conserva el original.',
  );
}

class RoutineSetTarget {
  const RoutineSetTarget({
    this.reps,
    this.repsMin,
    this.repsMax,
    this.weightKg,
    this.durationSeconds,
    this.loadType,
    this.assistanceKg,
  });
  final int? reps, repsMin, repsMax, durationSeconds;
  final double? weightKg;
  final double? assistanceKg;
  final RoutineExerciseLoadType? loadType;
  double? loadFor(RoutineExerciseLoadType fallback) {
    final mode = loadType ?? fallback;
    if (mode == RoutineExerciseLoadType.bodyweight) return null;
    return mode == RoutineExerciseLoadType.assistedKg
        ? assistanceKg ?? (loadType == null ? weightKg : null)
        : weightKg;
  }

  RoutineSetTarget copyWith({
    int? reps,
    int? repsMin,
    int? repsMax,
    int? durationSeconds,
    double? weightKg,
    double? assistanceKg,
    RoutineExerciseLoadType? loadType,
    bool clearWeight = false,
    bool clearAssistance = false,
  }) => RoutineSetTarget(
    reps: reps ?? this.reps,
    repsMin: repsMin ?? this.repsMin,
    repsMax: repsMax ?? this.repsMax,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    weightKg: clearWeight ? null : weightKg ?? this.weightKg,
    assistanceKg: clearAssistance ? null : assistanceKg ?? this.assistanceKg,
    loadType: loadType ?? this.loadType,
  );
  Map<String, dynamic> toJson() => {
    'reps': reps,
    'repsMin': repsMin,
    'repsMax': repsMax,
    'weightKg': weightKg,
    'durationSeconds': durationSeconds,
    if (loadType != null) 'loadType': loadType!.name,
    if (assistanceKg != null) 'assistanceKg': assistanceKg,
  };
  factory RoutineSetTarget.fromJson(Map<String, dynamic> json) =>
      RoutineSetTarget(
        reps: json['reps'] as int?,
        repsMin: json['repsMin'] as int?,
        repsMax: json['repsMax'] as int?,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        durationSeconds: json['durationSeconds'] as int?,
        loadType: decodeSetLoadType(json['loadType']),
        assistanceKg: (json['assistanceKg'] as num?)?.toDouble(),
      );
}

class SetEntry {
  SetEntry({
    required this.id,
    this.reps,
    this.durationSeconds,
    this.rir,
    this.restSeconds,
    this.done,

    // NEW (load components)
    this.externalLoadKg, // barra/mancuerna/lastre
    this.assistanceKg, // asistencia (dominadas asistidas)
    this.bodyweightKg, // snapshot del peso del usuario
    this.bodyweightFactor, // factor (lagartijas)
    this.loadIsAmbiguous = false,
    this.loadConvention = LoadConvention.recorded,
    this.implementCount,
    this.distanceMeters,
    this.note,
    this.performedAt,
    this.kind = SetKind.normal,
    this.loadType,
  });

  final String id;
  final LoadConvention loadConvention;
  final int? implementCount;
  final double? distanceMeters;
  final String? note;
  final DateTime? performedAt;
  final SetKind kind;
  final RoutineExerciseLoadType? loadType;

  final int? reps;
  final int? durationSeconds;
  final int? rir;
  final int? restSeconds;
  final bool? done;

  final double? externalLoadKg;
  final double? assistanceKg;
  final double? bodyweightKg;
  final double? bodyweightFactor;

  /// Legacy `weight` is preserved but cannot be classified as external load.
  final bool loadIsAmbiguous;

  SetEntry copyWith({
    String? id,
    int? reps,
    int? durationSeconds,
    int? rir,
    int? restSeconds,
    bool? done,
    double? externalLoadKg,
    double? assistanceKg,
    double? bodyweightKg,
    double? bodyweightFactor,
    bool? loadIsAmbiguous,
    LoadConvention? loadConvention,
    int? implementCount,
    double? distanceMeters,
    String? note,
    DateTime? performedAt,
    SetKind? kind,
    RoutineExerciseLoadType? loadType,
  }) {
    return SetEntry(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      loadType: loadType ?? this.loadType,
      loadConvention: loadConvention ?? this.loadConvention,
      implementCount: implementCount ?? this.implementCount,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      note: note ?? this.note,
      performedAt: performedAt ?? this.performedAt,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rir: rir ?? this.rir,
      restSeconds: restSeconds ?? this.restSeconds,
      done: done ?? this.done,
      externalLoadKg: externalLoadKg ?? this.externalLoadKg,
      assistanceKg: assistanceKg ?? this.assistanceKg,
      bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      bodyweightFactor: bodyweightFactor ?? this.bodyweightFactor,
      loadIsAmbiguous: loadIsAmbiguous ?? this.loadIsAmbiguous,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'loadConvention': loadConvention.name,
    if (loadType != null) 'loadType': loadType!.name,
    'implementCount': implementCount,
    'distanceMeters': distanceMeters,
    'note': note,
    'performedAt': performedAt?.toUtc().toIso8601String(),
    'reps': reps,
    'durationSeconds': durationSeconds,
    'rir': rir,
    'restSeconds': restSeconds,
    'done': done,
    'externalLoadKg': externalLoadKg,
    'assistanceKg': assistanceKg,
    'bodyweightKg': bodyweightKg,
    'bodyweightFactor': bodyweightFactor,
    'loadIsAmbiguous': loadIsAmbiguous,
    if (kind != SetKind.normal) 'kind': kind.name,
  };

  factory SetEntry.fromJson(Map<String, dynamic> json) {
    final legacyWeight = (json['weight'] as num?)?.toDouble();

    return SetEntry(
      id: json['id'] as String,
      kind: SetKind.decode(json['kind']),
      loadConvention: decodeLoadConvention(json['loadConvention']),
      loadType: decodeSetLoadType(json['loadType']),
      implementCount: json['implementCount'] as int?,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      note: json['note'] as String?,
      performedAt: DateTime.tryParse(json['performedAt'] as String? ?? ''),
      reps: json['reps'] as int?,
      durationSeconds: json['durationSeconds'] as int?,
      rir: json['rir'] as int?,
      restSeconds: json['restSeconds'] as int?,
      done: json['done'] as bool?,
      externalLoadKg:
          (json['externalLoadKg'] as num?)?.toDouble() ?? legacyWeight,
      assistanceKg: (json['assistanceKg'] as num?)?.toDouble(),
      bodyweightKg: (json['bodyweightKg'] as num?)?.toDouble(),
      bodyweightFactor: (json['bodyweightFactor'] as num?)?.toDouble(),
      loadIsAmbiguous:
          json['loadIsAmbiguous'] as bool? ??
          (json['externalLoadKg'] == null && legacyWeight != null),
    );
  }
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment,
    this.measurement,
    this.notes,
    this.targetSets = 3,
    this.targetReps,
    this.targetDurationSeconds,
    this.targetRepsMin = 8,
    this.targetRepsMax = 12,
    this.targetLoadType = RoutineExerciseLoadType.bodyweight,
    this.targetWeightKg,
    this.targetAssistanceKg,
    this.loadSchemaVersion = 0,
    this.restSeconds,
    this.rir,
    List<SetEntry>? sets,
    this.restEnabled,
    this.instanceId,
    this.setTargets = const [],
    this.sportPlan,
    this.sportResult,
    this.sportPurpose,
    this.supersetId,
  }) : sets = sets ?? [];

  final String id;
  final String name;

  /// Exercises sharing this id are done back to back; rest comes after the
  /// last one of the group.
  final String? supersetId;
  final String? muscleGroup;
  final String? equipment;
  final String? measurement;
  final String? notes;
  final int targetSets;
  final int? targetReps;
  final int? targetDurationSeconds;
  bool get isTimed =>
      measurement == 'time' ||
      measurement == 'seconds' ||
      targetDurationSeconds != null;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final RoutineExerciseLoadType targetLoadType;
  final double? targetWeightKg;
  final double? targetAssistanceKg;
  final int loadSchemaVersion;
  double? get plannedLoad => switch (targetLoadType) {
    RoutineExerciseLoadType.bodyweight => null,
    RoutineExerciseLoadType.assistedKg =>
      targetAssistanceKg ?? (loadSchemaVersion == 0 ? targetWeightKg : null),
    _ => targetWeightKg,
  };
  final int? restSeconds;
  final int? rir;
  final List<SetEntry> sets;
  final bool? restEnabled;
  final String? instanceId;
  final List<RoutineSetTarget> setTargets;
  final SportActivityPlan? sportPlan;
  final SportMeasurements? sportResult;
  final FootballGymPurpose? sportPurpose;

  WorkoutExercise copyWith({
    bool? restEnabled,
    String? instanceId,
    List<RoutineSetTarget>? setTargets,
    SportActivityPlan? sportPlan,
    SportMeasurements? sportResult,
    bool clearSportResult = false,
    FootballGymPurpose? sportPurpose,
    String? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    String? measurement,
    String? notes,
    int? targetSets,
    int? targetReps,
    bool clearTargetReps = false,
    int? targetDurationSeconds,
    bool clearTargetDuration = false,
    int? targetRepsMin,
    int? targetRepsMax,
    RoutineExerciseLoadType? targetLoadType,
    double? targetWeightKg,
    double? targetAssistanceKg,
    int? loadSchemaVersion,
    bool clearTargetAssistanceKg = false,
    bool clearTargetWeightKg = false,
    int? restSeconds,
    bool clearRestSeconds = false,
    int? rir,
    List<SetEntry>? sets,
    String? supersetId,
    bool clearSuperset = false,
  }) {
    return WorkoutExercise(
      supersetId: clearSuperset ? null : supersetId ?? this.supersetId,
      restEnabled: restEnabled ?? this.restEnabled,
      instanceId: instanceId ?? this.instanceId,
      setTargets: setTargets ?? this.setTargets,
      sportPlan: sportPlan ?? this.sportPlan,
      sportPurpose: sportPurpose ?? this.sportPurpose,
      sportResult: clearSportResult ? null : sportResult ?? this.sportResult,
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      measurement: measurement ?? this.measurement,
      notes: notes ?? this.notes,
      targetSets: targetSets ?? this.targetSets,
      targetReps: clearTargetReps ? null : (targetReps ?? this.targetReps),
      targetDurationSeconds: clearTargetDuration
          ? null
          : (targetDurationSeconds ?? this.targetDurationSeconds),
      targetRepsMin: targetRepsMin ?? this.targetRepsMin,
      targetRepsMax: targetRepsMax ?? this.targetRepsMax,
      targetLoadType: targetLoadType ?? this.targetLoadType,
      loadSchemaVersion: loadSchemaVersion ?? this.loadSchemaVersion,
      targetAssistanceKg: clearTargetAssistanceKg
          ? null
          : targetAssistanceKg ?? this.targetAssistanceKg,
      targetWeightKg: clearTargetWeightKg
          ? null
          : (targetWeightKg ?? this.targetWeightKg),
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      rir: rir ?? this.rir,
      sets: sets ?? List<SetEntry>.from(this.sets),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'measurement': measurement,
    'notes': notes,
    'targetSets': targetSets,
    'instanceId': instanceId,
    'setTargets': setTargets.map((e) => e.toJson()).toList(),
    'sportPlan': sportPlan?.toJson(),
    'sportResult': sportResult?.toJson(),
    'sportPurpose': sportPurpose?.name,
    'restEnabled': restEnabled,
    'targetReps': targetReps,
    'targetDurationSeconds': targetDurationSeconds,
    'targetRepsMin': targetRepsMin,
    'targetRepsMax': targetRepsMax,
    'targetLoadType': targetLoadType.name,
    'targetWeightKg': targetWeightKg,
    if (targetAssistanceKg != null) 'targetAssistanceKg': targetAssistanceKg,
    if (loadSchemaVersion != 0) 'loadSchemaVersion': loadSchemaVersion,
    'restSeconds': restSeconds,
    'rir': rir,
    'sets': sets.map((e) => e.toJson()).toList(),
    if (supersetId != null) 'supersetId': supersetId,
  };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final serializedSets = (json['sets'] as List<dynamic>? ?? [])
        .map((e) => SetEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final targetWeightKg = (json['targetWeightKg'] as num?)?.toDouble();
    final targetLoadType = RoutineExerciseLoadType.values.firstWhere(
      (value) => value.name == json['targetLoadType'],
      orElse: () {
        if (targetWeightKg != null) return RoutineExerciseLoadType.weightedKg;
        final equipment = (json['equipment'] as String? ?? '').toLowerCase();
        if (equipment.contains('machine') || equipment.contains('máquina')) {
          return RoutineExerciseLoadType.machineKg;
        }
        return RoutineExerciseLoadType.bodyweight;
      },
    );

    return WorkoutExercise(
      id: json['id'] as String,
      name: json['name'] as String,
      instanceId: json['instanceId'] as String?,
      supersetId: json['supersetId'] as String?,
      sportPurpose: json['sportPurpose'] == null
          ? null
          : FootballGymPurpose.values.byName(json['sportPurpose'] as String),
      setTargets: (json['setTargets'] as List<dynamic>? ?? [])
          .map((e) => RoutineSetTarget.fromJson(e as Map<String, dynamic>))
          .toList(),
      sportPlan: json['sportPlan'] is Map<String, dynamic>
          ? SportActivityPlan.fromJson(
              json['sportPlan'] as Map<String, dynamic>,
            )
          : null,
      sportResult: json['sportResult'] is Map<String, dynamic>
          ? SportMeasurements.fromJson(
              json['sportResult'] as Map<String, dynamic>,
            )
          : null,
      muscleGroup: json['muscleGroup'] as String?,
      restEnabled: json['restEnabled'] as bool?,
      equipment: json['equipment'] as String?,
      measurement: json['measurement'] as String?,
      notes: json['notes'] as String?,
      targetSets:
          (json['targetSets'] as int?) ??
          (serializedSets.isEmpty ? 3 : serializedSets.length),
      targetReps: json['targetReps'] as int?,
      targetDurationSeconds: json['targetDurationSeconds'] as int?,
      targetRepsMin: (json['targetRepsMin'] as int?) ?? 8,
      targetRepsMax: (json['targetRepsMax'] as int?) ?? 12,
      targetLoadType: targetLoadType,
      targetWeightKg: targetWeightKg,
      targetAssistanceKg: (json['targetAssistanceKg'] as num?)?.toDouble(),
      loadSchemaVersion: json['loadSchemaVersion'] as int? ?? 0,
      restSeconds: json['restSeconds'] as int?,
      rir: json['rir'] as int?,
      sets: serializedSets,
    );
  }
}

class WorkoutTemplate {
  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.origin = TemplateOrigin.standard,
    this.activityName,
    this.folderId,
    this.notes,
    this.footballMode,
    List<WorkoutExercise>? exercises,
  }) : exercises = exercises ?? [];

  final String id;
  final String name;
  final WorkoutType type;
  final TemplateOrigin origin;
  final String? activityName;
  final String? folderId;
  final String? notes;
  final FootballMode? footballMode;
  final List<WorkoutExercise> exercises;

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    WorkoutType? type,
    String? folderId,
    bool clearFolder = false,
    List<WorkoutExercise>? exercises,
    String? notes,
    FootballMode? footballMode,
    bool clearFootballMode = false,
  }) => WorkoutTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    origin: origin,
    activityName: activityName,
    folderId: clearFolder ? null : folderId ?? this.folderId,
    exercises: exercises ?? this.exercises,
    notes: notes ?? this.notes,
    footballMode: clearFootballMode ? null : footballMode ?? this.footballMode,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'id': id,
    'name': name,
    'type': type.name,
    'notes': notes,
    'footballMode': footballMode?.name,
    'origin': origin.name,
    'activityName': activityName,
    'folderId': folderId,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) =>
      WorkoutTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        type: WorkoutType.values.firstWhere(
          (element) => element.name == json['type'],
        ),
        origin: TemplateOrigin.values.firstWhere(
          (element) => element.name == json['origin'],
          orElse: () => TemplateOrigin.custom,
        ),
        activityName: json['activityName'] as String?,
        folderId: json['folderId'] as String?,
        notes: json['notes'] as String?,
        footballMode: json['footballMode'] is String
            ? FootballMode.values.byName(json['footballMode'] as String)
            : null,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RoutineFolder {
  const RoutineFolder({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.color,
    this.icon,
  });

  final String id;
  final String name;
  final int sortOrder;
  final int? color;
  final String? icon;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sortOrder': sortOrder,
    'color': color,
    'icon': icon,
  };

  factory RoutineFolder.fromJson(Map<String, dynamic> json) {
    return RoutineFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      color: json['color'] as int?,
      icon: json['icon'] as String?,
    );
  }
}

enum TemplateOrigin { standard, user, custom }

class WorkoutSession {
  WorkoutSession({
    required this.id,
    required this.type,
    required this.date,
    this.customTypeName,
    this.templateId,
    this.templateName,
    this.activityName,
    this.durationMinutes,
    this.durationSeconds,
    this.durationIsActive,
    this.totalDurationSeconds,
    this.startedAt,
    this.sourceSessionId,
    this.programExecution,
    this.distanceKm,
    this.pace,
    this.rpe,
    this.fatigue,
    this.notes,
    this.exercises = const [],
    this.closingDuration,
    this.closingFatigue,
    this.closingPerformance,
    this.finalNotes,
  });

  final String id;
  final WorkoutType type;
  final DateTime date;
  final String? customTypeName;
  final String? templateId;
  final String? templateName;
  final String? activityName;
  final int? durationMinutes;
  final int? durationSeconds;

  /// True excludes pauses, but includes rest. Null means legacy semantics unknown.
  final bool? durationIsActive;
  final int? totalDurationSeconds;
  final DateTime? startedAt;
  final String? sourceSessionId;
  final ProgramExecutionRef? programExecution;
  final double? distanceKm;
  final String? pace;
  final int? rpe;
  final int? fatigue;
  final String? notes;
  final List<WorkoutExercise> exercises;
  final int? closingDuration;
  final int? closingFatigue;
  final int? closingPerformance;
  final String? finalNotes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'customTypeName': customTypeName,
    'templateId': templateId,
    'templateName': templateName,
    'date': date.toIso8601String(),
    'activityName': activityName,
    'durationMinutes': durationMinutes,
    'durationSeconds': durationSeconds,
    'durationIsActive': durationIsActive,
    'totalDurationSeconds': totalDurationSeconds,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'sourceSessionId': sourceSessionId,
    'programExecution': programExecution?.toJson(),
    'distanceKm': distanceKm,
    'pace': pace,
    'rpe': rpe,
    'fatigue': fatigue,
    'notes': notes,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'closingDuration': closingDuration,
    'closingFatigue': closingFatigue,
    'closingPerformance': closingPerformance,
    'finalNotes': finalNotes,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'] as String,
    type: WorkoutType.values.firstWhere(
      (element) => element.name == json['type'],
    ),
    customTypeName: json['customTypeName'] as String?,
    templateId: json['templateId'] as String?,
    templateName: json['templateName'] as String?,
    date: DateTime.parse(json['date'] as String),
    activityName: json['activityName'] as String?,
    durationMinutes: json['durationMinutes'] as int?,
    durationSeconds: json['durationSeconds'] as int?,
    durationIsActive: json['durationIsActive'] as bool?,
    totalDurationSeconds: json['totalDurationSeconds'] as int?,
    startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    sourceSessionId: json['sourceSessionId'] as String?,
    programExecution: json['programExecution'] is Map
        ? ProgramExecutionRef.fromJson(
            Map<String, dynamic>.from(json['programExecution'] as Map),
          )
        : null,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
    pace: json['pace'] as String?,
    rpe: json['rpe'] as int?,
    fatigue: json['fatigue'] as int?,
    notes: json['notes'] as String?,
    exercises: (json['exercises'] as List<dynamic>? ?? [])
        .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
    closingDuration: json['closingDuration'] as int?,
    closingFatigue: json['closingFatigue'] as int?,
    closingPerformance: json['closingPerformance'] as int?,
    finalNotes: json['finalNotes'] as String?,
  );

  String toJsonString() => jsonEncode(toJson());
}
