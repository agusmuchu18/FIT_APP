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
        ExerciseDefinition(
          id: 'sentadilla',
          name: 'Sentadilla frontal',
          aliases: const ['front squat'],
          primaryMuscles: const ['cuádriceps'],
          secondaryMuscles: const ['glúteos'],
          equipment: 'barbell',
          movementPattern: 'squat',
          defaultMeasurement: 'reps',
          loadType: LoadType.external,
        ),
        ExerciseDefinition(
          id: 'martillo',
          name: 'Curl martillo',
          aliases: const ['hammer curl'],
          primaryMuscles: const ['bíceps'],
          secondaryMuscles: const [],
          equipment: 'dumbbell',
          movementPattern: 'pull',
          defaultMeasurement: 'reps',
          loadType: LoadType.external,
        ),
        ExerciseDefinition(
          id: 'predicador',
          name: 'Curl predicador',
          aliases: const ['preacher curl'],
          primaryMuscles: const ['bíceps'],
          secondaryMuscles: const [],
          equipment: 'machine',
          movementPattern: 'pull',
          defaultMeasurement: 'reps',
          loadType: LoadType.external,
        ),
      ];

  testWidgets('renderiza recientes con 3 cards large', (tester) async {
    final controller = ExercisePickerController(
      exercises: buildExercises(),
      initialRecentExerciseIds: const ['curl_biceps', 'martillo', 'predicador'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: TemplateExercisePickerScreen(controller: controller),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Usados recientemente'), findsOneWidget);
    expect(find.byType(RecentExerciseCard), findsNWidgets(3));
  });

  testWidgets('search por músculo muestra ejercicios aunque el nombre no coincida', (tester) async {
    final controller = ExercisePickerController(
      exercises: buildExercises(),
      initialRecentExerciseIds: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: TemplateExercisePickerScreen(controller: controller),
      ),
    );

    await tester.enterText(find.byType(TextField), 'bíceps');
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Curl clásico'), findsOneWidget);
    expect(find.text('Curl martillo'), findsOneWidget);
    expect(find.text('Curl predicador'), findsOneWidget);
    expect(find.text('Sentadilla frontal'), findsNothing);
  });
}
