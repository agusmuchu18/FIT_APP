import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/presentation/widgets/set_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('clearing set fields removes stored values', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = WorkoutSessionController();
    addTearDown(controller.dispose);
    await controller.initialize(
      initialExercises: const [
        ExerciseInSession(
          id: 'instance-1',
          exerciseId: 'bench_press',
          name: 'Press banca',
          sets: [SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8)],
        ),
      ],
    );

    controller.updateSet('instance-1', 'set-1', clearKg: true);
    controller.updateSet('instance-1', 'set-1', clearReps: true);

    final set = controller.exercises.single.sets.single;
    expect(set.kg, isNull);
    expect(set.reps, isNull);
  });

  testWidgets('empty text requests clearing kg and reps', (tester) async {
    bool? kgCleared;
    bool? repsCleared;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetRow(
            set: const SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8),
            onChanged: ({kg, clearKg, reps, clearReps, done}) {
              kgCleared = clearKg ?? kgCleared;
              repsCleared = clearReps ?? repsCleared;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '');
    await tester.enterText(find.byType(TextField).last, '');

    expect(kgCleared, isTrue);
    expect(repsCleared, isTrue);
  });

  testWidgets('editing kg does not rewrite the focused field', (tester) async {
    Widget row(double kg) => MaterialApp(
      home: Scaffold(
        body: SetRow(
          set: SetInSession(id: 'set-1', index: 1, kg: kg, reps: 8),
          onChanged: ({kg, clearKg, reps, clearReps, done}) {},
        ),
      ),
    );

    await tester.pumpWidget(row(50));
    await tester.enterText(find.byType(TextField).first, '5');
    await tester.pumpWidget(row(5));

    final kgField = tester.widget<TextField>(find.byType(TextField).first);
    expect(kgField.controller!.text, '5');
    expect(kgField.controller!.selection.baseOffset, 1);
  });

  testWidgets('comma load parses and invalid numbers clear stored values', (
    tester,
  ) async {
    double? receivedKg;
    bool? receivedClearKg;
    bool? receivedClearReps;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetRow(
            set: const SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8),
            onChanged: ({kg, clearKg, reps, clearReps, done}) {
              receivedKg = kg;
              receivedClearKg = clearKg;
              receivedClearReps = clearReps;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '2,5');
    await tester.pump();
    expect(receivedKg, 2.5);
    expect(find.text('Carga inválida'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '-1');
    await tester.pump();
    expect(find.text('Carga inválida'), findsOneWidget);
    expect(receivedClearKg, isTrue);

    await tester.enterText(find.byType(TextField).last, '0');
    await tester.pump();
    expect(find.text('Repeticiones inválidas'), findsOneWidget);
    expect(receivedClearReps, isTrue);
  });

  testWidgets('a set without repetitions cannot be marked complete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SetRow(
            set: const SetInSession(id: 'set-1', index: 1),
            onChanged: ({kg, clearKg, reps, clearReps, done}) {},
          ),
        ),
      ),
    );

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
  });
}
