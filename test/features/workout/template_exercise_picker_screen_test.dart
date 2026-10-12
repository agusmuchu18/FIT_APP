import 'package:fit_app/features/workout/pro/data/exercise_definition.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ExerciseDefinition> buildExercises() => [
    ExerciseDefinition(
      id: 'curl_biceps',
      name: 'Curl clásico',
      aliases: const ['biceps curl'],
      primaryMuscles: const ['bíceps'],
      secondaryMuscles: const ['antebrazo'],
      equipment: 'dumbbell',
      movementPattern: 'pull',
      defaultMeasurement: 'reps',
      loadType: LoadType.external,
    ),
  ];

  test('muestra ejercicios variados al abrir y aplica filtros luego', () {
    final controller = ExercisePickerController(exercises: exerciseLibrary);

    expect(controller.totalCount, exerciseLibrary.length);
    expect(controller.itemsVisible.take(6).map((exercise) => exercise.id), [
      'back_squat',
      'bench_press',
      'lat_pulldown',
      'deadlift',
      'military_press',
      'plank',
    ]);

    controller.setEquipmentFilters({'bodyweight'});
    expect(controller.itemsVisible, isNotEmpty);
    expect(
      controller.itemsVisible.every(
        (exercise) => exercise.equipment == 'bodyweight',
      ),
      isTrue,
    );
    controller.dispose();
  });

  testWidgets(
    'estado inicial muestra biblioteca y permite agregar sin filtros',
    (tester) async {
      final controller = ExercisePickerController(
        exercises: buildExercises(),
        initialRecentExerciseIds: const ['curl_biceps'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: TemplateExercisePickerScreen(controller: controller),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Explorá ejercicios'), findsOneWidget);
      expect(find.text('Curl clásico'), findsOneWidget);
      expect(find.byType(ExerciseExpandableCard), findsOneWidget);

      await tester.tap(find.byTooltip('Agregar Curl clásico'));
      await tester.pumpAndSettle();
      expect(find.text('Ver (1)'), findsOneWidget);
    },
  );

  testWidgets(
    'al agregar un ejercicio aparece mini-bar con Ver (N) y sin snackbar agregado',
    (tester) async {
      final controller = ExercisePickerController(exercises: buildExercises());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: TemplateExercisePickerScreen(controller: controller),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'curl');
      await tester.pump(const Duration(milliseconds: 260));

      await tester.tap(find.text('Curl clásico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('agregado'), findsNothing);
      expect(find.text('Ver (1)'), findsOneWidget);
      expect(find.byType(Chip), findsAtLeastNWidgets(1));
    },
  );

  testWidgets('biblioteca inicial funciona a 320 px con texto al 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ExercisePickerController(exercises: buildExercises());

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TemplateExercisePickerScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explorá ejercicios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
