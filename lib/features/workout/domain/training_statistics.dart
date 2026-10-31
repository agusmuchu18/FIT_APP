part of 'workout_analytics.dart';

class TrainingDateRange {
  const TrainingDateRange(this.start, this.end);
  final DateTime start, end; // Local calendar, end exclusive.
  factory TrainingDateRange.forPeriod(
    TrainingPeriod period,
    DateTime now, {
    DateTime? oldest,
  }) {
    final n = now.toLocal();
    return TrainingDateRange(
      period.start(now) ??
          (oldest == null
              ? null
              : DateTime(
                  oldest.toLocal().year,
                  oldest.toLocal().month,
                  oldest.toLocal().day,
                )) ??
          DateTime(n.year, n.month, n.day),
      DateTime(n.year, n.month, n.day + 1),
    );
  }
  factory TrainingDateRange.month(int year, int month) =>
      TrainingDateRange(DateTime(year, month), DateTime(year, month + 1));
  bool contains(DateTime time) =>
      !time.toLocal().isBefore(start) && time.toLocal().isBefore(end);
  int get calendarDays => math.max(
    0,
    DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays,
  );
  TrainingDateRange get previous => TrainingDateRange(
    DateTime(start.year, start.month, start.day - calendarDays),
    start,
  );
}

enum ExerciseRanking {
  sessions('Sesiones'),
  sets('Series'),
  volume('Volumen'),
  time('Tiempo registrado');

  const ExerciseRanking(this.label);
  final String label;
}

class ExerciseFrequency {
  ExerciseFrequency(this.id, this.name);
  final String id, name;
  final sessionIds = <String>{};
  int sets = 0, seconds = 0;
  double volume = 0;
  double value(ExerciseRanking ranking) => switch (ranking) {
    ExerciseRanking.sessions => sessionIds.length.toDouble(),
    ExerciseRanking.sets => sets.toDouble(),
    ExerciseRanking.volume => volume,
    ExerciseRanking.time => seconds.toDouble(),
  };
}

class MuscleTrainingSummary {
  MuscleTrainingSummary(this.region);
  final TrainingMuscle region;
  int directSets = 0, secondarySets = 0;
  final sessions = <String>{}, exerciseIds = <String>{};
  final days = <DateTime>{};
  double weeklyFrequency(int calendarDays) =>
      calendarDays > 0 ? sessions.length * 7 / calendarDays : 0;
}

enum TrainingMuscle {
  chest('Pecho'),
  back('Espalda (grupo)'),
  lowerBack('Espalda baja'),
  shoulders('Hombros'),
  trapezius('Trapecio'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  forearms('Antebrazos'),
  core('Zona media (grupo)'),
  obliques('Oblicuos'),
  glutes('Glúteos'),
  quads('Cuádriceps'),
  hamstrings('Isquiosurales'),
  calves('Pantorrillas'),
  adductors('Aductores'),
  hipFlexors('Flexores de cadera'),
  legs('Piernas (grupo)');

  const TrainingMuscle(this.label);
  final String label;
  static TrainingMuscle? fromCatalogue(String value) {
    final text = ExerciseLibraryIndex.normalizeQuery(value);
    if (text.contains('pecho') || text.contains('pectoral')) return chest;
    if (text.contains('espalda baja') || text.contains('lumbar')) {
      return lowerBack;
    }
    if (text.contains('espalda') || text.contains('dorsal')) return back;
    if (text.contains('trapec')) return trapezius;
    if (text.contains('hombro') ||
        text.contains('delto') ||
        text.contains('rotadores')) {
      return shoulders;
    }
    if (text.contains('biceps')) return biceps;
    if (text.contains('triceps')) return triceps;
    if (text.contains('antebra')) return forearms;
    if (text.contains('oblic')) return obliques;
    if (text.contains('core') || text.contains('abdominal')) return core;
    if (text.contains('glute')) return glutes;
    if (text.contains('cuadri')) return quads;
    if (text.contains('isquio') || text.contains('femoral')) return hamstrings;
    if (text.contains('pantorr') || text.contains('gemel')) return calves;
    if (text.contains('aductor')) return adductors;
    if (text.contains('flexores de cadera')) return hipFlexors;
    if (text == 'piernas') return legs;
    return null; // cardio, mobility and stability are not anatomical muscles.
  }
}

/// Period aggregation consumes WorkoutReport instead of reimplementing volume,
/// completion or duration formulas. Muscle participation remains a catalogue
/// attribution, with secondary sets separately counted and never weighted as a
/// physiological stimulus.
class TrainingStatistics {
  TrainingStatistics({
    required TrainingPerformanceIndex index,
    required this.range,
    DateTime? now,
  }) {
    final n = (now ?? DateTime.now()).toLocal();
    final todayEnd = DateTime(n.year, n.month, n.day + 1);
    sessions = List.unmodifiable(
      index.reports.where(
        (r) =>
            range.contains(r.session.date) &&
            r.session.date.toLocal().isBefore(todayEnd),
      ),
    );
    observedDays = TrainingDateRange(
      range.start,
      range.end.isBefore(todayEnd) ? range.end : todayEnd,
    ).calendarDays;
    volume = sessions.fold(0.0, (sum, r) => sum + r.externalVolume);
    sets = sessions.fold(0, (sum, r) => sum + r.performedSets);
    reps = sessions.fold(0, (sum, r) => sum + r.reps);
    knownDurations = sessions.where((r) => r.duration != null).length;
    durationSeconds = sessions.fold(
      0,
      (sum, r) => sum + (r.duration?.inSeconds ?? 0),
    );
    durationKinds = sessions
        .where((r) => r.duration != null)
        .map((r) => r.session.durationIsActive)
        .toSet();
    ambiguousVolumes = sessions.where((r) => r.ambiguousLoad).length;
    unknownCompletion = sessions.any((r) => r.legacyCompletionUnknown);
    final frequency = <String, ExerciseFrequency>{};
    final groups = {
      for (final r in TrainingMuscle.values) r: MuscleTrainingSummary(r),
    };
    final daily = <DateTime, List<WorkoutReport>>{};
    for (final report in sessions) {
      final date = report.session.date.toLocal(),
          day = DateTime(
            report.session.date.toLocal().year,
            report.session.date.toLocal().month,
            report.session.date.toLocal().day,
          );
      daily.putIfAbsent(day, () => []).add(report);
      for (final e in report.exercises) {
        final d = WorkoutAnalytics.definition(e.exercise),
            id = d?.id ?? e.exercise.id;
        final row = frequency.putIfAbsent(
          id,
          () => ExerciseFrequency(id, e.exercise.name),
        );
        if (e.performed.isNotEmpty) row.sessionIds.add(report.session.id);
        row.sets += e.performed.length;
        row.volume += e.externalVolume;
        row.seconds += e.performed.fold<int>(
          0,
          (sum, s) => sum + (s.durationSeconds ?? 0),
        );
        final direct =
            (d?.primaryMuscles ??
                    [
                      if (e.exercise.muscleGroup != null)
                        e.exercise.muscleGroup!,
                    ])
                .map(TrainingMuscle.fromCatalogue)
                .whereType<TrainingMuscle>()
                .toSet();
        final secondary =
            (d?.secondaryMuscles ?? const <String>[])
                .map(TrainingMuscle.fromCatalogue)
                .whereType<TrainingMuscle>()
                .toSet()
              ..removeAll(direct);
        final completed = e.performed.where((s) => s.done == true).length;
        for (final region in {...direct, ...secondary}) {
          final muscle = groups[region]!;
          if (direct.contains(region)) {
            muscle.directSets += completed;
          } else {
            muscle.secondarySets += completed;
          }
          if (completed > 0) {
            muscle.sessions.add(report.session.id);
            muscle.exerciseIds.add(id);
            muscle.days.add(DateTime(date.year, date.month, date.day));
          }
        }
      }
    }
    exerciseFrequency = Map.unmodifiable(frequency);
    muscleSummary = Map.unmodifiable(groups);
    sessionsByDay = Map.unmodifiable(
      daily.map((k, v) => MapEntry(k, List<WorkoutReport>.unmodifiable(v))),
    );
  }
  final TrainingDateRange range;
  late final List<WorkoutReport> sessions;
  late final double volume;
  late final int sets,
      reps,
      durationSeconds,
      knownDurations,
      ambiguousVolumes,
      observedDays;
  late final bool unknownCompletion;
  late final Set<bool?> durationKinds;
  late final Map<String, ExerciseFrequency> exerciseFrequency;
  late final Map<TrainingMuscle, MuscleTrainingSummary> muscleSummary;
  late final Map<DateTime, List<WorkoutReport>> sessionsByDay;
  double get weeklyFrequency =>
      observedDays > 0 ? sessions.length * 7 / observedDays : 0;
  double? get averageDurationSeconds =>
      knownDurations == 0 || durationKinds.length != 1
      ? null
      : durationSeconds / knownDurations;
  List<ExerciseFrequency> rank(ExerciseRanking by) =>
      exerciseFrequency.values.where((r) => r.value(by) > 0).toList()
        ..sort((a, b) {
          final order = b.value(by).compareTo(a.value(by));
          return order == 0 ? a.id.compareTo(b.id) : order;
        });
  static double? percentChange(num current, num previous) =>
      previous > 0 ? (current - previous) / previous * 100 : null;
}
