import 'dart:convert';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/domain/workout_live_metrics.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutReport report(String id, DateTime date, {double kg = 50, String? routine = 'r', int reps = 8}) =>
    WorkoutReport(WorkoutSession(id: id, type: WorkoutType.strength, date: date,
      templateId: routine, durationSeconds: 286, durationIsActive: true,
      exercises: [WorkoutExercise(id: 'bench_press', name: 'Press banca',
        targetLoadType: RoutineExerciseLoadType.weightedKg,
        sets: [SetEntry(id: 's', externalLoadKg: kg, reps: reps, done: true)])]));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('live and saved formulas agree, preserving seconds and excluding unfinished sets', () async {
    const exercises = [ExerciseInSession(id: 'e', exerciseId: 'bench_press', name: 'Press banca',
      restEnabled: false, restSeconds: 90, sets: [
        SetInSession(id: 's1', index: 1, kg: 50, reps: 8, done: true),
        SetInSession(id: 's2', index: 2, kg: 80, reps: 20),
      ])];
    final repository = WorkoutRepository();
    await repository.persistCompletedWorkout(exercises, sessionId: 'a', duration: const Duration(seconds: 286));
    final saved = WorkoutReport((await repository.listSessions()).single);
    expect(saved.externalVolume, WorkoutLiveMetrics.computeTotalVolume(exercises));
    expect(saved.externalVolume, 400);
    expect(saved.performedSets, 1);
    expect(saved.programmedSets, 2);
    expect(saved.reps, 8);
    expect(saved.duration, const Duration(seconds: 286));
    expect(saved.session.exercises.single.restEnabled, isFalse);
  });
  test('ambiguous legacy weight remains intact without invented external load', () {
    final set = SetEntry.fromJson({'id': 'old', 'weight': 80, 'reps': 10});
    expect(set.externalLoadKg, 80);
    expect(set.loadIsAmbiguous, isTrue);
    expect(WorkoutAnalytics.externalVolume(set), 0);
    expect(SetEntry.fromJson(set.toJson()).loadIsAmbiguous, isTrue);
    expect(WorkoutAnalytics.externalVolume(SetEntry(id: 'bw', reps: 10, bodyweightKg: 80)), 0);
    expect(WorkoutAnalytics.externalVolume(SetEntry(id: 'as', reps: 10, assistanceKg: 30)), 0);
    expect(WorkoutAnalytics.externalVolume(SetEntry(id: 'add', reps: 10, bodyweightKg: 80, externalLoadKg: 5)), 50);
  });
  test('muscle distribution counts valid sets rather than mixing kilograms with points', () {
    final session = WorkoutSession(id: 'mixed', type: WorkoutType.strength, date: DateTime(2026), exercises: [
      WorkoutExercise(id: 'bench_press', name: 'Banca', sets: [SetEntry(id: 'a', reps: 8, externalLoadKg: 100, done: true)]),
      WorkoutExercise(id: 'lat_pulldown', name: 'Jalón', sets: [SetEntry(id: 'b', reps: 8, externalLoadKg: 10, done: true)]),
      WorkoutExercise(id: 'unknown', name: 'Sin catálogo', sets: [SetEntry(id: 'c', reps: 50, done: true)]),
    ]);
    final distribution = WorkoutReport(session).muscleDistribution;
    expect(distribution['Pecho'], .5);
    expect(distribution['Espalda'], .5);
    expect(distribution['Core'], 0);
    expect(WorkoutAnalytics.externalVolume(SetEntry(id: 'bad', externalLoadKg: double.nan, reps: 8)), 0);
  });
  test('comparison prefers same routine, rejects future/different structure and divides by no zero', () {
    final current = report('current', DateTime(2026, 10, 12), kg: 60);
    final previous = report('previous', DateTime(2026, 10, 10));
    final unrelated = report('other', DateTime(2026, 10, 11), routine: 'other');
    final future = report('future', DateTime(2026, 10, 13), kg: 100);
    final comparison = WorkoutAnalytics.compare(current, [future, unrelated, previous])!;
    expect(comparison.previous.session.id, 'previous');
    expect(comparison.volumePercent, 20);
    final zero = report('zero', DateTime(2026, 10, 9), kg: 0);
    expect(WorkoutComparison(previous: zero, current: current).volumePercent, isNull);
    expect(WorkoutAnalytics.compare(current, [future]), isNull);
    expect(WorkoutAnalytics.compare(current, []), isNull);
  });
  test('local date boundaries, zero weeks and actual-period weekly frequency', () {
    final source = [
      report('edge', DateTime(2026, 10, 6)), report('out', DateTime(2026, 10, 5, 23, 59)),
      report('today', DateTime(2026, 10, 12, 23)), report('future', DateTime(2026, 10, 13)),
    ];
    final week = WorkoutHistoryReport(source: source, period: WorkoutHistoryPeriod.week, now: DateTime(2026, 10, 12, 12));
    expect(week.sessions.map((s) => s.session.id), ['today', 'edge']);
    expect(week.periodDays, 7);
    expect(week.weeklyFrequency, 2);
    expect(week.activity.fold(0, (sum, item) => sum + item.sessions), 2);
    final empty = WorkoutHistoryReport(source: [], period: WorkoutHistoryPeriod.month, now: DateTime(2026, 1, 2));
    expect(empty.activity.every((week) => week.sessions == 0), isTrue);
    expect(empty.periodDays, 30);
    expect(empty.weeklyFrequency, 0);
    final quarter = WorkoutHistoryReport(source: [], period: WorkoutHistoryPeriod.quarter, now: DateTime(2026, 5, 31));
    expect(quarter.periodDays, 93); // Feb 28 through May 31, inclusive.
  });
  test('legacy rows with invalid dates remain stored and are reported', () async {
    final prefs = await SharedPreferences.getInstance();
    final invalid = {'id': 'bad', 'type': 'strength', 'date': 'incorrecta'};
    await prefs.setString(WorkoutRepository.legacySessionsKey, jsonEncode([invalid]));
    final repository = WorkoutRepository();
    expect(await repository.listAllSessions(), isEmpty);
    expect(repository.unreadableHistoryRows, 1);
    await repository.persistLegacySession(report('new', DateTime(2026, 10, 12)).session);
    expect((jsonDecode(prefs.getString(WorkoutRepository.legacySessionsKey)!) as List).first, invalid);
    expect(await repository.findSession('new'), isNotNull);
  });
}
