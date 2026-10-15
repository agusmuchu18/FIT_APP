import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/presentation/widgets/routine_filter_artwork.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/training_home/exercise_technical_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routine_filter_sheet.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await rootBundle.load(entry.value);
      await ui.loadFontFromList(
        data.buffer.asUint8List(),
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
        home: child,
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    await tester.runAsync(() async {
      for (final path in manifest.listAssets().where(
        (p) => p.startsWith('assets/images/workout/') && p.endsWith('.webp'),
      )) {
        for (final width in [160, 640]) {
          await precacheImage(
            ResizeImage(AssetImage(path), width: width),
            context,
          );
        }
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String path) async {
    expect(tester.takeException(), isNull);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile(path));
  }

  testWidgets('inline selected catalogue and compact large text', (
    tester,
  ) async {
    final draft = RoutineDraftController();
    addTearDown(draft.dispose);
    await mount(tester, TemplateExercisePickerScreen(draftController: draft));
    await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('expand:back_squat')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await capture(tester, 'routine_inline_visual.png');
    await mount(
      tester,
      TemplateExercisePickerScreen(draftController: draft),
      size: const Size(320, 844),
      scale: 2,
    );
    final scroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('expand:back_squat')),
      150,
      scrollable: scroll,
    );
    await tester.tap(find.byKey(const ValueKey('expand:back_squat')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await capture(tester, 'routine_inline_accessible.png');
    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText == 'Series' ||
                widget.decoration?.hintText == 'Series'),
      ),
      150,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    await capture(tester, 'routine_inline_accessible_controls.png');
  });

  testWidgets('visual multi-select equipment including carried movement', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<Set<String>>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const RoutineFilterSheet(
                  title: 'Equipamiento',
                  options: [
                    'barbell',
                    'dumbbell',
                    'cable',
                    'kettlebell',
                    'machine',
                    'medicine_ball',
                    'rope',
                    'sled',
                    'carry',
                  ],
                  initialSelection: {'dumbbell', 'medicine_ball'},
                ),
              ),
              child: const Text('Filtros'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await capture(tester, 'routine_equipment_filters.png');
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await capture(tester, 'routine_equipment_patterns.png');
  });

  testWidgets('anatomical muscle options and separate objectives', (
    tester,
  ) async {
    await mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<Set<String>>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const RoutineFilterSheet(
                  title: 'Músculos',
                  muscle: true,
                  options: [
                    'pecho',
                    'hombros',
                    'bíceps',
                    'tríceps',
                    'cuádriceps',
                    'glúteos',
                    'cardio',
                    'estabilidad',
                    'movilidad',
                  ],
                  initialSelection: {'pecho', 'bíceps'},
                ),
              ),
              child: const Text('Filtros'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Filtros'));
    await tester.pumpAndSettle();
    await capture(tester, 'routine_muscle_filters.png');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await capture(tester, 'routine_muscle_objectives.png');
  });

  testWidgets(
    'technical page reuses exercise art and existing catalogue notes',
    (tester) async {
      final d = exerciseLibrary.firstWhere((e) => e.id == 'bench_press');
      await mount(
        tester,
        ExerciseTechnicalScreen(
          exercise: RoutineLabels.defaults(d),
          definition: d,
        ),
      );
      await capture(tester, 'routine_technical_visual.png');
    },
  );

  testWidgets('illustration system legible enlarged with unknown fallbacks', (
    tester,
  ) async {
    final groups = [
      'pecho',
      'espalda',
      'hombros',
      'bíceps',
      'tríceps',
      'core',
      'cuádriceps',
      'isquiosurales',
      'glúteos',
      'pantorrilla',
      'cardio',
      'movilidad',
    ];
    final equipment = [
      'barbell',
      'dumbbell',
      'cable',
      'kettlebell',
      'machine',
      'medicine_ball',
      'rope',
      'sled',
      'band',
      'bench',
      'bodyweight',
      'unknown',
    ];
    await mount(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final (isMuscle, values) in [
                (true, groups),
                (false, equipment),
              ])
                for (final value in values)
                  SizedBox(
                    width: 86,
                    child: Column(
                      children: [
                        RoutineFilterArtwork(
                          value: value,
                          muscle: isMuscle,
                          size: 64,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMuscle
                              ? RoutineLabels.muscleName(value)
                              : RoutineLabels.equipmentName(value),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      size: const Size(640, 780),
    );
    await capture(tester, 'routine_filter_artwork.png');
  });
}
