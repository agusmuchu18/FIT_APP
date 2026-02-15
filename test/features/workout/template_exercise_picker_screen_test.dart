import 'package:fit_app/features/workout/pro/data/exercise_definition.dart';
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

  testWidgets('estado inicial muestra empty state y no lista completa', (tester) async {
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

    expect(find.text('Todos los ejercicios'), findsNothing);
    expect(find.text('Buscá un ejercicio o músculo'), findsOneWidget);
    expect(find.byType(ExerciseExpandableCard), findsNothing);
  });

  testWidgets('al agregar un ejercicio aparece mini-bar con Ver (N) y sin snackbar agregado', (tester) async {
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
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('agregado'), findsNothing);
    expect(find.text('Ver (1)'), findsOneWidget);
    expect(find.byType(Chip), findsAtLeastNWidgets(1));
  });
}
