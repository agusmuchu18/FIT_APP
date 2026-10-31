import 'package:uuid/uuid.dart';

class ProgramDay {
  const ProgramDay({
    required this.id,
    required this.week,
    required this.weekday,
    this.routineId,
    this.rest = false,
    this.notes = '',
  });
  final String id;
  final int week, weekday; // zero-based week, ISO weekday 1..7
  final String? routineId;
  final bool rest;
  final String notes;
  ProgramDay copyWith({
    String? id,
    int? week,
    int? weekday,
    String? routineId,
    bool? rest,
    String? notes,
  }) => ProgramDay(
    id: id ?? this.id,
    week: week ?? this.week,
    weekday: weekday ?? this.weekday,
    routineId: rest == true ? null : routineId ?? this.routineId,
    rest: rest ?? this.rest,
    notes: notes ?? this.notes,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'week': week,
    'weekday': weekday,
    'routineId': routineId,
    'rest': rest,
    'notes': notes,
  };
  factory ProgramDay.fromJson(Map<String, dynamic> j) => ProgramDay(
    id: j['id'] as String,
    week: j['week'] as int,
    weekday: j['weekday'] as int,
    routineId: j['routineId'] as String?,
    rest: j['rest'] as bool? ?? false,
    notes: j['notes'] as String? ?? '',
  );
}

class ProgramExecutionRef {
  const ProgramExecutionRef({
    required this.programId,
    required this.programName,
    required this.dayId,
    required this.date,
  });
  final String programId, programName, dayId;
  final DateTime date;
  String get occurrenceKey =>
      '$programId|$dayId|${date.year}-${date.month}-${date.day}';
  Map<String, dynamic> toJson() => {
    'programId': programId,
    'programName': programName,
    'dayId': dayId,
    'date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
  };
  factory ProgramExecutionRef.fromJson(Map<String, dynamic> j) =>
      ProgramExecutionRef(
        programId: j['programId'] as String,
        programName: j['programName'] as String,
        dayId: j['dayId'] as String,
        date: DateTime.parse(j['date'] as String),
      );
}

class TrainingProgram {
  const TrainingProgram({
    required this.id,
    required this.name,
    required this.weeks,
    required this.days,
    this.description = '',
    this.goal = '',
    this.level = '',
    this.notes = '',
    this.equipment = const [],
    this.active = false,
    this.startDate,
  });
  final String id, name, description, goal, level, notes;
  final int weeks;
  final List<ProgramDay> days;
  final List<String> equipment;
  final bool active;
  final DateTime? startDate;
  String? get validationError {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      return 'El programa necesita un nombre.';
    }
    if (weeks < 1 || weeks > 52) return 'Usá entre 1 y 52 semanas.';
    if (days.isEmpty || !days.any((d) => !d.rest)) {
      return 'Agregá al menos una rutina al programa.';
    }
    if (active && startDate == null) {
      return 'Elegí la fecha de inicio antes de activar.';
    }
    if (startDate != null && startDate!.weekday != DateTime.monday) {
      return 'La semana inicial debe comenzar un lunes.';
    }
    if (days.map((d) => d.id).toSet().length != days.length) {
      return 'Hay días con identificadores repetidos.';
    }
    for (final day in days) {
      if (day.id.isEmpty ||
          day.week < 0 ||
          day.week >= weeks ||
          day.weekday < 1 ||
          day.weekday > 7 ||
          (day.rest
              ? day.routineId != null
              : day.routineId?.isNotEmpty != true)) {
        return 'Revisá los días y rutinas del programa.';
      }
      if (day.rest &&
          days.any(
            (d) =>
                d.id != day.id &&
                d.week == day.week &&
                d.weekday == day.weekday,
          )) {
        return 'Un descanso planificado no puede compartir el día con otra actividad.';
      }
    }
    return null;
  }

  TrainingProgram copyWith({
    String? id,
    String? name,
    String? description,
    String? goal,
    String? level,
    String? notes,
    int? weeks,
    List<ProgramDay>? days,
    List<String>? equipment,
    bool? active,
    DateTime? startDate,
    bool clearStart = false,
  }) => TrainingProgram(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    goal: goal ?? this.goal,
    level: level ?? this.level,
    notes: notes ?? this.notes,
    weeks: weeks ?? this.weeks,
    days: days ?? this.days,
    equipment: equipment ?? this.equipment,
    active: active ?? this.active,
    startDate: clearStart ? null : startDate ?? this.startDate,
  );
  TrainingProgram duplicateWeek(int week) {
    if (week < 0 || week >= weeks || weeks >= 52) {
      throw ArgumentError('Semana inválida');
    }
    return copyWith(
      weeks: weeks + 1,
      days: [
        ...days,
        ...days
            .where((d) => d.week == week)
            .map((d) => d.copyWith(id: const Uuid().v4(), week: weeks)),
      ],
    );
  }

  TrainingProgram removeWeek(int week) {
    if (weeks <= 1 || week < 0 || week >= weeks) {
      throw ArgumentError('Conservá al menos una semana.');
    }
    return copyWith(
      weeks: weeks - 1,
      days: [
        for (final d in days)
          if (d.week != week) d.week > week ? d.copyWith(week: d.week - 1) : d,
      ],
    );
  }

  TrainingProgram moveDay(String id, int direction) {
    if (direction != 1 && direction != -1) {
      throw ArgumentError('Dirección inválida');
    }
    final day = days.where((d) => d.id == id).firstOrNull;
    if (day == null) return this;
    final ordered = days.where((d) => d.week == day.week).toList(),
        position = days
            .where((d) => d.week == day.week)
            .toList()
            .indexWhere((d) => d.id == id);
    final target = position + direction;
    if (target < 0 || target >= ordered.length) return this;
    final moved = ordered.removeAt(position);
    ordered.insert(target, moved);
    var cursor = 0;
    return copyWith(
      days: [for (final d in days) d.week == day.week ? ordered[cursor++] : d],
    );
  }

  DateTime? dateFor(ProgramDay day) => startDate == null
      ? null
      : DateTime(
          startDate!.year,
          startDate!.month,
          startDate!.day + day.week * 7 + day.weekday - 1,
        );
  ProgramExecutionRef? executionFor(ProgramDay day) =>
      day.rest || dateFor(day) == null
      ? null
      : ProgramExecutionRef(
          programId: id,
          programName: name,
          dayId: day.id,
          date: dateFor(day)!,
        );
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'name': name,
    'description': description,
    'goal': goal,
    'level': level,
    'notes': notes,
    'weeks': weeks,
    'days': days.map((d) => d.toJson()).toList(),
    'equipment': equipment,
    'active': active,
    'startDate': startDate == null
        ? null
        : '${startDate!.year.toString().padLeft(4, '0')}-${startDate!.month.toString().padLeft(2, '0')}-${startDate!.day.toString().padLeft(2, '0')}',
  };
  factory TrainingProgram.fromJson(Map<String, dynamic> j) {
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Versión de programa no soportada');
    }
    final program = TrainingProgram(
      id: j['id'] as String,
      name: j['name'] as String,
      weeks: j['weeks'] as int,
      days: (j['days'] as List)
          .map((d) => ProgramDay.fromJson(Map<String, dynamic>.from(d as Map)))
          .toList(),
      description: j['description'] as String? ?? '',
      goal: j['goal'] as String? ?? '',
      level: j['level'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      equipment: List<String>.from(j['equipment'] as List? ?? []),
      active: j['active'] as bool? ?? false,
      startDate: DateTime.tryParse(j['startDate'] as String? ?? ''),
    );
    if (program.validationError case final error?) {
      throw FormatException(error);
    }
    return program;
  }
}
