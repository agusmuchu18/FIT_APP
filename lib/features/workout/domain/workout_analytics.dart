import 'dart:math' as math;

import '../pro/data/exercise_library.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import 'session_models.dart';
import 'exercise_load_policy.dart';

part 'exercise_performance.dart';
part 'training_statistics.dart';

enum WorkoutHistoryPeriod { week, month, quarter, all }

enum WorkoutArtCategory {
  push,
  pull,
  legs,
  fullBody,
  arms,
  cardio,
  mobility,
  mixed,
}

class ExerciseReport {
  ExerciseReport(this.exercise) {
    performed = exercise.sets
        .where((set) => WorkoutAnalytics.countsForMetrics(exercise, set))
        .toList(growable: false);
    warmups = exercise.sets.where((s) => s.kind == SetKind.warmup).length;
    reps = performed.fold(0, (sum, set) => sum + (set.reps ?? 0));
    externalVolume = performed.fold(
      0,
      (sum, set) =>
          sum + WorkoutAnalytics.externalVolume(set, exercise: exercise),
    );
  }
  final WorkoutExercise exercise;

  /// Recorded working sets: warm-ups are excluded from every metric.
  late final List<SetEntry> performed;
  late final int warmups;
  late final int reps;
  late final double externalVolume;
}

class WorkoutReport {
  WorkoutReport(this.session) {
    exercises = session.exercises
        .map(ExerciseReport.new)
        .toList(growable: false);
    performedSets = exercises.fold(
      0,
      (sum, report) => sum + report.performed.length,
    );
    programmedSets = session.exercises.fold(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    externalVolume = exercises.fold(
      0,
      (sum, report) => sum + report.externalVolume,
    );
    reps = exercises.fold(0, (sum, report) => sum + report.reps);
    muscleDistribution = WorkoutAnalytics.muscleDistribution(session.exercises);
  }
  final WorkoutSession session;
  late final List<ExerciseReport> exercises;
  late final int performedSets, programmedSets, reps;
  late final double externalVolume;
  late final Map<String, double> muscleDistribution;
  int get recordedExercises =>
      exercises.where((report) => report.performed.isNotEmpty).length;
  bool get legacyCompletionUnknown =>
      session.exercises.any((e) => e.sets.any((s) => s.done == null));
  bool get ambiguousLoad => session.exercises.any(
    (e) => e.sets.any((s) => WorkoutAnalytics.loadIsUnknown(e, s)),
  );
  Duration? get duration {
    final seconds =
        session.durationSeconds ??
        (session.durationMinutes == null && session.closingDuration == null
            ? null
            : (session.durationMinutes ?? session.closingDuration)! * 60);
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  String get durationLabel => session.durationIsActive == true
      ? 'Tiempo sin pausas'
      : 'Duración registrada';
  String get setsLabel =>
      legacyCompletionUnknown ? 'Series registradas' : 'Series completadas';
  String get name =>
      session.templateName ??
      session.activityName ??
      session.customTypeName ??
      'Entrenamiento libre';
  List<String> get mainMuscles {
    final entries =
        muscleDistribution.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((entry) => entry.key).toList(growable: false);
  }

  WorkoutArtCategory get artCategory {
    if (session.type == WorkoutType.cardio) return WorkoutArtCategory.cardio;
    final known = muscleDistribution.entries.where((e) => e.value > 0).toList();
    if (known.isEmpty) return WorkoutArtCategory.mixed;
    if (known.length >= 4) return WorkoutArtCategory.fullBody;
    known.sort((a, b) => b.value.compareTo(a.value));
    if (known.first.value < .5) return WorkoutArtCategory.mixed;
    return switch (known.first.key) {
      'Pecho' => WorkoutArtCategory.push,
      'Espalda' => WorkoutArtCategory.pull,
      'Piernas' => WorkoutArtCategory.legs,
      'Brazos' || 'Hombros' => WorkoutArtCategory.arms,
      _ => WorkoutArtCategory.mixed,
    };
  }
}

class WorkoutComparison {
  const WorkoutComparison({required this.previous, required this.current});
  final WorkoutReport previous, current;
  double? get volumePercent =>
      previous.externalVolume > 0 &&
          !previous.ambiguousLoad &&
          !current.ambiguousLoad
      ? (current.externalVolume - previous.externalVolume) /
            previous.externalVolume *
            100
      : null;
  double get volumeDelta => current.externalVolume - previous.externalVolume;
  int get repsDelta => current.reps - previous.reps;
  int get setsDelta => current.performedSets - previous.performedSets;
  Duration? get durationDelta =>
      current.duration != null &&
          previous.duration != null &&
          current.session.durationIsActive == previous.session.durationIsActive
      ? current.duration! - previous.duration!
      : null;
}

class WeeklyWorkoutActivity {
  const WeeklyWorkoutActivity(this.monday, this.sessions);
  final DateTime monday;
  final int sessions;
}

class WorkoutHistoryReport {
  WorkoutHistoryReport({
    required List<WorkoutReport> source,
    required this.period,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final end = DateTime(today.year, today.month, today.day + 1);
    final cutoff = switch (period) {
      WorkoutHistoryPeriod.week => DateTime(
        today.year,
        today.month,
        today.day - 6,
      ),
      WorkoutHistoryPeriod.month => DateTime(
        today.year,
        today.month,
        today.day - 29,
      ),
      WorkoutHistoryPeriod.quarter => _calendarMonthsBefore(today, 3),
      WorkoutHistoryPeriod.all => null,
    };
    sessions =
        source
            .where((report) {
              final date = report.session.date.toLocal();
              return date.isBefore(end) &&
                  (cutoff == null || !date.isBefore(cutoff));
            })
            .toList(growable: false)
          ..sort((a, b) => b.session.date.compareTo(a.session.date));
    externalVolume = sessions.fold(
      0,
      (sum, report) => sum + report.externalVolume,
    );
    duration = Duration(
      seconds: sessions.fold(
        0,
        (sum, report) => sum + (report.duration?.inSeconds ?? 0),
      ),
    );
    missingDurations = sessions.where((s) => s.duration == null).length;
    mixedDurationKinds =
        sessions.map((s) => s.session.durationIsActive).toSet().length > 1;
    final oldest = sessions.isEmpty
        ? today
        : sessions.last.session.date.toLocal();
    final start = cutoff ?? DateTime(oldest.year, oldest.month, oldest.day);
    // Calendar days (UTC midnight avoids daylight-saving 23/25-hour distortions).
    periodDays = math.max(
      1,
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays,
    );
    weeklyFrequency = sessions.length * 7 / periodDays;
    final counts = <DateTime, int>{};
    for (final report in sessions) {
      final monday = _monday(report.session.date.toLocal());
      counts[monday] = (counts[monday] ?? 0) + 1;
    }
    final weeks = <WeeklyWorkoutActivity>[];
    var monday = _monday(start);
    while (monday.isBefore(end)) {
      weeks.add(WeeklyWorkoutActivity(monday, counts[monday] ?? 0));
      monday = DateTime(monday.year, monday.month, monday.day + 7);
    }
    activity = List.unmodifiable(weeks);
  }
  final WorkoutHistoryPeriod period;
  late final List<WorkoutReport> sessions;
  late final double externalVolume, weeklyFrequency;
  late final Duration duration;
  late final int periodDays, missingDurations;
  late final bool mixedDurationKinds;
  late final List<WeeklyWorkoutActivity> activity;
  static DateTime _monday(DateTime date) =>
      DateTime(date.year, date.month, date.day - date.weekday + 1);
  static DateTime _calendarMonthsBefore(DateTime date, int months) {
    final monthStart = DateTime(date.year, date.month - months);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    return DateTime(
      monthStart.year,
      monthStart.month,
      math.min(date.day, lastDay),
    );
  }
}

class WorkoutAnalytics {
  const WorkoutAnalytics._();
  static const muscles = [
    'Espalda',
    'Pecho',
    'Piernas',
    'Brazos',
    'Hombros',
    'Core',
  ];
  static final _definitions = {
    for (final exercise in exerciseLibrary) exercise.id: exercise,
  };
  static final _index = ExerciseLibraryIndex(exerciseLibrary);
  static ExerciseDefinition? definition(WorkoutExercise exercise) =>
      _definitions[exercise.id] ?? _index.findByQuery(exercise.name);
  static bool isTimed(WorkoutExercise exercise) =>
      exercise.isTimed ||
      (definition(exercise)?.isTimed ?? false) ||
      exercise.sets.any((s) => (s.durationSeconds ?? 0) > 0 && s.reps == null);
  static bool isRecordedSet(WorkoutExercise exercise, SetEntry set) =>
      set.done != false &&
      (set.externalLoadKg == null ||
          (set.externalLoadKg!.isFinite && set.externalLoadKg! >= 0)) &&
      (set.assistanceKg == null ||
          (set.assistanceKg!.isFinite && set.assistanceKg! >= 0)) &&
      (exercise.measurement == 'distance'
          ? (set.distanceMeters != null &&
                set.distanceMeters!.isFinite &&
                set.distanceMeters! > 0)
          : isTimed(exercise)
          ? (set.durationSeconds ?? 0) > 0
          : (set.reps ?? 0) > 0);

  /// A recorded set that is not a warm-up: the only sets used for volume,
  /// records, comparisons and muscle counts.
  static bool countsForMetrics(WorkoutExercise exercise, SetEntry set) =>
      set.kind != SetKind.warmup && isRecordedSet(exercise, set);

  static double totalExternalVolume(List<WorkoutExercise> exercises) =>
      exercises.fold(
        0.0,
        (sum, exercise) =>
            sum +
            exercise.sets
                .where((s) => countsForMetrics(exercise, s))
                .fold(
                  0.0,
                  (partial, set) =>
                      partial + externalVolume(set, exercise: exercise),
                ),
      );
  static bool isBodyweight(WorkoutExercise exercise) =>
      ExerciseLoadPolicy.isBodyweight(
        definition(exercise),
        equipment: exercise.equipment,
      );

  /// A legacy bodyweight kg value has no proven meaning unless a load mode was
  /// explicitly recorded. Catalogue capability never proves that it was lastre.
  static RoutineExerciseLoadType? setLoadType(
    WorkoutExercise exercise,
    SetEntry set,
  ) {
    if (set.loadIsAmbiguous) return null;
    if (set.loadType != null) return set.loadType;
    if (exercise.targetLoadType == RoutineExerciseLoadType.assistedKg ||
        exercise.targetLoadType == RoutineExerciseLoadType.addedWeightKg) {
      return exercise.targetLoadType;
    }
    if (isBodyweight(exercise)) {
      if (set.assistanceKg != null) return RoutineExerciseLoadType.assistedKg;
      return (set.externalLoadKg ?? 0) > 0
          ? null
          : RoutineExerciseLoadType.bodyweight;
    }
    if (exercise.targetLoadType == RoutineExerciseLoadType.bodyweight &&
        set.externalLoadKg != null) {
      return RoutineExerciseLoadType.weightedKg;
    }
    return exercise.targetLoadType;
  }

  static bool loadIsUnknown(WorkoutExercise e, SetEntry s) {
    final mode = setLoadType(e, s);
    return s.loadIsAmbiguous ||
        mode == null ||
        (s.externalLoadKg != null &&
            mode != RoutineExerciseLoadType.bodyweight &&
            mode != RoutineExerciseLoadType.assistedKg &&
            externalLoadForVolume(s, exercise: e) == null);
  }

  static double externalVolume(SetEntry set, {WorkoutExercise? exercise}) {
    final kg = externalLoadForVolume(set, exercise: exercise);
    final reps = set.reps;
    if (set.loadIsAmbiguous ||
        kg == null ||
        !kg.isFinite ||
        kg < 0 ||
        reps == null ||
        reps < 1) {
      return 0;
    }
    return kg * reps;
  }

  /// Historical recorded loads retain their original convention. Multiplication
  /// is allowed only with an explicit per-implement convention and count.
  static double? externalLoadForVolume(
    SetEntry set, {
    WorkoutExercise? exercise,
  }) {
    final mode = exercise == null ? set.loadType : setLoadType(exercise, set);
    if (mode == RoutineExerciseLoadType.bodyweight ||
        mode == RoutineExerciseLoadType.assistedKg ||
        (exercise != null && mode == null) ||
        (set.loadType == null && set.assistanceKg != null)) {
      return null;
    }
    final kg = set.externalLoadKg;
    if (set.loadIsAmbiguous || kg == null || !kg.isFinite || kg < 0) {
      return null;
    }
    if (set.loadConvention != LoadConvention.perImplement) return kg;
    final count = set.implementCount;
    return count != null && count > 0 && count <= 2 ? kg * count : null;
  }

  static List<WorkoutExercise> fromLive(List<ExerciseInSession> exercises) =>
      exercises
          .map(
            (e) => WorkoutExercise(
              id: e.exerciseId,
              name: e.name,
              notes: e.notes,
              targetSets: e.sets.length,
              loadSchemaVersion: 1,
              instanceId: e.plan?.instanceId ?? e.id,
              setTargets: e.plan?.setTargets ?? const [],
              sportPlan: e.sportPlan,
              sportPurpose: e.plan?.sportPurpose,
              sportResult: e.sportResult,
              supersetId: e.supersetId,
              restEnabled: e.restEnabled,
              measurement: e.isDistance
                  ? 'distance'
                  : e.isTimed
                  ? 'seconds'
                  : 'reps',
              targetLoadType: e.defaultMode,
              restSeconds: e.restSeconds,
              sets: e.sets
                  .map(
                    (s) => SetEntry(
                      loadType: s.loadType,
                      loadIsAmbiguous: s.loadIsAmbiguous,
                      id: s.id,
                      done: s.done,
                      reps: s.reps,
                      durationSeconds: s.durationSeconds,
                      externalLoadKg: s.kg,
                      bodyweightKg: s.bodyweightKg,
                      bodyweightFactor: s.bodyweightFactor,
                      assistanceKg: s.assistanceKg,
                      distanceMeters: s.distanceMeters,
                      loadConvention: s.loadConvention,
                      implementCount: s.implementCount,
                      rir: s.rir,
                      note: s.note,
                      performedAt: s.performedAt,
                      kind: s.kind,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(growable: false);

  /// Each valid recorded set contributes one unit shared among known primary
  /// muscle groups. This is catalogue attribution, not physiological activation.
  static Map<String, double> muscleDistribution(
    List<WorkoutExercise> exercises,
  ) {
    final buckets = {for (final muscle in muscles) muscle: 0.0};
    for (final exercise in exercises) {
      final groups =
          (definition(exercise)?.primaryMuscles ??
                  [if (exercise.muscleGroup != null) exercise.muscleGroup!])
              .map(_group)
              .whereType<String>()
              .toSet();
      if (groups.isEmpty) continue;
      final count = exercise.sets
          .where((set) => countsForMetrics(exercise, set))
          .length;
      for (final group in groups) {
        buckets[group] = buckets[group]! + count / groups.length;
      }
    }
    final total = buckets.values.fold(0.0, (sum, value) => sum + value);
    return total == 0
        ? buckets
        : buckets.map((key, value) => MapEntry(key, value / total));
  }

  static String? _group(String muscle) {
    final text = muscle.toLowerCase();
    if (text.contains('espalda') ||
        text.contains('dorsal') ||
        text.contains('trapec')) {
      return 'Espalda';
    }
    if (text.contains('pecho') || text.contains('pectoral')) return 'Pecho';
    if (text.contains('pierna') ||
        text.contains('cuád') ||
        text.contains('glú') ||
        text.contains('femor') ||
        text.contains('pantorr') ||
        text.contains('gemel') ||
        text.contains('isquio') ||
        text.contains('aductor')) {
      return 'Piernas';
    }
    if (text.contains('bíceps') ||
        text.contains('tríceps') ||
        text.contains('antebra')) {
      return 'Brazos';
    }
    if (text.contains('hombro') || text.contains('delto')) return 'Hombros';
    if (text.contains('core') ||
        text.contains('abdominal') ||
        text.contains('oblic') ||
        text.contains('lumbar')) {
      return 'Core';
    }
    return null;
  }

  static WorkoutComparison? compare(
    WorkoutReport current,
    List<WorkoutReport> history,
  ) {
    if (current.ambiguousLoad) return null;
    if (current.performedSets == 0) {
      if (current.session.type == WorkoutType.strength ||
          current.duration == null ||
          current.session.activityName?.trim().isNotEmpty != true) {
        return null;
      }
      final candidates =
          history
              .where(
                (previous) =>
                    previous.session.id != current.session.id &&
                    previous.session.date.isBefore(current.session.date) &&
                    previous.session.type == current.session.type &&
                    previous.session.activityName ==
                        current.session.activityName &&
                    previous.duration != null &&
                    previous.session.durationIsActive ==
                        current.session.durationIsActive,
              )
              .toList()
            ..sort((a, b) => b.session.date.compareTo(a.session.date));
      return candidates.isEmpty
          ? null
          : WorkoutComparison(previous: candidates.first, current: current);
    }
    final structure = _structure(current);
    final candidates = history
        .where(
          (previous) =>
              previous.session.id != current.session.id &&
              previous.session.date.isBefore(current.session.date) &&
              previous.session.type == current.session.type &&
              previous.performedSets > 0 &&
              previous.legacyCompletionUnknown ==
                  current.legacyCompletionUnknown &&
              !previous.ambiguousLoad &&
              _structure(previous) == structure,
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.session.date.compareTo(a.session.date));
    final sameRoutine = candidates
        .where(
          (candidate) =>
              current.session.templateId != null &&
              candidate.session.templateId == current.session.templateId,
        )
        .toList();
    return WorkoutComparison(
      previous: sameRoutine.isEmpty ? candidates.first : sameRoutine.first,
      current: current,
    );
  }

  static String _structure(WorkoutReport report) {
    final entries = report.exercises.where((e) => e.performed.isNotEmpty).map((
      e,
    ) {
      final kinds =
          e.performed
              .map((s) => setLoadType(e.exercise, s)?.name ?? 'unknown')
              .toSet()
              .toList()
            ..sort();
      final key =
          definition(e.exercise)?.id ??
          ExerciseLibraryIndex.normalizeQuery(e.exercise.name);
      final conventions =
          e.performed
              .map((s) => exerciseLoadKey(e.exercise, s))
              .toSet()
              .toList()
            ..sort();
      return '$key|${isTimed(e.exercise)}|${kinds.join(',')}|${conventions.join(',')}';
    }).toList()..sort();
    return entries.join(';');
  }

  static (String, SetEntry)? highlightedSet(WorkoutReport report) {
    (String, SetEntry)? best;
    var volume = 0.0;
    for (final exercise in report.exercises) {
      for (final set in exercise.performed) {
        final current = externalVolume(set, exercise: exercise.exercise);
        if (current > volume) {
          volume = current;
          best = (exercise.exercise.name, set);
        }
      }
    }
    return best;
  }
}
