import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/domain/sport_activity.dart';
import 'package:fit_app/features/workout/presentation/widgets/routine_filter_artwork.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/training_home/exercise_configuration_sheet.dart';
import 'package:fit_app/features/workout/training_home/exercise_technical_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routine_filter_sheet.dart';
import 'package:fit_app/features/workout/training_home/routine_review_screen.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:fit_app/features/workout/training_home/template_workout_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Finder expand(String id) => find.byKey(ValueKey('expand:$id'));
  Finder detail(String id) => find.byKey(ValueKey('details:$id'));
  Finder field(String label) => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            widget.decoration?.hintText == label),
  );
  Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    double delta = 200,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final scroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(target, delta, scrollable: scroll);
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester,
    RoutineDraftController draft, {
    ExercisePickerController? controller,
    Size size = const Size(390, 844),
    double scale = 1,
    bool reducedMotion = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.workout,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: TemplateExercisePickerScreen(
          draftController: draft,
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RoutineDraftController draft() {
    final value = RoutineDraftController();
    addTearDown(value.dispose);
    return value;
  }

  testWidgets(
    'inline opens and closes without a modal and preserves temporary values',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(ExerciseConfigurationSheet), findsOneWidget);
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '5');
      await reveal(tester, expand('back_squat'), delta: -200);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseConfigurationSheet), findsNothing);
      expect(d.items, isEmpty);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      expect(tester.widget<TextField>(field('Series')).controller!.text, '5');
    },
  );

  testWidgets(
    'only one row is open and switching rows retains each edited configuration',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '4');
      await reveal(tester, expand('bench_press'));
      await tester.tap(expand('bench_press'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseConfigurationSheet), findsOneWidget);
      expect(
        tester
            .widget<ExerciseConfigurationSheet>(
              find.byType(ExerciseConfigurationSheet),
            )
            .exercise
            .id,
        'bench_press',
      );
      await reveal(tester, field('Series'), delta: -200);
      await tester.enterText(field('Series'), '6');
      await reveal(tester, expand('back_squat'), delta: -200);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      expect(tester.widget<TextField>(field('Series')).controller!.text, '4');
      await reveal(
        tester,
        find.byTooltip('Agregar Sentadilla trasera'),
        delta: -200,
      );
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      expect(d.items.single.targetSets, 4);
      expect(find.byType(ExerciseConfigurationSheet), findsOneWidget);
    },
  );

  testWidgets(
    'plus is independent, double tap cannot duplicate, valid changes persist into review',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '5');
      await reveal(
        tester,
        find.byTooltip('Agregar Sentadilla trasera'),
        delta: -200,
      );
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      expect(d.selectedCount, 1);
      final checked = tester.widget<IconButton>(
        find
            .ancestor(
              of: find.byTooltip('Sentadilla trasera seleccionado'),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(checked.onPressed, isNull);
      expect(find.byType(ExerciseConfigurationSheet), findsOneWidget);
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '7');
      await tester.pumpAndSettle();
      expect(d.items.single.targetSets, 7);
      expect(d.items.single.isTimed, isFalse);
      await d.flush();
      final restored = RoutineDraftController();
      await restored.restore();
      expect(restored.items.single.targetSets, 7);
      restored.dispose();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineReviewScreen), findsOneWidget);
      expect(d.items.single.targetSets, 7);
    },
  );

  testWidgets(
    'name opens technical page; back preserves query, filters, scroll, selection and edits',
    (tester) async {
      final d = draft();
      final c = ExercisePickerController(exercises: exerciseLibrary);
      addTearDown(c.dispose);
      c.setQuery('sentadilla');
      c.setEquipmentFilters({'barbell'});
      await mount(tester, d, controller: c);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '4');
      await reveal(tester, detail('back_squat'), delta: -200);
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      final before = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .offset;
      await tester.tap(detail('back_squat'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseTechnicalScreen), findsOneWidget);
      expect(find.text('Ficha del ejercicio'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(c.query, 'sentadilla');
      expect(c.equipmentFilters, {'barbell'});
      expect(d.items.single.targetSets, 4);
      expect(c.expandedExerciseId, 'back_squat');
      expect(
        tester
            .widget<CustomScrollView>(find.byType(CustomScrollView))
            .controller!
            .offset,
        closeTo(before, .1),
      );
    },
  );

  testWidgets(
    'invalid values survive collapse, block add and never overwrite selected valid goals',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '0');
      await tester.pumpAndSettle();
      expect(d.items.single.targetSets, 3);
      await reveal(tester, expand('back_squat'), delta: -200);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineReviewScreen), findsNothing);
      await reveal(tester, field('Series'));
      expect(tester.widget<TextField>(field('Series')).controller!.text, '0');
      await tester.enterText(field('Series'), '4');
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineReviewScreen), findsOneWidget);
      expect(d.items.single.targetSets, 4);
    },
  );

  testWidgets(
    'invalid unselected configuration does not silently add defaults',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), 'bad');
      await reveal(
        tester,
        find.byTooltip('Agregar Sentadilla trasera'),
        delta: -200,
      );
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      expect(d.items, isEmpty);
    },
  );

  testWidgets(
    'filters apply multiple original keys and clear without changing catalogue IDs',
    (tester) async {
      final d = draft();
      final c = ExercisePickerController(exercises: exerciseLibrary);
      addTearDown(c.dispose);
      await mount(tester, d, controller: c);
      await tester.tap(find.text('Equipamiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter:barbell')));
      await tester.tap(find.byKey(const ValueKey('filter:bodyweight')));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(c.equipmentFilters, {'barbell', 'bodyweight'});
      expect(
        c.itemsVisible.every(
          (e) => {'barbell', 'bodyweight'}.contains(e.equipment),
        ),
        isTrue,
      );
      await tester.tap(find.text('Equipamiento · 2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('filter:barbell')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.text('Limpiar'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(c.equipmentFilters, isEmpty);
      expect(c.totalCount, 297);
    },
  );

  testWidgets(
    'filter actions remain reachable at 320 and 200 percent and cancel preserves filters',
    (tester) async {
      final d = draft();
      final c = ExercisePickerController(exercises: exerciseLibrary);
      addTearDown(c.dispose);
      await mount(
        tester,
        d,
        controller: c,
        size: const Size(320, 844),
        scale: 2,
      );
      await tester.tap(find.text('Equipamiento'));
      await tester.pumpAndSettle();
      final option = find.byKey(const ValueKey('filter:barbell'));
      expect(tester.getSize(option).height, greaterThanOrEqualTo(48));
      await tester.tap(option);
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.equipmentFilters, {'barbell'});
      await tester.tap(find.text('Equipamiento · 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar'));
      Navigator.of(tester.element(find.byType(RoutineFilterSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Equipamiento · 1'), findsOneWidget);
      expect(c.equipmentFilters, {'barbell'});
    },
  );

  testWidgets(
    'muscles and objectives use separate visual sections and keep multi-selection',
    (tester) async {
      Set<String>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<Set<String>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const RoutineFilterSheet(
                      title: 'Músculos',
                      options: [
                        'pecho',
                        'core',
                        'cardio',
                        'estabilidad',
                        'cuerpo completo',
                      ],
                      initialSelection: {},
                      muscle: true,
                    ),
                  );
                },
                child: const Text('Filtros'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Grupos musculares'), findsOneWidget);
      expect(find.text('Categorías y objetivos'), findsOneWidget);
      expect(find.text('Zona media'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('filter:pecho')));
      await tester.tap(find.byKey(const ValueKey('filter:cardio')));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(result, {'pecho', 'cardio'});
    },
  );

  test('equipment and muscle names cover raw values without reclassifying persisted carry', () {
    expect(RoutineLabels.equipmentName('medicine_ball'), 'Balón medicinal');
    expect(RoutineLabels.equipmentName('rope'), 'Cuerda');
    expect(RoutineLabels.equipmentName('sled'), 'Trineo de entrenamiento');
    expect(RoutineLabels.equipmentName('carry'), 'Transporte con carga');
    expect(RoutineLabels.muscleName('core'), 'Zona media');
    expect(exerciseLibrary.where((e) => e.equipment == 'carry'), isNotEmpty);
    expect(
      exerciseLibrary.every(
        (e) => RoutineLabels.equipment.containsKey(e.equipment),
      ),
      isTrue,
    );
    final search = ExercisePickerController(exercises: exerciseLibrary)
      ..setQuery('zona media');
    expect(search.totalCount, greaterThan(0));
    expect(
      search.itemsVisible.every(
        (e) => [...e.primaryMuscles, ...e.secondaryMuscles].contains('core'),
      ),
      isTrue,
    );
    search.dispose();
  });

  testWidgets(
    'vector filter art has a consistent fallback without asset loading',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final value in [
                  'medicine_ball',
                  'rope',
                  'sled',
                  'unknown',
                ])
                  RoutineFilterArtwork(value: value, muscle: false),
                for (final value in ['pecho', 'glúteos', 'cardio', 'unknown'])
                  RoutineFilterArtwork(value: value, muscle: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoutineFilterArtwork), findsNWidgets(8));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard leaves the bottom configuration reachable above selection bar',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final rest = find.widgetWithText(
        SwitchListTile,
        'Heredar descanso de la sesión',
      );
      await reveal(tester, rest, delta: 150);
      expect(
        tester.getRect(rest).bottom,
        lessThan(tester.getRect(find.text('Ver (1)')).top),
      );
      expect(tester.getRect(find.text('Ver (1)')).bottom, lessThan(544));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected expanded screen reflows at 320 and 200 percent with accessible expansion',
    (tester) async {
      final handle = tester.ensureSemantics();
      final d = draft();
      await mount(tester, d, size: const Size(320, 844), scale: 2);
      await reveal(tester, expand('back_squat'));
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      await reveal(tester, expand('back_squat'), delta: -200);
      expect(
        find.bySemanticsLabel('Configurar Sentadilla trasera'),
        findsOneWidget,
      );
      expect(
        tester.getSize(expand('back_squat')).width,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      expect(
        find.bySemanticsLabel('Contraer Sentadilla trasera'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets(
    'long lazy list retains configured selected value after scrolling out and back',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      expect(find.byType(ExerciseBrowserCard).evaluate().length, lessThan(10));
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Series'));
      await tester.enterText(field('Series'), '6');
      await reveal(tester, find.text('Mostrar más'), delta: 500);
      await tester.tap(find.text('Mostrar más'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseBrowserCard).evaluate().length, lessThan(15));
      await reveal(tester, expand('back_squat'), delta: -800);
      await reveal(tester, field('Series'));
      expect(tester.widget<TextField>(field('Series')).controller!.text, '6');
    },
  );

  testWidgets(
    'switching expanded rows keeps the tapped header in view during motion',
    (tester) async {
      final d = draft();
      await mount(tester, d, reducedMotion: false);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      final animation = tester.widget<AnimatedSize>(
        find.descendant(
          of: find.byKey(const ValueKey('browser:back_squat')),
          matching: find.byType(AnimatedSize),
        ),
      );
      expect(animation.duration, const Duration(milliseconds: 200));
      await reveal(tester, expand('bench_press'));
      final before = tester.getTopLeft(expand('bench_press')).dy;
      await tester.tap(expand('bench_press'));
      await tester.pumpAndSettle();
      expect(expand('bench_press'), findsOneWidget);
      expect(tester.getTopLeft(expand('bench_press')).dy, closeTo(before, 1));
      expect(find.byType(ExerciseConfigurationSheet), findsOneWidget);
    },
  );

  testWidgets(
    'advanced per-set ranges and weight survive collapse and reach review',
    (tester) async {
      final d = draft();
      await mount(tester, d);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Opciones avanzadas'));
      await tester.tap(find.text('Opciones avanzadas'));
      await tester.pumpAndSettle();
      await reveal(
        tester,
        find.widgetWithText(SwitchListTile, 'Objetivos por serie'),
      );
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Objetivos por serie'),
      );
      await tester.pumpAndSettle();
      await reveal(tester, field('Repeticiones mínimas · serie 1'));
      await tester.enterText(field('Repeticiones mínimas · serie 1'), '6');
      await reveal(tester, field('Carga externa (kg) · serie 1'));
      await tester.enterText(field('Carga externa (kg) · serie 1'), '25,5');
      await reveal(tester, expand('back_squat'), delta: -300);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Agregar Sentadilla trasera'));
      await tester.pumpAndSettle();
      expect(d.items.single.setTargets.first.repsMin, 6);
      expect(d.items.single.setTargets.first.repsMax, 12);
      expect(d.items.single.setTargets.first.weightKg, 25.5);
      await tester.tap(expand('back_squat'));
      await tester.pumpAndSettle();
      await reveal(tester, field('Carga externa (kg) · serie 1'));
      expect(
        tester
            .widget<TextField>(field('Carga externa (kg) · serie 1'))
            .controller!
            .text,
        '25,5',
      );
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(RoutineReviewScreen), findsOneWidget);
      expect(d.items.single.setTargets.first.weightKg, 25.5);
    },
  );

  test('filter selected text and primary add glyph maintain contrast', () {
    final colors = AppTheme.workout.colorScheme;
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    expect(
      contrast(
        colors.primary,
        Color.alphaBlend(colors.primary.withValues(alpha: .10), colors.surface),
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(colors.onPrimary, colors.primary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(colors.onSurface, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
    'football raw invalid targets survive remount and valid changes reach draft',
    (tester) async {
      final d = draft()
        ..setMode(TemplateWorkoutType.sport, FootballMode.technical);
      await mount(tester, d);
      final activity = footballActivities.firstWhere(
        (a) => a.mode == FootballMode.technical,
      );
      await tester.tap(expand(activity.id));
      await tester.pumpAndSettle();
      await reveal(tester, field('Duración del bloque (s)'));
      await tester.enterText(field('Duración del bloque (s)'), 'bad');
      await reveal(tester, expand(activity.id), delta: -200);
      await tester.tap(expand(activity.id));
      await tester.pumpAndSettle();
      await tester.tap(expand(activity.id));
      await tester.pumpAndSettle();
      await reveal(tester, field('Duración del bloque (s)'));
      expect(
        tester
            .widget<TextField>(field('Duración del bloque (s)'))
            .controller!
            .text,
        'bad',
      );
      await tester.enterText(field('Duración del bloque (s)'), '120');
      await reveal(
        tester,
        find.byTooltip('Agregar ${activity.name}'),
        delta: -200,
      );
      await tester.tap(find.byTooltip('Agregar ${activity.name}'));
      await tester.pumpAndSettle();
      expect(
        d.items.single.sportPlan!.targets.values[SportMetric.durationSeconds],
        120,
      );
      expect(d.items.single.sportResult, isNull);
    },
  );
}
