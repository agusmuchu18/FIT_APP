import 'dart:convert';

enum WorkoutType {
  strength,
  cardio,
  functional,
  sport,
  custom,
}

class SetEntry {
  SetEntry({
    required this.id,
    this.reps,
    this.durationSeconds,
    this.rir,
    this.restSeconds,

    // NEW (load components)
    this.externalLoadKg, // barra/mancuerna/lastre
    this.assistanceKg, // asistencia (dominadas asistidas)
    this.bodyweightKg, // snapshot del peso del usuario
    this.bodyweightFactor, // factor (lagartijas)
  });

  final String id;

  final int? reps;
  final int? durationSeconds;
  final int? rir;
  final int? restSeconds;

  final double? externalLoadKg;
  final double? assistanceKg;
  final double? bodyweightKg;
  final double? bodyweightFactor;

  SetEntry copyWith({
    String? id,
    int? reps,
    int? durationSeconds,
    int? rir,
    int? restSeconds,
    double? externalLoadKg,
    double? assistanceKg,
    double? bodyweightKg,
    double? bodyweightFactor,
  }) {
    return SetEntry(
      id: id ?? this.id,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rir: rir ?? this.rir,
      restSeconds: restSeconds ?? this.restSeconds,
      externalLoadKg: externalLoadKg ?? this.externalLoadKg,
      assistanceKg: assistanceKg ?? this.assistanceKg,
      bodyweightKg: bodyweightKg ?? this.bodyweightKg,
      bodyweightFactor: bodyweightFactor ?? this.bodyweightFactor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reps': reps,
        'durationSeconds': durationSeconds,
        'rir': rir,
        'restSeconds': restSeconds,
        'externalLoadKg': externalLoadKg,
        'assistanceKg': assistanceKg,
        'bodyweightKg': bodyweightKg,
        'bodyweightFactor': bodyweightFactor,
      };

  factory SetEntry.fromJson(Map<String, dynamic> json) {
    final legacyWeight = (json['weight'] as num?)?.toDouble();

    return SetEntry(
      id: json['id'] as String,
      reps: json['reps'] as int?,
      durationSeconds: json['durationSeconds'] as int?,
      rir: json['rir'] as int?,
      restSeconds: json['restSeconds'] as int?,
      externalLoadKg: (json['externalLoadKg'] as num?)?.toDouble() ?? legacyWeight,
      assistanceKg: (json['assistanceKg'] as num?)?.toDouble(),
      bodyweightKg: (json['bodyweightKg'] as num?)?.toDouble(),
      bodyweightFactor: (json['bodyweightFactor'] as num?)?.toDouble(),
    );
  }
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.measurement,
    this.notes,
    List<SetEntry>? sets,
  }) : sets = sets ?? [];

  final String id;
  final String name;
  final String? muscleGroup;
  final String? measurement;
  final String? notes;
  final List<SetEntry> sets;

  WorkoutExercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? measurement,
    String? notes,
    List<SetEntry>? sets,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      measurement: measurement ?? this.measurement,
      notes: notes ?? this.notes,
      sets: sets ?? List<SetEntry>.from(this.sets),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'measurement': measurement,
        'notes': notes,
        'sets': sets.map((e) => e.toJson()).toList(),
      };

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) => WorkoutExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String?,
        measurement: json['measurement'] as String?,
        notes: json['notes'] as String?,
        sets: (json['sets'] as List<dynamic>? ?? [])
            .map((e) => SetEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutTemplate {
  WorkoutTemplate({
    required this.id,
    required this.name,
    required this.type,
    this.origin = TemplateOrigin.standard,
    this.activityName,
    List<WorkoutExercise>? exercises,
  }) : exercises = exercises ?? [];

  final String id;
  final String name;
  final WorkoutType type;
  final TemplateOrigin origin;
  final String? activityName;
  final List<WorkoutExercise> exercises;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'origin': origin.name,
        'activityName': activityName,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) => WorkoutTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        type: WorkoutType.values
            .firstWhere((element) => element.name == json['type']),
        origin: TemplateOrigin.values
            .firstWhere((element) => element.name == json['origin'],
                orElse: () => TemplateOrigin.custom),
        activityName: json['activityName'] as String?,
        exercises: (json['exercises'] as List<dynamic>? ?? [])
            .map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
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
        type: WorkoutType.values
            .firstWhere((element) => element.name == json['type']),
        customTypeName: json['customTypeName'] as String?,
        templateId: json['templateId'] as String?,
        templateName: json['templateName'] as String?,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        activityName: json['activityName'] as String?,
        durationMinutes: json['durationMinutes'] as int?,
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
