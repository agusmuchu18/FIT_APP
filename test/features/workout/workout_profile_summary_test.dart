import 'dart:async';

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/profile/profile_social_screen.dart';
import 'package:fit_app/features/profile/widgets/profile_social_widgets.dart';
import 'package:fit_app/features/workout/data/workout_preferences.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/training_units.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/presentation/widgets/workout_units_host.dart';
import 'package:fit_app/features/workout/presentation/workout_profile_summary.dart';
import 'package:fit_app/features/workout/presentation/workout_records_panel.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'training_test_fixtures.dart';

class _ProfileRepository extends WorkoutRepository {
  _ProfileRepository(this.sessions);
  final List<WorkoutSession> sessions;
  bool fail = false;
  Completer<TrainingPerformanceIndex>? pending;
  int reads = 0;
  @override
  Future<TrainingPerformanceIndex> performanceIndex({
    bool refresh = false,
  }) async {
    reads++;
    if (pending case final waiting?) return waiting.future;
    if (fail) throw StateError('Fixture disk read failure');
    return TrainingPerformanceIndex(sessions, asOf: DateTime(2026, 10, 17));
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  final now = DateTime(2026, 10, 17);
  WorkoutProfileSummary summary(List<WorkoutSession> sessions) =>
      WorkoutProfileSummary.fromIndex(
        TrainingPerformanceIndex(sessions, asOf: now),
        now: now,
      );

  test('profile uses canonical session counts, 30-day statistics and a traceable current record', () {
    final data = summary(trainingFixtureSessions());
    expect(data.allSessions, 4);
    expect(data.recent.sets, 4);
    expect(data.recent.sessionsByDay.length, 4);
    expect(data.recent.volume, 1720);
    expect(data.latestRecord!.kind, RecordKind.load);
    expect(data.latestRecord!.value, 57.5);
    expect(data.latestRecord!.sessionId, 'session-3');
    expect(data.recent.averageDurationSeconds, 1200);
  });
  test('empty history and unknown historical completion never fabricate a PR or measured duration', () {
    final empty = summary([]);
    expect(empty.allSessions, 0);
    expect(empty.latestRecord, isNull);
    expect(empty.recent.averageDurationSeconds, isNull);
    final source = WorkoutSession(
      id: 'legacy',
      type: WorkoutType.strength,
      date: now,
      exercises: [
        WorkoutExercise(
          id: 'bench_press',
          name: 'Press banca',
          sets: [SetEntry(id: 's', externalLoadKg: 120, reps: 8)],
        ),
      ],
    );
    final data = summary([source]);
    expect(data.recent.unknownCompletion, isTrue);
    expect(data.latestRecord, isNull);
    expect(data.recent.knownDurations, 0);
  });
  test('all-time count and current period remain distinct and future days are excluded', () {
    final current = trainingFixtureSessions();
    final old = WorkoutSession.fromJson({
      ...current.first.toJson(),
      'id': 'old',
      'date': DateTime(2025, 1, 1).toIso8601String(),
    });
    final future = WorkoutSession.fromJson({
      ...current.first.toJson(),
      'id': 'future',
      'date': DateTime(2026, 10, 18).toIso8601String(),
    });
    final data = summary([...current, old, future]);
    expect(data.allSessions, 5);
    expect(data.recent.sessions, hasLength(4));
    expect(data.latestRecord!.sessionId, isNot('future'));
  });

  Future<void> mount(
    WidgetTester tester,
    _ProfileRepository repo, {
    double width = 390,
    double scale = 1,
    TrainingUnits units = const TrainingUnits(),
    bool active = true,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: WorkoutUnits(
            preferences: WorkoutPreferences(units: units),
            child: child!,
          ),
        ),
        home: ProfileSocialScreen(
          repository: repo,
          now: now,
          photos: const [],
          active: active,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Map<String, String> hero(WidgetTester tester) => {
    for (final item
        in tester.widget<ProfileHero>(find.byType(ProfileHero)).stats)
      item.label: item.value,
  };

  testWidgets(
    'hidden profile defers loading and coalesces history changes until it is opened',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions());
      await mount(tester, repo, active: false);
      expect(repo.reads, 0);
      repo.invalidateHistory();
      await tester.pump();
      expect(repo.reads, 0);
      await mount(tester, repo);
      expect(hero(tester)['Entrenos'], '4');
      final reads = repo.reads;
      await mount(tester, repo, active: false);
      repo.sessions.clear();
      repo.invalidateHistory();
      await tester.pump();
      expect(repo.reads, reads);
      await mount(tester, repo);
      expect(hero(tester)['Entrenos'], '0');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'hidden PR panel waits for activation and refreshes saved history on return',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions());
      Widget panel(bool active) => MaterialApp(
        home: Scaffold(
          body: WorkoutRecordsPanel(repository: repo, active: active),
        ),
      );
      await tester.pumpWidget(panel(false));
      await tester.pump();
      expect(repo.reads, 0);
      await tester.pumpWidget(panel(true));
      await tester.pumpAndSettle();
      expect(repo.reads, greaterThan(0));
      final reads = repo.reads;
      await tester.pumpWidget(panel(false));
      repo.sessions.clear();
      repo.invalidateHistory();
      await tester.pump();
      expect(repo.reads, reads);
      await tester.pumpWidget(panel(true));
      await tester.pumpAndSettle();
      expect(find.textContaining('Todavía no hay récords'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile displays real data, reacts to deletion and shares the source with its PR tab',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions());
      await mount(tester, repo);
      expect(hero(tester)['Entrenos'], '4');
      expect(hero(tester)['Última marca'], '57,5');
      expect(find.text('148'), findsNothing);
      expect(find.text('Óptima'), findsNothing);
      await tester.tap(find.text('Estadísticas'));
      await tester.pumpAndSettle();
      expect(find.text('Tu entrenamiento · últimos 30 días'), findsOneWidget);
      repo.sessions.clear();
      repo.invalidateHistory();
      await tester.pumpAndSettle();
      expect(hero(tester)['Entrenos'], '0');
      expect(hero(tester)['Última marca'], '—');
      await tester.tap(find.text('PRs'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Todavía no hay récords'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'storage failure stays distinct from empty history and retry restores real counters',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions())..fail = true;
      await mount(tester, repo);
      expect(hero(tester)['Entrenos'], '—');
      await tester.tap(find.text('Estadísticas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudieron leer'), findsOneWidget);
      expect(find.textContaining('Sin sesiones guardadas'), findsNothing);
      repo.fail = false;
      await tester.tap(find.text('Reintentar estadísticas'));
      await tester.pumpAndSettle();
      expect(hero(tester)['Entrenos'], '4');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'PR filters survive switching tabs without rereading the repository',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions());
      await mount(tester, repo);
      await tester.tap(find.text('PRs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 días').last);
      await tester.pumpAndSettle();
      final reads = repo.reads;
      await tester.tap(find.text('Fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PRs'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<TrainingPeriod>>(
              find.byType(DropdownButton<TrainingPeriod>),
            )
            .value,
        TrainingPeriod.week,
      );
      expect(repo.reads, reads);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'changing display units reuses the loaded profile snapshot without storage work',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions());
      await mount(tester, repo);
      final reads = repo.reads;
      await mount(
        tester,
        repo,
        units: const TrainingUnits(weight: WeightUnit.lb),
      );
      expect(repo.reads, reads);
      expect(hero(tester)['Última marca'], '126,77');
      expect(
        repo.sessions.last.exercises.single.sets.single.externalLoadKg,
        57.5,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('late account results cannot overwrite the new owner snapshot', (
    tester,
  ) async {
    final old = _ProfileRepository([])
      ..pending = Completer<TrainingPerformanceIndex>();
    await mount(tester, old);
    expect(hero(tester)['Entrenos'], '…');
    AccountStorageScope.current = AccountStorageScope.forUser(
      'profile-new-owner',
    );
    final fresh = _ProfileRepository(trainingFixtureSessions());
    await mount(tester, fresh);
    expect(hero(tester)['Entrenos'], '4');
    old.pending!.complete(TrainingPerformanceIndex([], asOf: now));
    await tester.pumpAndSettle();
    expect(hero(tester)['Entrenos'], '4');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'profile metrics retain units and readability at 320px and 200 percent',
    (tester) async {
      final repo = _ProfileRepository(trainingFixtureSessions());
      await mount(
        tester,
        repo,
        width: 320,
        scale: 2,
        units: const TrainingUnits(weight: WeightUnit.lb),
      );
      final items = tester.widget<ProfileHero>(find.byType(ProfileHero)).stats;
      expect(items.last.unit, 'lb');
      expect(items.last.value, '126,77');
      expect(
        tester
            .widgetList<AnimatedSwitcher>(find.byType(AnimatedSwitcher))
            .every((s) => s.duration == Duration.zero),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Estadísticas'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(NestedScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Estadísticas'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Volumen externo (30d)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('lb·rep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
