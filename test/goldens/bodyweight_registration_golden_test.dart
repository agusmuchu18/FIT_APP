import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/presentation/workout_in_progress_screen.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/exercise_configuration_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  Future<void> surface(
    WidgetTester tester, {
    bool light = false,
    double width = 390,
    double scale = 1,
    bool timed = false,
    bool completedFirst = false,
  }) async {
    for (final e in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await rootBundle.load(e.value);
      await ui.loadFontFromList(data.buffer.asUint8List(), fontFamily: e.key);
    }
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      WorkoutRepository.draftKey,
      jsonEncode({
        'workoutId': 'test-only-bodyweight',
        'sessionStart': '2026-10-24T10:00:00',
        'isPaused': true,
        'pausedAt': '2026-10-24T10:10:00',
        'exercises': [
          ExerciseInSession(
            id: 'exercise',
            exerciseId: timed ? 'plank' : 'pull_up',
            name: timed ? 'Plancha' : 'Dominadas pronas',
            isTimed: timed,
            sets: [
              SetInSession(
                id: 'one',
                index: 1,
                reps: timed ? null : 10,
                durationSeconds: timed ? 45 : null,
                done: completedFirst,
              ),
              if (!timed) const SetInSession(id: 'two', index: 2, reps: 8),
            ],
          ).toJson(),
        ],
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: light ? AppTheme.light : AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const WorkoutInProgressScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> see(WidgetTester t, Finder target) async {
    // The session header collapses while scrolling. Settle each drag before
    // checking the target's hit region, rather than only its presence in a sliver.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      await t.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await t.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
  }

  testWidgets(
    'default bodyweight table hides kg and enables added load inline',
    (t) async {
      await surface(t);
      expect(find.byKey(const ValueKey('set-load-one')), findsNothing);
      expect(find.byKey(const ValueKey('set-load-two')), findsNothing);
      expect(find.text('REPS'), findsOneWidget);
      expect(find.text('KG'), findsNothing);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('bodyweight_default.png'),
      );
      await see(t, find.text('Añadir lastre o asistencia'));
      await t.tap(find.text('Añadir lastre o asistencia'));
      await t.pumpAndSettle();
      await t.tap(find.text('Con lastre'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byKey(const ValueKey('set-load-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('set-load-two')), findsOneWidget);
      expect(find.text('LASTRE'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'mixed modes use per-set inline choices and keep completed rows intact',
    (t) async {
      await surface(t, completedFirst: true);
      await see(t, find.text('Añadir lastre o asistencia'));
      await t.tap(find.text('Añadir lastre o asistencia'));
      await t.pumpAndSettle();
      await t.tap(find.text('Con lastre'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('set-load-one')), findsNothing);
      expect(find.byKey(const ValueKey('set-load-two')), findsOneWidget);
      await t.enterText(find.byKey(const ValueKey('set-load-two')), '10');
      await see(t, find.byTooltip('Detalles de serie 2'));
      await t.tap(find.byTooltip('Detalles de serie 2'));
      await t.pumpAndSettle();
      final second = find.byKey(const ValueKey('two'));
      final assistance = find.descendant(
        of: second,
        matching: find.text('Con asistencia'),
      );
      await see(t, assistance);
      await t.tap(assistance);
      await t.pumpAndSettle();
      await see(t, find.byKey(const ValueKey('set-load-two')));
      await t.enterText(find.byKey(const ValueKey('set-load-two')), '20');
      await t.pump(const Duration(seconds: 1));
      final saved = (await WorkoutRepository().loadDraftExercises())!.single;
      expect(saved.sets.first.done, true);
      expect(saved.sets.first.loadType, RoutineExerciseLoadType.bodyweight);
      expect(saved.sets.last.loadType, RoutineExerciseLoadType.assistedKg);
      expect(saved.sets.last.assistanceKg, 20);
      expect(saved.sets.last.kg, 10);
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('set-load-two')))
            .decoration!
            .prefixIcon,
        isNotNull,
      );
      expect(find.text('−'), findsOneWidget);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('bodyweight_mixed_inline.png'),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('plank shows time in light theme without a kg field', (t) async {
    await surface(t, timed: true, light: true);
    expect(find.text('TIEMPO'), findsOneWidget);
    expect(find.byKey(const ValueKey('set-load-one')), findsNothing);
    expect(find.byKey(const ValueKey('set-result-one')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('bodyweight_timed_light.png'),
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'bodyweight options reflow at 320px and 200 percent without a modal',
    (t) async {
      await surface(t, width: 320, scale: 2);
      expect(find.byKey(const ValueKey('set-load-one')), findsNothing);
      await see(t, find.text('Añadir lastre o asistencia'));
      await t.tap(find.text('Añadir lastre o asistencia'));
      await t.pumpAndSettle();
      await see(t, find.text('Con asistencia'));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('bodyweight_accessible.png'),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'inline routine configuration preserves both optional load drafts',
    (t) async {
      final definition = exerciseLibrary.firstWhere((d) => d.id == 'pull_up');
      WorkoutExercise? value;
      await t.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExerciseConfigurationSheet(
                exercise: RoutineLabels.defaults(definition),
                definition: definition,
                inline: true,
                action: 'Agregar',
                onChanged: (e) => value = e,
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Tipo de carga'), findsNothing);
      await see(t, find.text('Añadir lastre o asistencia'));
      await t.tap(find.text('Añadir lastre o asistencia'));
      await t.pumpAndSettle();
      await t.tap(find.text('Con lastre'));
      await t.pumpAndSettle();
      final weight = find.widgetWithText(TextFormField, 'Lastre objetivo (kg)');
      await see(t, weight);
      await t.enterText(weight, '10');
      await t.pumpAndSettle();
      expect(value!.targetWeightKg, 10);
      await see(t, find.text('Con asistencia'));
      await t.tap(find.text('Con asistencia'));
      await t.pumpAndSettle();
      final assistance = find.widgetWithText(
        TextFormField,
        'Asistencia objetivo (kg)',
      );
      await see(t, assistance);
      await t.enterText(assistance, '25');
      await t.pumpAndSettle();
      expect(value!.targetAssistanceKg, 25);
      expect(value!.targetWeightKg, 10);
      await see(t, find.text('Solo peso corporal'));
      await t.tap(find.text('Solo peso corporal'));
      await t.pumpAndSettle();
      final restored = WorkoutExercise.fromJson(value!.toJson());
      expect(restored.targetLoadType, RoutineExerciseLoadType.bodyweight);
      expect(restored.plannedLoad, isNull);
      expect(restored.targetWeightKg, 10);
      expect(restored.targetAssistanceKg, 25);
      expect(find.byType(BottomSheet), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  for (final legacy in [true, false]) {
    testWidgets(
      'inline per-set assistance only converts legacy load ($legacy)',
      (t) async {
        final exercise =
            RoutineLabels.defaults(
              exerciseLibrary.firstWhere((d) => d.id == 'pull_up'),
            ).copyWith(
              loadSchemaVersion: legacy ? 0 : 1,
              targetLoadType: RoutineExerciseLoadType.assistedKg,
              targetSets: 1,
              setTargets: [
                RoutineSetTarget(
                  loadType: legacy ? null : RoutineExerciseLoadType.assistedKg,
                  reps: 8,
                  weightKg: 15,
                ),
              ],
            );
        final memory = ExerciseConfigurationMemory()..advanced = true;
        await t.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ExerciseConfigurationSheet(
                  exercise: exercise,
                  inline: true,
                  memory: memory,
                  action: 'Guardar',
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final field = find.byKey(const ValueKey('target-0-assistedKg'));
        await see(t, field);
        expect(t.widget<TextFormField>(field).initialValue, legacy ? '15' : '');
        expect(t.takeException(), isNull);
      },
    );
  }
}
