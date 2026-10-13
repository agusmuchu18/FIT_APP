enum SportDiscipline { football }

enum FootballMode { technical, tactical, physical, gym, competition, recovery }

enum FootballGymPurpose { strength, power, stability, conditioning }

extension FootballGymPurposeLabel on FootballGymPurpose {
  String get label => switch (this) {
    FootballGymPurpose.strength => 'Fuerza',
    FootballGymPurpose.power => 'Potencia',
    FootballGymPurpose.stability => 'Estabilidad',
    FootballGymPurpose.conditioning => 'Acondicionamiento',
  };
}

enum SportMetric {
  durationSeconds,
  distanceMeters,
  repetitions,
  playedMinutes,
  goals,
  assists,
  effort,
}

extension FootballModeLabel on FootballMode {
  String get label => switch (this) {
    FootballMode.technical => 'Técnica',
    FootballMode.tactical => 'Táctica',
    FootballMode.physical => 'Preparación física',
    FootballMode.gym => 'Gimnasio para fútbol',
    FootballMode.competition => 'Partido / competición',
    FootballMode.recovery => 'Recuperación',
  };
}

extension SportMetricLabel on SportMetric {
  String get label => switch (this) {
    SportMetric.durationSeconds => 'Duración del bloque (s)',
    SportMetric.distanceMeters => 'Distancia (m)',
    SportMetric.repetitions => 'Repeticiones',
    SportMetric.playedMinutes => 'Minutos jugados',
    SportMetric.goals => 'Goles',
    SportMetric.assists => 'Asistencias',
    SportMetric.effort => 'Esfuerzo percibido (1–10)',
  };
  bool get integer => this != SportMetric.distanceMeters;
  bool valid(double value) =>
      value.isFinite &&
      value >= 0 &&
      (!integer || value == value.roundToDouble()) &&
      (this != SportMetric.effort || (value >= 1 && value <= 10));
}

/// Values have restricted typed keys/units. Plans and results own different instances.
class SportMeasurements {
  SportMeasurements({
    Map<SportMetric, double> values = const {},
    this.position = '',
    this.notes = '',
  }) : values = Map.unmodifiable(values);
  final Map<SportMetric, double> values;
  final String position;
  final String notes;
  bool get valid => values.entries.every((e) => e.key.valid(e.value));
  Map<String, dynamic> toJson() => {
    'values': {for (final e in values.entries) e.key.name: e.value},
    'position': position,
    'notes': notes,
  };
  factory SportMeasurements.fromJson(Map<String, dynamic> json) =>
      SportMeasurements(
        values: {
          for (final e
              in (json['values'] as Map<String, dynamic>? ?? {}).entries)
            SportMetric.values.byName(e.key): (e.value as num).toDouble(),
        },
        position: json['position'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

class SportActivityPlan {
  SportActivityPlan({
    required this.activityId,
    required this.mode,
    SportMeasurements? targets,
    this.objective = '',
  }) : targets = targets ?? SportMeasurements();
  final String activityId;
  final FootballMode mode;
  final SportMeasurements targets;
  final String objective;
  Map<String, dynamic> toJson() => {
    'discipline': 'football',
    'activityId': activityId,
    'mode': mode.name,
    'targets': targets.toJson(),
    'objective': objective,
  };
  factory SportActivityPlan.fromJson(Map<String, dynamic> json) {
    if (json['discipline'] != 'football') {
      throw FormatException('Disciplina no soportada');
    }
    return SportActivityPlan(
      activityId: json['activityId'] as String,
      mode: FootballMode.values.byName(json['mode'] as String),
      targets: SportMeasurements.fromJson(
        json['targets'] as Map<String, dynamic>,
      ),
      objective: json['objective'] as String? ?? '',
    );
  }
  bool resultValid(SportMeasurements? result) {
    if (result == null || !result.valid) return false;
    final definition = footballActivities
        .where((e) => e.id == activityId)
        .firstOrNull;
    if (definition == null) return false;
    if (!result.values.keys.every(definition.metrics.contains)) return false;
    if ((result.values[SportMetric.durationSeconds] ?? 0) <= 0) return false;
    if (mode == FootballMode.physical &&
        ((result.values[SportMetric.distanceMeters] ?? 0) <= 0 ||
            (result.values[SportMetric.repetitions] ?? 0) <= 0)) {
      return false;
    }
    final played = result.values[SportMetric.playedMinutes];
    return played == null ||
        played * 60 <= result.values[SportMetric.durationSeconds]!;
  }
}

class FootballActivity {
  const FootballActivity(this.id, this.name, this.mode, this.description);
  final String id, name, description;
  final FootballMode mode;
  List<SportMetric> get metrics => [
    SportMetric.durationSeconds,
    if (mode == FootballMode.physical) ...[
      SportMetric.distanceMeters,
      SportMetric.repetitions,
    ],
    if (mode == FootballMode.competition) ...[
      SportMetric.playedMinutes,
      SportMetric.goals,
      SportMetric.assists,
    ],
    SportMetric.effort,
  ];
}

const footballActivities = [
  FootballActivity(
    'football_pass',
    'Pase',
    FootballMode.technical,
    'Definí la distancia, superficie de contacto y objetivo de tu práctica.',
  ),
  FootballActivity(
    'football_control',
    'Control',
    FootballMode.technical,
    'Describí la recepción y orientación que querés practicar.',
  ),
  FootballActivity(
    'football_dribble',
    'Conducción y regate',
    FootballMode.technical,
    'Configurá un recorrido y anotá las condiciones del ejercicio.',
  ),
  FootballActivity(
    'football_shoot',
    'Remate',
    FootballMode.technical,
    'Anotá la posición y el objetivo del remate.',
  ),
  FootballActivity(
    'football_position',
    'Posicionamiento',
    FootballMode.tactical,
    'Definí el objetivo, roles y espacio del ejercicio colectivo.',
  ),
  FootballActivity(
    'football_press',
    'Presión',
    FootballMode.tactical,
    'Describí las consignas y el objetivo del bloque.',
  ),
  FootballActivity(
    'football_transition',
    'Transiciones y sistema táctico',
    FootballMode.tactical,
    'Anotá las fases y roles que se van a trabajar.',
  ),
  FootballActivity(
    'football_sprint',
    'Sprint de 20 metros',
    FootballMode.physical,
    'Distancia, repeticiones y tiempo se registran por separado.',
  ),
  FootballActivity(
    'football_acceleration',
    'Aceleraciones',
    FootballMode.physical,
    'Definí distancia y repeticiones; registrá el tiempo realizado.',
  ),
  FootballActivity(
    'football_agility',
    'Cambios de dirección y agilidad',
    FootballMode.physical,
    'Describí el recorrido; configurá distancia, repeticiones y recuperación.',
  ),
  FootballActivity(
    'football_endurance',
    'Resistencia',
    FootballMode.physical,
    'Definí el bloque de distancia y repeticiones. No se estima rendimiento automáticamente.',
  ),
  FootballActivity(
    'football_match',
    'Partido',
    FootballMode.competition,
    'Registrá duración, participación, posición, estadísticas y esfuerzo percibido.',
  ),
  FootballActivity(
    'football_jump',
    'Saltos horizontales y potencia',
    FootballMode.physical,
    'Definí distancia del salto, repeticiones y duración del bloque. No se calcula potencia ni rendimiento automáticamente.',
  ),
  FootballActivity(
    'football_mobility',
    'Movilidad y recuperación',
    FootballMode.recovery,
    'Anotá duración, esfuerzo y sensaciones del trabajo regenerativo.',
  ),
];
