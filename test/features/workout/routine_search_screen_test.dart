import 'dart:convert';

import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/routine_search_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final strength = WorkoutTemplate(
    id: 'routine-1',
    name: 'Fuerza superior',
    type: WorkoutType.strength,
    origin: TemplateOrigin.user,
    exercises: [WorkoutExercise(id: 'bench', name: 'Press de pecho')],
  );
  final legs = WorkoutTemplate(
    id: 'routine-2',
    name: 'Piernas',
    type: WorkoutType.strength,
    origin: TemplateOrigin.user,
    exercises: [WorkoutExercise(id: 'squat', name: 'Sentadilla')],
  );

  test('search matches accents, name and exercise terms', () {
    expect(searchWorkoutRoutines([strength, legs], 'fuerza'), [strength]);
    expect(searchWorkoutRoutines([strength, legs], 'pecho'), [strength]);
    expect(searchWorkoutRoutines([strength, legs], 'FUERZA pécho'), [strength]);
    expect(searchWorkoutRoutines([strength, legs], 'biceps'), isEmpty);
  });

  testWidgets('search screen displays real routines and empty results', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      RoutinesRepository.templatesKey: jsonEncode([
        strength.toJson(),
        legs.toJson(),
      ]),
    });

    await tester.pumpWidget(
      const MaterialApp(home: WorkoutRoutineSearchScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mis rutinas'));
    await tester.pumpAndSettle();
    expect(find.text('Fuerza superior'), findsOneWidget);
    expect(find.text('Piernas'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sentadilla');
    await tester.pump();
    expect(find.text('Fuerza superior'), findsNothing);
    expect(find.text('Piernas'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'desconocido');
    await tester.pump();
    expect(
      find.text('No encontramos rutinas con esa búsqueda.'),
      findsOneWidget,
    );
  });
}
