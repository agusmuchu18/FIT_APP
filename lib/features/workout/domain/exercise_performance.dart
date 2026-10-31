part of 'workout_analytics.dart';

enum TrainingPeriod {
  week('7 días'),
  month('30 días'),
  quarter('3 meses'),
  halfYear('6 meses'),
  year('12 meses'),
  all('Histórico');

  const TrainingPeriod(this.label);
  final String label;
  DateTime? start(DateTime now) {
    final today = DateTime(
      now.toLocal().year,
      now.toLocal().month,
      now.toLocal().day,
    );
    return switch (this) {
      week => DateTime(today.year, today.month, today.day - 6),
      month => DateTime(today.year, today.month, today.day - 29),
      quarter => WorkoutHistoryReport._calendarMonthsBefore(today, 3),
      halfYear => WorkoutHistoryReport._calendarMonthsBefore(today, 6),
      year => WorkoutHistoryReport._calendarMonthsBefore(today, 12),
      all => null,
    };
  }
}

enum ExerciseMetric {
  load('Mayor carga', 'kg'),
  estimatedMax('1RM estimada', 'kg'),
  setVolume('Volumen por serie', 'kg·rep'),
  sessionVolume('Volumen de sesión', 'kg·rep'),
  repetitions('Repeticiones', 'rep'),
  sets('Series completadas', 'series'),
  frequency('Frecuencia', 'sesiones'),
  duration('Tiempo registrado', 's'),
  distance('Distancia', 'm');

  const ExerciseMetric(this.label, this.unit);
  final String label, unit;
}

enum RecordKind {
  load('Mayor carga'),
  setVolume('Volumen por serie'),
  sessionVolume('Volumen de sesión'),
  repetitions('Más repeticiones'),
  estimatedMax('1RM estimada'),
  repLoad('Carga por repeticiones'),
  duration('Mayor tiempo sostenido');

  const RecordKind(this.label);
  final String label;
}

/// A comparison boundary, never a conversion between body mass, added load,
/// assistance, machines, or an unknown dumbbell convention.
String exerciseLoadKey(WorkoutExercise e, SetEntry s) =>
    '${WorkoutAnalytics.setLoadType(e, s)?.name ?? 'unknown'}|${e.equipment ?? WorkoutAnalytics.definition(e)?.equipment ?? 'unknown'}|${s.loadConvention.name}|${s.loadConvention == LoadConvention.perImplement ? s.implementCount ?? '?' : 1}${WorkoutAnalytics.setLoadType(e, s) == RoutineExerciseLoadType.assistedKg ? '|assistance:${s.assistanceKg ?? '?'}' : ''}';

String exerciseLoadLabel(WorkoutExercise e, SetEntry s) {
  final kind = switch (WorkoutAnalytics.setLoadType(e, s)) {
    null => 'Carga antigua sin clasificar',
    RoutineExerciseLoadType.bodyweight => 'Peso corporal',
    RoutineExerciseLoadType.addedWeightKg => 'Lastre',
    RoutineExerciseLoadType.assistedKg =>
      'Asistencia ${s.assistanceKg == null ? "sin registrar" : "${s.assistanceKg} kg"}',
    RoutineExerciseLoadType.machineKg => 'Máquina',
    RoutineExerciseLoadType.weightedKg => 'Carga externa',
  };
  return '$kind · ${switch (s.loadConvention) {
    LoadConvention.recorded => 'registrada',
    LoadConvention.total => 'total',
    LoadConvention.perImplement => 'por implemento (${s.implementCount ?? '?'})',
  }}';
}

class ExerciseObservation {
  ExerciseObservation({
    required this.report,
    required this.exercise,
    required List<SetEntry> sets,
    required this.loadKey,
  }) : sets = List.unmodifiable(sets);
  final WorkoutReport report;
  final WorkoutExercise exercise;
  final List<SetEntry> sets;
  final String loadKey;
  String get exerciseId =>
      WorkoutAnalytics.definition(exercise)?.id ?? exercise.id;
  String get label => exerciseLoadLabel(exercise, sets.first);
  double get volume => sets.fold(
    0.0,
    (sum, s) => sum + WorkoutAnalytics.externalVolume(s, exercise: exercise),
  );
  int get reps => sets.fold(0, (sum, s) => sum + (s.reps ?? 0));
  double? value(ExerciseMetric metric) {
    final loaded = sets.where(
      (s) =>
          WorkoutAnalytics.externalLoadForVolume(s, exercise: exercise) != null,
    );
    final volumetric = loaded;
    double? maximum(Iterable<double?> values) {
      final known = values
          .whereType<double>()
          .where((n) => n.isFinite)
          .toList();
      return known.isEmpty ? null : known.reduce(math.max);
    }

    return switch (metric) {
      ExerciseMetric.load => maximum(loaded.map((s) => s.externalLoadKg)),
      ExerciseMetric.estimatedMax => maximum(
        loaded.map((s) => TrainingPerformanceIndex.estimatedMax(exercise, s)),
      ),
      ExerciseMetric.setVolume => maximum(
        volumetric.map(
          (s) => WorkoutAnalytics.externalVolume(s, exercise: exercise),
        ),
      ),
      ExerciseMetric.sessionVolume =>
        loaded.isEmpty || volumetric.length != loaded.length ? null : volume,
      ExerciseMetric.repetitions =>
        WorkoutAnalytics.isTimed(exercise) || exercise.measurement == 'distance'
            ? null
            : reps.toDouble(),
      ExerciseMetric.sets => sets.length.toDouble(),
      ExerciseMetric.frequency => 1,
      ExerciseMetric.duration =>
        sets.any((s) => s.durationSeconds != null)
            ? sets.fold<double>(0, (sum, s) => sum + (s.durationSeconds ?? 0))
            : null,
      ExerciseMetric.distance =>
        sets.any((s) => s.distanceMeters != null)
            ? sets.fold<double>(0, (sum, s) => sum + (s.distanceMeters ?? 0))
            : null,
    };
  }
}

class ExercisePersonalRecord {
  const ExercisePersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.loadKey,
    required this.loadLabel,
    required this.kind,
    required this.value,
    required this.sessionId,
    required this.date,
    required this.setIds,
    this.reps,
  });
  final String exerciseId, exerciseName, loadKey, loadLabel, sessionId;
  final RecordKind kind;
  final double value;
  final DateTime date;
  final List<String> setIds;
  final int? reps;
  bool get estimated => kind == RecordKind.estimatedMax;
  String get unit => kind == RecordKind.repetitions
      ? 'rep'
      : kind == RecordKind.duration
      ? 's'
      : kind == RecordKind.setVolume || kind == RecordKind.sessionVolume
      ? 'kg·rep'
      : 'kg';
}

/// Immutable, one-pass index derived only from canonical saved sessions.
/// Unknown legacy completion remains visible in general reports, but cannot
/// certify a personal record. No cache or storage is owned by this domain type.
class TrainingPerformanceIndex {
  TrainingPerformanceIndex(Iterable<WorkoutSession> source, {DateTime? asOf}) {
    final now = (asOf ?? DateTime.now()).toLocal();
    final end = DateTime(now.year, now.month, now.day + 1);
    final ordered = source.toList()
      ..sort((a, b) {
        final order = a.date.compareTo(b.date);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
    reports = List.unmodifiable(ordered.map(WorkoutReport.new));
    final byExercise = <String, List<ExerciseObservation>>{};
    final best = <String, ExercisePersonalRecord>{};
    final progression = <ExercisePersonalRecord>[];
    var unknown = 0;
    for (final report in reports) {
      if (!report.session.date.isBefore(end)) continue;
      final sessionGroups = <String, ExerciseObservation>{};
      for (final e in report.session.exercises) {
        unknown += e.sets.where((s) => s.done == null).length;
        final groups = <String, List<SetEntry>>{};
        for (final s in e.sets) {
          if (s.done != true || !WorkoutAnalytics.countsForMetrics(e, s)) {
            continue;
          }
          groups.putIfAbsent(exerciseLoadKey(e, s), () => []).add(s);
        }
        for (final entry in groups.entries) {
          final id = WorkoutAnalytics.definition(e)?.id ?? e.id;
          final key = '$id|${entry.key}';
          sessionGroups[key] = ExerciseObservation(
            report: report,
            exercise: e,
            sets: [...?sessionGroups[key]?.sets, ...entry.value],
            loadKey: entry.key,
          );
        }
      }
      for (final observation in sessionGroups.values) {
        final e = observation.exercise;
        final entry = MapEntry(observation.loadKey, observation.sets);
        byExercise
            .putIfAbsent(observation.exerciseId, () => [])
            .add(observation);
        void record(
          RecordKind kind,
          double? value,
          List<String> ids, {
          int? reps,
        }) {
          if (value == null || !value.isFinite || value <= 0) return;
          final key =
              '${observation.exerciseId}|${entry.key}|${kind.name}|${reps ?? ''}';
          if (best[key] != null && best[key]!.value >= value) return;
          final mark = ExercisePersonalRecord(
            exerciseId: observation.exerciseId,
            exerciseName: e.name,
            loadKey: entry.key,
            loadLabel: observation.label,
            kind: kind,
            value: value,
            sessionId: report.session.id,
            date: report.session.date,
            setIds: List.unmodifiable(ids),
            reps: reps,
          );
          best[key] = mark;
          progression.add(mark);
        }

        for (final s in entry.value) {
          final mode = WorkoutAnalytics.setLoadType(e, s);
          if (mode == null) continue;
          if (!WorkoutAnalytics.isTimed(e) && e.measurement != 'distance') {
            record(RecordKind.repetitions, s.reps?.toDouble(), [s.id]);
          }
          if (e.sportPlan == null &&
              WorkoutAnalytics.definition(e)?.isTimed == true) {
            record(RecordKind.duration, s.durationSeconds?.toDouble(), [s.id]);
          }
          if (mode == RoutineExerciseLoadType.bodyweight ||
              mode == RoutineExerciseLoadType.assistedKg ||
              WorkoutAnalytics.externalLoadForVolume(s, exercise: e) == null) {
            continue;
          }
          record(RecordKind.load, s.externalLoadKg, [s.id]);
          if (s.reps != null) {
            record(RecordKind.repLoad, s.externalLoadKg, [s.id], reps: s.reps);
          }
          record(
            RecordKind.setVolume,
            WorkoutAnalytics.externalVolume(s, exercise: e),
            [s.id],
          );
          record(RecordKind.estimatedMax, estimatedMax(e, s), [s.id]);
        }
        if (observation.value(ExerciseMetric.sessionVolume) != null) {
          record(
            RecordKind.sessionVolume,
            observation.value(ExerciseMetric.sessionVolume),
            observation.sets.map((s) => s.id).toList(),
          );
        }
      }
    }
    history = Map.unmodifiable(
      byExercise.map(
        (k, v) =>
            MapEntry(k, List<ExerciseObservation>.unmodifiable(v.reversed)),
      ),
    );
    records = List.unmodifiable(best.values);
    recordHistory = List.unmodifiable(progression);
    unknownCompletionSets = unknown;
  }
  late final List<WorkoutReport> reports;
  late final Map<String, List<ExerciseObservation>> history;
  late final List<ExercisePersonalRecord> records, recordHistory;
  late final int unknownCompletionSets;

  /// Epley: w * (1 + r/30), with a one-rep result equal to w. Conservative
  /// product scope: 1–10 reps, explicit external resistance, no known reserve,
  /// no assisted/bodyweight/added-load/time/distance prediction. Not a real PR.
  static double? estimatedMax(WorkoutExercise e, SetEntry s) {
    final d = WorkoutAnalytics.definition(e),
        kg = s.externalLoadKg,
        reps = s.reps;
    if (s.done != true ||
        s.loadIsAmbiguous ||
        (s.loadConvention == LoadConvention.perImplement &&
            WorkoutAnalytics.externalLoadForVolume(s, exercise: e) == null) ||
        kg == null ||
        !kg.isFinite ||
        kg <= 0 ||
        reps == null ||
        reps < 1 ||
        reps > 10 ||
        (s.rir != null && s.rir != 0) ||
        s.assistanceKg != null ||
        e.sportPlan != null ||
        WorkoutAnalytics.isTimed(e) ||
        e.measurement == 'distance' ||
        (WorkoutAnalytics.setLoadType(e, s) !=
                RoutineExerciseLoadType.weightedKg &&
            WorkoutAnalytics.setLoadType(e, s) !=
                RoutineExerciseLoadType.machineKg) ||
        d?.defaultMeasurement != 'reps' ||
        d?.loadType != LoadType.external) {
      return null;
    }
    return reps == 1 ? kg : kg * (1 + reps / 30);
  }

  List<ExerciseObservation> exerciseHistory(
    String id, {
    TrainingPeriod period = TrainingPeriod.all,
    DateTime? now,
    String? loadKey,
  }) {
    final n = (now ?? DateTime.now()).toLocal(),
        start = period.start(now ?? DateTime.now());
    final end = DateTime(n.year, n.month, n.day + 1);
    return (history[id] ?? const <ExerciseObservation>[])
        .where(
          (o) =>
              (loadKey == null || o.loadKey == loadKey) &&
              o.report.session.date.isBefore(end) &&
              (start == null || !o.report.session.date.isBefore(start)),
        )
        .toList(growable: false);
  }

  List<ExercisePersonalRecord> sessionRecords(String sessionId) {
    final selected = <String, ExercisePersonalRecord>{};
    for (final mark in recordHistory.where((r) => r.sessionId == sessionId)) {
      selected['${mark.exerciseId}|${mark.loadKey}|${mark.kind.name}|${mark.reps ?? ''}'] =
          mark;
    }
    return selected.values.toList(growable: false);
  }
}
