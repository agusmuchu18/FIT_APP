import 'training_test_fixtures.dart';

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/presentation/workout_insights_screen.dart';
import 'package:fit_app/features/workout/presentation/workout_records_panel.dart';
import 'package:fit_app/features/workout/presentation/widgets/set_row.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/exercise_technical_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'exercise tabs retain unsaved permanent notes and real history at 320',
    (tester) async {
      final library = TrainingFixtureLibrary(),
          repository = TrainingFixtureRepository(trainingFixtureSessions());
      await mount(
        tester,
        ExerciseTechnicalScreen(
          exercise: trainingFixtureExercise(),
          repository: repository,
          library: library,
        ),
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Tu nota'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).hitTestable().first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Tu nota'),
        'Nota editada',
      );
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('4 sesiones registradas'), findsOneWidget);
      await tester.tap(find.text('Resumen'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(TextField, 'Tu nota'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).hitTestable().first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Tu nota'))
            .controller!
            .text,
        'Nota editada',
      );
      await tester.ensureVisible(find.text('Guardar nota'));
      await tester.tap(find.text('Guardar nota'));
      await tester.pumpAndSettle();
      expect(library.note, 'Nota editada');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Técnica'));
      await tester.pumpAndSettle();
      expect(find.text('Descripción'), findsOneWidget);
    },
  );
  testWidgets('empty exercise and PR panels never show invented records', (
    tester,
  ) async {
    final repo = TrainingFixtureRepository([]);
    await mount(
      tester,
      ExerciseTechnicalScreen(
        exercise: trainingFixtureExercise(),
        repository: repo,
        library: TrainingFixtureLibrary(),
      ),
    );
    expect(find.textContaining('Todavía no hay series'), findsOneWidget);
    await mount(
      tester,
      Scaffold(body: WorkoutRecordsPanel(repository: repo)),
      scale: 2,
      theme: AppTheme.light,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Todavía no hay récords'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).hitTestable().first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Todavía no hay récords'), findsOneWidget);
    expect(find.textContaining('140 kg'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'insights tabs and monthly reports reflow at 320 and 200 percent',
    (tester) async {
      await mount(
        tester,
        WorkoutInsightsScreen(
          library: TrainingFixtureLibrary(),
          repository: TrainingFixtureRepository(trainingFixtureSessions()),
          now: DateTime(2026, 10, 17),
        ),
        scale: 2,
        theme: AppTheme.light,
      );
      await tester.scrollUntilVisible(
        find.text('Actividad diaria'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(ListView).hitTestable().first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Actividad diaria'), findsOneWidget);
      await tester.ensureVisible(find.text('Músculos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Músculos'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ListView).hitTestable().last,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Calendario'));
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Un día sin registro'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Informes'));
      await tester.tap(find.text('Informes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Mes actual parcial'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).hitTestable().first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.textContaining('Mes actual parcial'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'advanced series fields stay collapsed and preserve explicit load convention',
    (tester) async {
      var set = const SetInSession(id: 's', index: 1, kg: 20, reps: 8);
      var expanded = false;
      await mount(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, update) => SetRow(
                set: set,
                isExpanded: expanded,
                onToggleExpanded: () => update(() => expanded = !expanded),
                onDetailsChanged: (value) => update(() => set = value),
                onChanged: ({kg, clearKg, reps, clearReps, done}) => update(
                  () => set = set.copyWith(
                    kg: kg,
                    clearKg: clearKg ?? false,
                    reps: reps,
                    clearReps: clearReps ?? false,
                    done: done,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Cómo registrás la carga'), findsNothing);
      await tester.tap(find.byTooltip('Detalles de serie 1'));
      await tester.pumpAndSettle();
      expect(find.text('Cómo registrás la carga'), findsOneWidget);
      await tester.tap(find.text('Tal como fue registrada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por implemento').last);
      await tester.pumpAndSettle();
      expect(set.loadConvention, LoadConvention.perImplement);
      expect(set.hasValidResult(isTimed: false), isFalse);
      await tester.ensureVisible(find.text('Cantidad de implementos'));
      await tester.tap(find.text('Cantidad de implementos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dos implementos').last);
      await tester.pumpAndSettle();
      expect(set.implementCount, 2);
      expect(set.hasValidResult(isTimed: false), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
