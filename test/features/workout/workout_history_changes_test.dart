import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/features/workout/application/workout_completion_recovery.dart';
import 'package:fit_app/features/workout/application/workout_history_mutation_service.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryProjectionFixture implements FitnessRepository {
  final entries = <String, WorkoutEntry>{};
  bool fail = false;
  int writes = 0;
  @override
  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    if (fail) throw StateError('Fixture disk failure');
    entries[entry.id] = entry;
    writes++;
  }

  @override
  Future<List<WorkoutEntry>> getWorkoutProjections() async =>
      entries.values.toList();
  @override
  Future<List<WorkoutEntry>> getWorkouts() async =>
      entries.values.where((e) => !e.deleted).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkoutSession _session({double kg = 60}) => WorkoutSession(
  id: 'original-session',
  type: WorkoutType.strength,
  date: DateTime(2026, 10, 1),
  durationMinutes: 20,
  durationSeconds: 1200,
  durationIsActive: true,
  exercises: [
    WorkoutExercise(
      id: 'bench_press',
      name: 'Press banca',
      targetLoadType: RoutineExerciseLoadType.weightedKg,
      sets: [
        SetEntry(id: 'original-set', externalLoadKg: kg, reps: 8, done: true),
      ],
    ),
  ],
);
void main() {
  late String originalScope;
  setUp(() {
    originalScope = AccountStorageScope.current;
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = originalScope);
  test('correction invalidates PRs, previous results, charts, calendar and volume without overwriting source rows', () async {
    final repository = WorkoutRepository(),
        fitness = HistoryProjectionFixture();
    await repository.persistLegacySession(_session());
    final before = (await SharedPreferences.getInstance()).getString(
      WorkoutRepository.legacySessionsKey,
    );
    final first = await repository.performanceIndex();
    expect(
      first.records.firstWhere((r) => r.kind == RecordKind.load).value,
      60,
    );
    await WorkoutHistoryMutationService(
      repository,
      fitness,
    ).correct(_session(kg: 40), expectedRevision: 0);
    final index = await repository.performanceIndex();
    expect(identical(first, index), isFalse);
    expect(
      index.records.firstWhere((r) => r.kind == RecordKind.load).value,
      40,
    );
    expect(
      (await repository.getPreviousSetsForExercise('bench_press')).single.kg,
      40,
    );
    expect(
      (await repository.loadLatestCompletedSessionExercises())!
          .single
          .sets
          .single
          .kg,
      40,
    );
    final stats = TrainingStatistics(
      index: index,
      range: TrainingDateRange.month(2026, 10),
      now: DateTime(2026, 10, 17),
    );
    expect(stats.volume, 320);
    expect(
      stats.sessionsByDay[DateTime(2026, 10, 1)]!.single.session.id,
      'original-session',
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        WorkoutRepository.legacySessionsKey,
      ),
      before,
    );
    expect(fitness.entries.keys, ['original-session']);
    expect(
      (await repository.historyChanges()).values.single.projectionPending,
      isFalse,
    );
  });
  test('deletion survives reopening and cannot resurrect a legacy source or its records', () async {
    final repository = WorkoutRepository(),
        fitness = HistoryProjectionFixture();
    await repository.persistLegacySession(_session());
    await recoverCompletedWorkouts(repository, fitness);
    await WorkoutHistoryMutationService(
      repository,
      fitness,
    ).delete('original-session', expectedRevision: 0);
    expect(await WorkoutRepository().listAllSessions(), isEmpty);
    expect((await repository.performanceIndex()).records, isEmpty);
    expect(await fitness.getWorkouts(), isEmpty);
    expect(fitness.entries['original-session']!.deleted, isTrue);
    await recoverCompletedWorkouts(WorkoutRepository(), fitness);
    expect(await fitness.getWorkouts(), isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getString(
        WorkoutRepository.legacySessionsKey,
      ),
      contains('original-set'),
    );
  });
  test('projection failure leaves a durable pending change and restart repairs it exactly once', () async {
    final repository = WorkoutRepository(),
        fitness = HistoryProjectionFixture()..fail = true;
    await repository.persistLegacySession(_session());
    await expectLater(
      WorkoutHistoryMutationService(
        repository,
        fitness,
      ).correct(_session(kg: 42), expectedRevision: 0),
      throwsA(isA<HistoryProjectionPending>()),
    );
    expect(
      (await WorkoutRepository().historyChanges())
          .values
          .single
          .projectionPending,
      isTrue,
    );
    expect(
      (await repository.listAllSessions())
          .single
          .exercises
          .single
          .sets
          .single
          .externalLoadKg,
      42,
    );
    fitness.fail = false;
    await recoverCompletedWorkouts(WorkoutRepository(), fitness);
    expect(fitness.writes, 1);
    await recoverCompletedWorkouts(WorkoutRepository(), fitness);
    expect(fitness.writes, 1);
    expect(
      (await repository.historyChanges()).values.single.projectionPending,
      isFalse,
    );
  });
  test('stale corrections are rejected and changes remain separated by account including late writes', () async {
    final guest = WorkoutRepository(), fitness = HistoryProjectionFixture();
    await guest.persistLegacySession(_session());
    await WorkoutHistoryMutationService(
      guest,
      fitness,
    ).correct(_session(kg: 42), expectedRevision: 0);
    await expectLater(
      guest.stageHistoryCorrection(_session(kg: 99), expectedRevision: 0),
      throwsStateError,
    );
    AccountStorageScope.current = AccountStorageScope.forUser('different-user');
    expect(await WorkoutRepository().listAllSessions(), isEmpty);
    await WorkoutHistoryMutationService(
      guest,
      fitness,
    ).delete('original-session', expectedRevision: 1);
    expect(await WorkoutRepository().historyChanges(), isEmpty);
    expect(await guest.listAllSessions(), isEmpty);
  });
  test('unknown versions are preserved and cannot silently reset corrected history', () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({
      'schemaVersion': 99,
      'changes': {'future': 'keep'},
    });
    await prefs.setString(WorkoutHistoryChanges.storageKey, raw);
    await expectLater(
      WorkoutRepository().listAllSessions(),
      throwsFormatException,
    );
    await expectLater(
      WorkoutRepository().stageHistoryDeletion(
        'original-session',
        expectedRevision: 0,
      ),
      throwsFormatException,
    );
    expect(prefs.getString(WorkoutHistoryChanges.storageKey), raw);
  });
}
