import 'package:flutter/foundation.dart';

import '../workout/domain/training_units.dart';

enum BodyMetric {
  weight('Peso', 'kg'),
  bodyFat('Grasa corporal', '%'),
  leanMass('Masa magra', 'kg'),
  chest('Pecho', 'cm'),
  waist('Cintura', 'cm'),
  abdomen('Abdomen', 'cm'),
  hips('Cadera', 'cm'),
  neck('Cuello', 'cm'),
  shoulders('Hombros', 'cm'),
  rightBiceps('Bíceps derecho', 'cm'),
  leftBiceps('Bíceps izquierdo', 'cm'),
  rightForearm('Antebrazo derecho', 'cm'),
  leftForearm('Antebrazo izquierdo', 'cm'),
  rightThigh('Muslo derecho', 'cm'),
  leftThigh('Muslo izquierdo', 'cm'),
  rightCalf('Pantorrilla derecha', 'cm'),
  leftCalf('Pantorrilla izquierda', 'cm');

  const BodyMetric(this.label, this.unit);
  final String label, unit;
}

@immutable
class BodyValue {
  const BodyValue(this.value, this.unit);
  final double value;
  final String unit;
  double get canonical => switch (unit) {
    'lb' => WeightUnit.lb.toKg(value),
    'in' => value * 2.54,
    _ => value,
  };
  double inUnit(String target) => switch (target) {
    'lb' => WeightUnit.lb.fromKg(canonical),
    'in' => canonical / 2.54,
    _ => canonical,
  };
  void validate(BodyMetric metric) {
    final allowed = switch (metric.unit) {
      'kg' => {'kg', 'lb'},
      'cm' => {'cm', 'in'},
      _ => {'%'},
    };
    if (!allowed.contains(unit) ||
        !value.isFinite ||
        value < 0 ||
        (value == 0 && metric != BodyMetric.bodyFat) ||
        value > (metric == BodyMetric.bodyFat ? 100 : 1000000)) {
      throw const FormatException('Valor o unidad de medida inválidos.');
    }
  }

  Map<String, dynamic> toJson() => {'value': value, 'unit': unit};
}

/// Private, explicitly entered observations; no derived composition or health
/// inference. Original values/units remain authoritative after unit changes.
@immutable
class BodyMeasurement {
  BodyMeasurement({
    required this.id,
    required this.date,
    required Map<BodyMetric, BodyValue> values,
    required this.createdAt,
    this.revision = 1,
    this.notes = '',
  }) : values = Map.unmodifiable(values) {
    if (id.isEmpty ||
        id.length > 128 ||
        date.year < 1900 ||
        date.year > 2200 ||
        date.hour != 0 ||
        date.minute != 0 ||
        date.second != 0 ||
        date.millisecond != 0 ||
        date.microsecond != 0 ||
        values.isEmpty ||
        notes.length > 500 ||
        revision < 1) {
      throw const FormatException('Registro de medidas inválido.');
    }
    for (final item in values.entries) {
      item.value.validate(item.key);
    }
  }
  final String id, notes;
  final int revision;
  final DateTime date, createdAt;
  final Map<BodyMetric, BodyValue> values;
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'date': dateKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'source': 'manual',
    'revision': revision,
    'notes': notes,
    'values': {for (final e in values.entries) e.key.name: e.value.toJson()},
  };
  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 || json['source'] != 'manual') {
      throw const FormatException('Formato de medidas no compatible.');
    }
    final rawDate = json['date'] as String;
    final date = DateTime.parse(rawDate);
    final result = BodyMeasurement(
      id: json['id'] as String,
      date: date,
      createdAt: DateTime.parse(json['createdAt'] as String),
      revision: json['revision'] as int,
      notes: json['notes'] as String,
      values: {
        for (final e in (json['values'] as Map).entries)
          BodyMetric.values.byName(e.key as String): BodyValue(
            ((e.value as Map)['value'] as num).toDouble(),
            (e.value as Map)['unit'] as String,
          ),
      },
    );
    if (rawDate != result.dateKey) {
      throw const FormatException('Fecha de medida inválida.');
    }
    return result;
  }
}
