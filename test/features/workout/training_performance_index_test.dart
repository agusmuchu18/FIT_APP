import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExercise exercise(
  List<SetEntry> sets, {
  String id = 'bench_press',
  RoutineExerciseLoadType load = RoutineExerciseLoadType.weightedKg,
}) => WorkoutExercise(id: id, name: id, targetLoadType: load, sets: sets);
SetEntry result(
  String id, {
  double kg = 60,
  int reps = 8,
  bool? done = true,
  LoadConvention convention = LoadConvention.recorded,
  int? count,
}) => SetEntry(
  id: id,
  externalLoadKg: kg,
  reps: reps,
  done: done,
  loadConvention: convention,
  implementCount: count,
);
WorkoutSession session(
  String id,
  List<WorkoutExercise> exercises, {
  DateTime? date,
}) => WorkoutSession(
  id: id,
  type: WorkoutType.strength,
  date: date ?? DateTime(2026, 10, 1),
  exercises: exercises,
);

void main() {
  test(
    'records derive only from valid completed results and carry exact origin',
    () {
      final index = TrainingPerformanceIndex([
        session('a', [
          exercise([
            result('pending', kg: 1000, done: false),
            result('unknown', kg: 999, done: null),
            result('invalid', kg: double.nan),
            result('real'),
          ]),
        ]),
      ]);
      final records = index.records
          .where((r) => r.kind == RecordKind.load)
          .toList();
      expect(records.single.value, 60);
      expect(records.single.sessionId, 'a');
      expect(records.single.setIds, ['real']);
      expect(index.unknownCompletionSets, 1);
    },
  );
  test('duplicate exercise instances aggregate into one session observation and session volume', () {
    final index = TrainingPerformanceIndex([
      session('a', [
        exercise([result('one')]),
        exercise([result('two')]),
      ]),
    ]);
    expect(index.history['bench_press'], hasLength(1));
    expect(index.history['bench_press']!.single.sets, hasLength(2));
    expect(
      index.records
          .singleWhere((r) => r.kind == RecordKind.sessionVolume)
          .value,
      960,
    );
    expect(
      index.records
          .singleWhere((r) => r.kind == RecordKind.sessionVolume)
          .setIds,
      ['one', 'two'],
    );
  });
  test('dumbbell semantics never double legacy loads; explicit count alone enables volume multiplication', () {
    expect(
      WorkoutAnalytics.externalVolume(result('old', kg: 20, reps: 10)),
      200,
    );
    expect(
      WorkoutAnalytics.externalVolume(
        result(
          'pair',
          kg: 20,
          reps: 10,
          convention: LoadConvention.perImplement,
          count: 2,
        ),
      ),
      400,
    );
    final unknown = result(
      'unknown',
      kg: 20,
      convention: LoadConvention.perImplement,
    );
    expect(WorkoutAnalytics.externalLoadForVolume(unknown), isNull);
    final index = TrainingPerformanceIndex([
      session('a', [
        exercise([unknown]),
      ]),
    ]);
    expect(
      index.history['bench_press']!.single.value(ExerciseMetric.sessionVolume),
      isNull,
    );
    expect(
      index.records.where((r) => r.kind == RecordKind.sessionVolume),
      isEmpty,
    );
  });
  test('incompatible conventions, assistance and bodyweight do not compete as load records', () {
    final index = TrainingPerformanceIndex([
      session('a', [
        exercise([result('one', kg: 100)]),
        exercise([
          result(
            'two',
            kg: 60,
            convention: LoadConvention.perImplement,
            count: 2,
          ),
        ]),
        exercise(
          [SetEntry(id: 'as', assistanceKg: 80, reps: 8, done: true)],
          id: 'pull_up',
          load: RoutineExerciseLoadType.assistedKg,
        ),
        exercise(
          [SetEntry(id: 'bw', reps: 12, done: true)],
          id: 'pull_up',
          load: RoutineExerciseLoadType.bodyweight,
        ),
      ]),
    ]);
    expect(index.records.where((r) => r.kind == RecordKind.load), hasLength(2));
    expect(
      index.records.where(
        (r) => r.kind == RecordKind.repetitions && r.exerciseId == 'pull_up',
      ),
      hasLength(2),
    );
  });
  test('Epley is explicitly estimated, bounded to appropriate sets and never extrapolates rep records', () {
    final e = exercise([]);
    expect(
      TrainingPerformanceIndex.estimatedMax(e, result('one', kg: 100, reps: 1)),
      100,
    );
    expect(
      TrainingPerformanceIndex.estimatedMax(e, result('five', kg: 90, reps: 5)),
      105,
    );
    expect(
      TrainingPerformanceIndex.estimatedMax(e, result('many', reps: 11)),
      isNull,
    );
    expect(
      TrainingPerformanceIndex.estimatedMax(e, result('pending', done: false)),
      isNull,
    );
    expect(
      TrainingPerformanceIndex.estimatedMax(
        exercise(
          [],
          id: 'pull_up',
          load: RoutineExerciseLoadType.addedWeightKg,
        ),
        result('lastre'),
      ),
      isNull,
    );
    final index = TrainingPerformanceIndex([
      session('a', [
        exercise([result('five', reps: 5)]),
      ]),
    ]);
    expect(
      index.records
          .singleWhere((r) => r.kind == RecordKind.estimatedMax)
          .estimated,
      isTrue,
    );
    expect(
      index.records
          .where((r) => r.kind == RecordKind.repLoad)
          .map((r) => r.reps),
      [5],
    );
  });
  test(
    'rebuilding after correcting or deleting source recalculates all records',
    () {
      final first = session('first', [
        exercise([result('one', kg: 90)]),
      ]);
      final later = session('later', [
        exercise([result('two', kg: 100)]),
      ], date: DateTime(2026, 10, 2));
      expect(
        TrainingPerformanceIndex([first, later]).records
            .firstWhere((r) => r.kind == RecordKind.load)
            .sessionId,
        'later',
      );
      final corrected = session('later', [
        exercise([result('two', kg: 80)]),
      ], date: DateTime(2026, 10, 2));
      expect(
        TrainingPerformanceIndex([first, corrected]).records
            .firstWhere((r) => r.kind == RecordKind.load)
            .sessionId,
        'first',
      );
      expect(
        TrainingPerformanceIndex([first]).records
            .firstWhere((r) => r.kind == RecordKind.load)
            .value,
        90,
      );
    },
  );
  test('period cutoffs use local calendar and exclude future sessions', () {
    final now = DateTime(2026, 10, 17, 13);
    final index = TrainingPerformanceIndex([
      session('edge', [
        exercise([result('one')]),
      ], date: DateTime(2026, 10, 11)),
      session('old', [
        exercise([result('two')]),
      ], date: DateTime(2026, 10, 10, 23, 59)),
      session('future', [
        exercise([result('three')]),
      ], date: DateTime(2026, 10, 18)),
    ]);
    expect(
      index
          .exerciseHistory('bench_press', period: TrainingPeriod.week, now: now)
          .map((o) => o.report.session.id),
      ['edge'],
    );
    expect(
      TrainingPeriod.quarter.start(DateTime(2026, 5, 31)),
      DateTime(2026, 2, 28),
    );
  });
  test('added optional metadata round-trips without changing prior values', () {
    final old = SetInSession.fromJson({
      'id': 'old',
      'index': 1,
      'kg': 20.0,
      'reps': 10,
      'done': true,
    });
    expect(old.loadConvention, LoadConvention.recorded);
    final modern = old.copyWith(
      loadConvention: LoadConvention.perImplement,
      implementCount: 2,
      rir: 0,
      note: 'Privada',
    );
    expect(SetInSession.fromJson(modern.toJson()).note, 'Privada');
    final saved = WorkoutAnalytics.fromLive([
      ExerciseInSession(
        id: 'instance',
        exerciseId: 'bench_press',
        name: 'Press banca',
        sets: [modern],
      ),
    ]).single.sets.single;
    expect(saved.implementCount, 2);
    expect(saved.note, 'Privada');
    expect(saved.rir, 0);
    expect(WorkoutAnalytics.externalVolume(saved), 400);
  });
  for (final size in [1, 50, 500]) {
    test('$size sessions retain all results in the performance index', () {
      final source = List.generate(
        size,
        (i) => session('session-$i', [
          exercise(
            List.generate(
              20,
              (j) => result('s-$i-$j', kg: 20 + (i % 10).toDouble()),
            ),
          ),
        ], date: DateTime(2024, 1, 1).add(Duration(days: i))),
      );
      final watch = Stopwatch()..start();
      final index = TrainingPerformanceIndex(source);
      watch.stop();
      expect(index.reports, hasLength(size));
      expect(
        index.history['bench_press']!.fold<int>(0, (n, o) => n + o.sets.length),
        size * 20,
      );
      // Host duration is an observation, never a device performance guarantee.
      // ignore: avoid_print
      print(
        'PERFORMANCE_INDEX_HOST: $size sessions / ${size * 20} sets / ${watch.elapsedMicroseconds} us',
      );
    });
  }
}
