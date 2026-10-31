import 'dart:async';
import 'dart:io';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/core/data/account_session_gate.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  testWidgets(
    'account switch disposes a shared Navigator and its private routes',
    (tester) async {
      final accounts = StreamController<String?>.broadcast(sync: true);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AccountSessionGate<String>(
          accounts: accounts.stream,
          restore: (id, scope) async => id!,
          builder: (id) => MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(body: Text('Cuenta $id')),
          ),
        ),
      );
      accounts.add('A');
      await tester.pumpAndSettle();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Sesión privada A')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sesión privada A'), findsOneWidget);
      accounts.add('B');
      await tester.pumpAndSettle();
      expect(find.text('Cuenta B'), findsOneWidget);
      expect(find.text('Sesión privada A'), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(accounts.close);
    },
  );
  test('concurrent routine saves preserve both routines', () async {
    final first = RoutinesRepository();
    final second = RoutinesRepository();
    await Future.wait([
      first.saveRoutine(
        name: 'A',
        workoutType: WorkoutType.strength,
        exercises: [WorkoutExercise(id: 'bench_press', name: 'Press banca')],
      ),
      second.saveRoutine(
        name: 'B',
        workoutType: WorkoutType.strength,
        exercises: [WorkoutExercise(id: 'bench_press', name: 'Press banca')],
      ),
    ]);
    expect((await first.getAllRoutines()).map((routine) => routine.name), [
      'A',
      'B',
    ]);
  });
  test(
    'guest, account A and account B retain independent data and late writes',
    () async {
      final guest = WorkoutRepository();
      final guestRoutines = RoutinesRepository();
      await guest.persistDraftWithStartTime(
        [],
        startTime: DateTime(2026),
        workoutId: 'guest-draft',
      );
      await guestRoutines.saveRoutine(
        name: 'Invitado',
        workoutType: WorkoutType.strength,
        exercises: [WorkoutExercise(id: 'bench_press', name: 'Press banca')],
      );
      AccountStorageScope.current = AccountStorageScope.forUser('A');
      final accountA = WorkoutRepository();
      final routinesA = RoutinesRepository();
      expect(await accountA.loadDraftExercises(), isNull);
      expect(await routinesA.getAllRoutines(), isEmpty);
      await accountA.persistDraftWithStartTime(
        [],
        startTime: DateTime(2026),
        workoutId: 'A-draft',
      );
      await routinesA.saveRoutine(
        name: 'A',
        workoutType: WorkoutType.strength,
        exercises: [WorkoutExercise(id: 'bench_press', name: 'Press banca')],
      );
      AccountStorageScope.current = AccountStorageScope.forUser('B');
      expect(await WorkoutRepository().loadDraftExercises(), isNull);
      expect(await RoutinesRepository().getAllRoutines(), isEmpty);
      await guest.persistDraftWithStartTime(
        [],
        startTime: DateTime(2026),
        workoutId: 'guest-late',
      );
      await guestRoutines.saveRoutine(
        name: 'Invitado tardío',
        workoutType: WorkoutType.strength,
        exercises: [WorkoutExercise(id: 'bench_press', name: 'Press banca')],
      );
      expect(await WorkoutRepository().loadDraftExercises(), isNull);
      expect((await accountA.loadDraftIdentity())!.sessionId, 'A-draft');
      expect(routinesA.watchRoutines().value.map((item) => item.name), ['A']);
      AccountStorageScope.current = '';
      expect(
        (await WorkoutRepository().loadDraftIdentity())!.sessionId,
        'guest-late',
      );
      expect(await RoutinesRepository().getAllRoutines(), hasLength(2));
    },
  );

  test(
    'Hive rich sessions and Home projection survive reopen in their owner',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fit-account-test-',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      final guestLocal = await LocalStorageService.create();
      await Hive.openBox<String>(WorkoutRepository.richSessionsBoxName);
      final guest = WorkoutRepository();
      await guest.persistCompletedWorkout(const [
        ExerciseInSession(
          id: 'ex',
          exerciseId: 'bench_press',
          name: 'Press',
          sets: [SetInSession(id: 'set', index: 1, reps: 8, done: true)],
        ),
      ], sessionId: 'guest');
      await guestLocal.saveWorkout(
        WorkoutEntry(
          id: 'guest',
          name: 'Invitado',
          durationMinutes: 10,
          intensity: 'No registrada',
        ),
      );
      final scope = AccountStorageScope.forUser('account');
      AccountStorageScope.current = scope;
      final accountLocal = await LocalStorageService.create(scope: scope);
      final account = WorkoutRepository();
      await Hive.openBox<String>(account.sessionsBoxName);
      expect(await account.listSessions(), isEmpty);
      expect(await accountLocal.fetchWorkouts(), isEmpty);
      await Hive.close();
      AccountStorageScope.current = '';
      final reopened = await LocalStorageService.create();
      await Hive.openBox<String>(WorkoutRepository.richSessionsBoxName);
      expect((await WorkoutRepository().listSessions()).single.id, 'guest');
      expect((await reopened.fetchWorkouts()).single.id, 'guest');
    },
  );

  testWidgets('late account restoration cannot display the previous account', (
    tester,
  ) async {
    final accounts = StreamController<String?>.broadcast(sync: true);
    final a = Completer<String>();
    final b = Completer<String>();
    await tester.pumpWidget(
      AccountSessionGate<String>(
        accounts: accounts.stream,
        restore: (id, scope) => id == 'A' ? a.future : b.future,
        builder: (value) => MaterialApp(home: Text(value)),
      ),
    );
    accounts.add('A');
    await tester.pump();
    accounts.add('B');
    await tester.pump();
    b.complete('Cuenta B');
    await tester.pumpAndSettle();
    a.complete('Cuenta A');
    await tester.pumpAndSettle();
    expect(find.text('Cuenta B'), findsOneWidget);
    expect(find.text('Cuenta A'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(accounts.close);
  });
}
