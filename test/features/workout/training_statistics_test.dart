import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSession workout(
  String id,
  DateTime date, {
  bool? active = true,
  int? seconds = 60,
  bool? done = true,
}) => WorkoutSession(
  id: id,
  type: WorkoutType.strength,
  date: date,
  durationSeconds: seconds,
  durationIsActive: active,
  exercises: [
    WorkoutExercise(
      id: 'bench_press',
      name: 'Press banca',
      sets: [SetEntry(id: '$id-set', externalLoadKg: 50, reps: 8, done: done)],
    ),
  ],
);
void main() {
  test('calendar-month aggregation excludes next month, future days and handles zero comparison', () {
    final index = TrainingPerformanceIndex([
      workout('oct', DateTime(2026, 10, 1)),
      workout('future', DateTime(2026, 10, 18)),
      workout('nov', DateTime(2026, 11, 1)),
    ]);
    final data = TrainingStatistics(
      index: index,
      range: TrainingDateRange.month(2026, 10),
      now: DateTime(2026, 10, 17),
    );
    expect(data.sessions.map((r) => r.session.id), ['oct']);
    expect(data.observedDays, 17);
    expect(data.volume, 400);
    expect(data.reps, 8);
    expect(TrainingStatistics.percentChange(5, 0), isNull);
    expect(TrainingStatistics.percentChange(12, 10), 20);
  });
  test('direct and secondary sets are separate catalogue attributions, cardio is not anatomy', () {
    final data = TrainingStatistics(
      index: TrainingPerformanceIndex([workout('a', DateTime(2026, 10, 1))]),
      range: TrainingDateRange.month(2026, 10),
      now: DateTime(2026, 10, 17),
    );
    expect(data.muscleSummary[TrainingMuscle.chest]!.directSets, 1);
    expect(data.muscleSummary[TrainingMuscle.triceps]!.secondarySets, 1);
    expect(data.muscleSummary[TrainingMuscle.triceps]!.directSets, 0);
    expect(data.muscleSummary[TrainingMuscle.chest]!.exerciseIds, {
      'bench_press',
    });
    expect(TrainingMuscle.fromCatalogue('cardio'), isNull);
    expect(TrainingMuscle.fromCatalogue('estabilidad'), isNull);
    expect(TrainingMuscle.fromCatalogue('movilidad'), isNull);
    expect(data.muscleSummary[TrainingMuscle.core]!.directSets, 0);
  });
  test('unknown legacy completion is disclosed and cannot certify direct completed sets', () {
    final data = TrainingStatistics(
      index: TrainingPerformanceIndex([
        workout('a', DateTime(2026, 10, 1), done: null),
      ]),
      range: TrainingDateRange.month(2026, 10),
      now: DateTime(2026, 10, 17),
    );
    expect(data.unknownCompletion, isTrue);
    expect(data.sets, 1);
    expect(
      data.muscleSummary.values.every(
        (r) => r.directSets == 0 && r.secondarySets == 0,
      ),
      isTrue,
    );
  });
  test('known durations are totaled but incompatible duration kinds are never averaged together', () {
    final index = TrainingPerformanceIndex([
      workout('active', DateTime(2026, 10, 1), seconds: 60),
      workout('elapsed', DateTime(2026, 10, 2), active: false, seconds: 120),
      workout('unknown', DateTime(2026, 10, 3), seconds: null),
    ]);
    final data = TrainingStatistics(
      index: index,
      range: TrainingDateRange.month(2026, 10),
      now: DateTime(2026, 10, 17),
    );
    expect(data.durationSeconds, 180);
    expect(data.knownDurations, 2);
    expect(data.averageDurationSeconds, isNull);
    expect(data.durationKinds, hasLength(2));
  });
  test('ranking uses actual sessions, sets and recorded volume; never fabricates exercise time', () {
    final data = TrainingStatistics(
      index: TrainingPerformanceIndex([
        workout('a', DateTime(2026, 10, 1)),
        workout('b', DateTime(2026, 10, 2)),
      ]),
      range: TrainingDateRange.month(2026, 10),
      now: DateTime(2026, 10, 17),
    );
    expect(data.rank(ExerciseRanking.sessions).single.sessionIds, hasLength(2));
    expect(data.rank(ExerciseRanking.sets).single.sets, 2);
    expect(data.rank(ExerciseRanking.volume).single.volume, 800);
    expect(data.rank(ExerciseRanking.time), isEmpty);
  });
}
