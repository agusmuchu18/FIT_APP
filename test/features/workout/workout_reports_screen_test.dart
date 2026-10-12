import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/presentation/workout_summary_screen.dart';
import 'package:fit_app/features/workout/training_home/workout_history_screen.dart';
import 'package:fit_app/features/workout/presentation/widgets/workout_report_widgets.dart';

import '../../support/workout_report_fixture.dart';

void main() {
  testWidgets('radar uses absolute 0–100 scale and zero stays at the center', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutMuscleReport(
            report: WorkoutReport(workoutReportFixture()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<RadarChart>(find.byType(RadarChart));
    expect(chart.data.isMinValueAtCenter, true);
    expect(chart.data.minEntry.value, 0);
    expect(chart.data.maxEntry.value, 100);
    final values = chart.data.dataSets.last.dataEntries
        .map((e) => e.value)
        .toList();
    expect(values.where((v) => v == 0), hasLength(4));
    expect(values.reduce((a, b) => a + b), 100);
    expect(find.text('Espalda 50 %'), findsOneWidget);
    expect(find.text('Pecho 50 %'), findsOneWidget);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AccountStorageScope.current = '';
  });
  testWidgets(
    'summary resolves saved ID, retries a read error and opens persisted detail',
    (tester) async {
      final repository = WorkoutReportsRepository([
        workoutReportFixture(),
      ], fail: true);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSummaryScreen(
            sessionId: 'saved',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo leer'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.textContaining('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Entrenamiento completado'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ver entrenamiento completo'),
        400,
      );
      await tester.tap(find.text('Ver entrenamiento completo'));
      await tester.pumpAndSettle();
      expect(find.text('Detalle'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Serie 2'), 300);
      expect(find.textContaining('Pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown summary ID is explicit and never shows another session',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSummaryScreen(
            sessionId: 'missing',
            repository: WorkoutReportsRepository([workoutReportFixture()]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no está disponible en esta cuenta'),
        findsOneWidget,
      );
      expect(find.text('Entrenamiento completado'), findsNothing);
    },
  );
  testWidgets(
    'history distinguishes empty data, starts training and supports read retry',
    (tester) async {
      final repository = WorkoutReportsRepository([], fail: true);
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/workout': (_) => const Scaffold(body: Text('Entrenar'))},
          home: WorkoutHistoryScreen(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo cargar'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.textContaining('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tu historial empieza con tu próxima sesión'),
        findsOneWidget,
      );
      await tester.tap(find.text('Empezar entrenamiento'));
      await tester.pumpAndSettle();
      expect(find.text('Entrenar'), findsOneWidget);
    },
  );
  testWidgets(
    'history persists account filter and calculates without rereading on selection',
    (tester) async {
      final repository = WorkoutReportsRepository([
        workoutReportFixture(date: DateTime(2026, 8, 1)),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutHistoryScreen(
            repository: repository,
            now: DateTime(2026, 10, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin entrenamientos en este período'), findsOneWidget);
      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();
      expect(find.text('Actividad semanal'), findsOneWidget);
      expect(repository.reads, 1);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'workout_history_period',
        ),
        'all',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutHistoryScreen(
            repository: repository,
            now: DateTime(2026, 10, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todo'))
            .selected,
        true,
      );
      AccountStorageScope.current = AccountStorageScope.forUser('another');
      expect(
        (await ScopedPreferences.getInstance()).getString(
          'workout_history_period',
        ),
        isNull,
      );
    },
  );
  testWidgets('large history builds only visible report cards', (tester) async {
    final repository = WorkoutReportsRepository(
      List.generate(
        500,
        (i) => workoutReportFixture(
          id: 's$i',
          date: DateTime(2026, 10, 12).subtract(Duration(days: i)),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutHistoryScreen(
          repository: repository,
          now: DateTime(2026, 10, 12),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutArtwork).evaluate().length, lessThan(20));
    expect(repository.reads, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'summary and history remain usable at 320px, text 200%, reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = WorkoutReportsRepository([workoutReportFixture()]);
      Widget app(Widget screen) => MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: screen,
      );
      await tester.pumpWidget(
        app(WorkoutSummaryScreen(sessionId: 'saved', repository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ver entrenamiento completo'),
        300,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          WorkoutHistoryScreen(
            repository: repository,
            now: DateTime(2026, 10, 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
