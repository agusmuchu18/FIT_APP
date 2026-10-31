import 'package:intl/intl.dart';

import 'workout_analytics.dart';
import 'routine_labels.dart';
import 'training_units.dart';

class TrainingExportSection {
  const TrainingExportSection(
    this.id,
    this.title,
    this.lines, {
    this.private = false,
  });
  final String id, title;
  final List<String> lines;
  final bool private;
}

class TrainingExportPoint {
  const TrainingExportPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

/// A snapshot of explicitly selected, already-derived information. No account
/// identifier, permanent exercise note or raw storage payload is exported.
class TrainingExportData {
  const TrainingExportData({
    required this.kind,
    required this.sections,
    this.points = const [],
    this.metricLabel,
  });
  final String kind;
  final List<TrainingExportSection> sections;
  final List<TrainingExportPoint> points;
  final String? metricLabel;
  Set<String> get defaults => sections
      .where((s) => !s.private && s.lines.isNotEmpty)
      .map((s) => s.id)
      .toSet();
  static String number(num n) => NumberFormat('0.##', 'es').format(n);
  factory TrainingExportData.session(
    WorkoutReport report,
    List<ExercisePersonalRecord> records, {
    TrainingUnits units = const TrainingUnits(),
  }) => TrainingExportData(
    kind: 'ENTRENAMIENTO',
    sections: [
      TrainingExportSection('name', 'Sesión', [report.name]),
      TrainingExportSection('date', 'Fecha', [
        DateFormat.yMMMMd('es').format(report.session.date.toLocal()),
      ]),
      TrainingExportSection('metrics', 'Tu sesión', [
        '${report.performedSets} series registradas',
        '${units.valueWithUnit('kg·rep', report.externalVolume)} de volumen externo${report.ambiguousLoad ? ' conocido (parcial)' : ''}',
        report.duration == null
            ? 'Duración no registrada'
            : '${report.durationLabel}: ${number(report.duration!.inSeconds / 60)} min',
        if (report.legacyCompletionUnknown)
          'Incluye series históricas sin confirmación de finalización.',
      ]),
      TrainingExportSection('exercises', 'Ejercicios', [
        for (final e in report.exercises)
          '${RoutineLabels.exerciseName(e.exercise.name)} · ${e.performed.length} series',
      ]),
      if (records.isNotEmpty)
        TrainingExportSection('records', 'Marcas logradas en esta sesión', [
          for (final r in records)
            '${RoutineLabels.exerciseName(r.exerciseName)} · ${r.kind.label}: ${units.valueWithUnit(r.unit, r.value)}${r.reps == null ? '' : ' × ${r.reps} rep'} · ${r.loadLabel}',
        ]),
      TrainingExportSection('muscles', 'Distribución por series principales', [
        for (final m in report.muscleDistribution.entries)
          if (m.value > 0) '${m.key}: ${number(m.value * 100)} %',
        'Atribución del catálogo; no mide activación ni estímulo.',
      ]),
      TrainingExportSection('notes', 'Notas privadas de esta sesión', [
        if (report.session.notes?.isNotEmpty == true) report.session.notes!,
        if (report.session.finalNotes?.isNotEmpty == true)
          report.session.finalNotes!,
        for (final e in report.exercises) ...[
          if (e.exercise.notes?.isNotEmpty == true)
            '${e.exercise.name}: ${e.exercise.notes}',
          for (final s in e.performed)
            if (s.note?.isNotEmpty == true)
              '${e.exercise.name} · serie: ${s.note}',
        ],
      ], private: true),
    ],
  );
  factory TrainingExportData.month(
    TrainingStatistics stats, {
    TrainingUnits units = const TrainingUnits(),
  }) => TrainingExportData(
    kind: 'INFORME MENSUAL',
    sections: [
      TrainingExportSection('date', 'Mes', [
        DateFormat.yMMMM('es').format(stats.range.start),
      ]),
      TrainingExportSection('metrics', 'Tu actividad', [
        '${stats.sessions.length} sesiones · ${stats.sets} series registradas',
        '${units.valueWithUnit('kg·rep', stats.volume)} de volumen externo${stats.ambiguousVolumes > 0 ? ' conocido (parcial)' : ''}',
        '${number(stats.durationSeconds / 60)} min registrados en ${stats.knownDurations} sesiones',
        '${stats.observedDays} días transcurridos del período',
        '${number(stats.weeklyFrequency)} sesiones por semana',
        if (stats.unknownCompletion)
          'Incluye series históricas sin confirmación de finalización.',
      ]),
      TrainingExportSection('exercises', 'Ejercicios más frecuentes', [
        for (final e in stats.rank(ExerciseRanking.sessions).take(8))
          '${RoutineLabels.exerciseName(e.name)} · ${e.sessionIds.length} sesiones',
      ]),
    ],
  );
  factory TrainingExportData.record(
    ExercisePersonalRecord record, {
    TrainingUnits units = const TrainingUnits(),
  }) => TrainingExportData(
    kind: record.estimated ? 'MARCA ESTIMADA' : 'RÉCORD PERSONAL',
    sections: [
      TrainingExportSection('name', 'Ejercicio', [
        RoutineLabels.exerciseName(record.exerciseName),
      ]),
      TrainingExportSection('date', 'Fecha de la marca', [
        DateFormat.yMMMMd('es').format(record.date.toLocal()),
      ]),
      TrainingExportSection('metrics', record.kind.label, [
        '${units.valueWithUnit(record.unit, record.value)}${record.reps == null ? '' : ' · ${record.reps} rep'}',
        record.loadLabel,
        if (record.estimated)
          '1RM estimada mediante Epley. No equivale a un máximo medido.',
      ]),
    ],
  );
}
