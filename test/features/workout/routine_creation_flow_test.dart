import 'package:fit_app/features/workout/pro/data/exercise_definition.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRoutinesRepository extends RoutinesRepository {
  bool saveCalled = false;

  @override
  Future<WorkoutTemplate> saveRoutine({
    required String name,
    required WorkoutType workoutType,
    required List<WorkoutExercise> exercises,
    String? activityName,
  }) async {
    saveCalled = true;
    return WorkoutTemplate(
      id: 'id',
      name: name,
      type: workoutType,
      exercises: exercises,
      activityName: activityName,
      origin: TemplateOrigin.user,
    );
  }
}

void main() {
  testWidgets('con selección, Listo navega a review y Guardar llama saveRoutine', (tester) async {
    final controller = ExercisePickerController(
      exercises: [
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
        )
      ],
    );
    final repo = FakeRoutinesRepository();
    final draft = RoutineDraftController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TemplateExercisePickerScreen(
                    controller: controller,
                    repository: repo,
                    draftController: draft,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'curl');
    await tester.pump(const Duration(milliseconds: 260));
    await tester.tap(find.text('Curl clásico'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva rutina'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Upper A');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.saveCalled, isTrue);
    expect(find.text('Nueva rutina'), findsNothing);
  });
}
