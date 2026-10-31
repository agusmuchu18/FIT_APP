import 'dart:convert';
import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/domain/sport_activity.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/exercise_configuration_sheet.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routine_preview_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_review_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:fit_app/features/workout/training_home/template_workout_type.dart';
import 'package:fit_app/features/workout/training_home/training_home_controller.dart';
import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Deterministic visual fixtures, never production sessions or fabricated usage.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> capture(
    WidgetTester tester,
    Widget home,
    String file, {
    Size size = const Size(390, 844),
    double scale = 1,
    double scroll = 0,
  }) async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await rootBundle.load(entry.value);
      await ui.loadFontFromList(
        bytes.buffer.asUint8List(),
        fontFamily: entry.key,
      );
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.workout,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: home,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    await tester.runAsync(() async {
      for (final asset in manifest.listAssets().where(
        (p) => p.startsWith('assets/images/workout/') && p.endsWith('.webp'),
      )) {
        for (final width in [160, 640]) {
          await precacheImage(
            ResizeImage(AssetImage(asset), width: width),
            context,
          );
        }
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pumpAndSettle();
    if (scroll != 0) {
      await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(file));
  }

  RoutineDraftController gym() {
    final draft = RoutineDraftController();
    for (final id in ['bench_press', 'pull_up', 'plank']) {
      draft.add(
        RoutineLabels.defaults(exerciseLibrary.singleWhere((e) => e.id == id)),
      );
    }
    draft.updateHeader(
      name: 'Fuerza del martes',
      notes: 'Preparar banco, barra y colchoneta.',
    );
    final bench = draft.items.first;
    draft.update(
      bench.instanceId!,
      bench.copyWith(targetSets: 4, targetWeightKg: 40, restSeconds: 90),
    );
    addTearDown(draft.dispose);
    return draft;
  }

  testWidgets('visual catalogue and its compact enlarged variant', (
    tester,
  ) async {
    await capture(
      tester,
      const TemplateExercisePickerScreen(),
      'routine_picker_visual.png',
    );
    await capture(
      tester,
      const TemplateExercisePickerScreen(),
      'routine_picker_accessible.png',
      size: const Size(320, 844),
      scale: 2,
    );
  });
  testWidgets('shared configuration and configured review', (tester) async {
    final draft = gym();
    await capture(
      tester,
      Scaffold(
        body: ExerciseConfigurationSheet(
          exercise: draft.items.first,
          definition: exerciseLibrary.first,
          action: 'Guardar configuración',
        ),
      ),
      'routine_configuration.png',
    );
    final review = RoutineReviewScreen(
      draftController: draft,
      exercisesById: {for (final e in exerciseLibrary) e.id: e},
      repository: RoutinesRepository(),
    );
    await capture(tester, review, 'routine_review_visual.png');
    await capture(
      tester,
      review,
      'routine_review_accessible.png',
      size: const Size(320, 844),
      scale: 2,
    );
    await capture(
      tester,
      review,
      'routine_review_wide.png',
      size: const Size(900, 844),
    );
    await capture(
      tester,
      review,
      'routine_review_cards_accessible.png',
      size: const Size(320, 844),
      scale: 2,
      scroll: 900,
    );
  });
  testWidgets('library and preview expose the saved plan', (tester) async {
    final draft = gym();
    final template = await RoutinesRepository().saveRoutine(
      name: draft.name,
      workoutType: WorkoutType.strength,
      exercises: draft.items,
      notes: draft.notes,
    );
    await capture(
      tester,
      const TrainingHomeScreen(),
      'routine_library_visual.png',
      scroll: 620,
    );
    await capture(
      tester,
      const TrainingHomeScreen(),
      'routine_library_accessible.png',
      size: const Size(320, 844),
      scale: 2,
      scroll: 1600,
    );
    final controller = TrainingHomeController();
    addTearDown(controller.dispose);
    await controller.initialize();
    await capture(
      tester,
      RoutinePreviewScreen(
        routine: template,
        controller: controller,
        typeLabel: 'Gimnasio',
        lastUsedLabel: 'Sin estrenar',
      ),
      'routine_preview_visual.png',
    );
  });
  testWidgets('football explorer and typed configuration', (tester) async {
    final draft = RoutineDraftController();
    addTearDown(draft.dispose);
    draft.setMode(TemplateWorkoutType.sport, FootballMode.physical);
    await capture(
      tester,
      TemplateExercisePickerScreen(draftController: draft),
      'routine_football_visual.png',
    );
    final e = WorkoutExercise(
      id: 'football_sprint',
      name: 'Sprint de 20 metros',
      targetSets: 1,
      measurement: 'seconds',
      sportPlan: SportActivityPlan(
        activityId: 'football_sprint',
        mode: FootballMode.physical,
        targets: SportMeasurements(
          values: {SportMetric.distanceMeters: 20, SportMetric.repetitions: 6},
        ),
        objective: 'Aceleración controlada',
      ),
    );
    await capture(
      tester,
      Scaffold(
        body: ExerciseConfigurationSheet(
          exercise: e,
          action: 'Agregar a rutina',
        ),
      ),
      'routine_football_configuration.png',
    );
  });
  testWidgets('unreadable draft has a visible recovery state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'workout_routine_draft_v2': jsonEncode({'invalid': true}),
    });
    await capture(
      tester,
      const TemplateExercisePickerScreen(),
      'routine_draft_error.png',
    );
  });
}
