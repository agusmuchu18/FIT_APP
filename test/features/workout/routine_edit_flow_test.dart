import 'package:fit_app/features/workout/training_home/exercise_configuration_sheet.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/routine_edit_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_preview_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/training_home_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({WorkoutTemplate routine, TrainingHomeController controller})>
seedRoutine() async {
  final repository = RoutinesRepository();
  final routine = await repository.saveRoutine(
    name: 'Fuerza A',
    workoutType: WorkoutType.strength,
    exercises: [
      WorkoutExercise(
        id: 'bench_press',
        name: 'Press banca',
        targetSets: 3,
        targetLoadType: RoutineExerciseLoadType.weightedKg,
      ),
    ],
  );
  final controller = TrainingHomeController();
  await controller.initialize();
  return (routine: routine, controller: controller);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('edited targets and order persist and prefill a new session', () async {
    final seeded = await seedRoutine();
    addTearDown(seeded.controller.dispose);
    await seeded.controller.createFolder('Fuerza');
    final folderId = seeded.controller.folders.single.id;
    await seeded.controller.updateRoutine(
      WorkoutTemplate(
        id: seeded.routine.id,
        name: 'Fuerza B',
        type: WorkoutType.functional,
        origin: seeded.routine.origin,
        folderId: folderId,
        exercises: [
          WorkoutExercise(id: 'squat', name: 'Sentadilla', targetSets: 2),
          seeded.routine.exercises.single.copyWith(
            targetSets: 4,
            targetReps: 10,
            targetWeightKg: 55,
            restSeconds: 120,
          ),
        ],
      ),
    );

    final saved = (await RoutinesRepository().getAllRoutines()).single;
    expect(saved.id, seeded.routine.id);
    expect(saved.name, 'Fuerza B');
    expect(saved.type, WorkoutType.functional);
    expect(saved.folderId, folderId);
    expect(saved.exercises.map((e) => e.id), ['squat', 'bench_press']);

    final session = WorkoutSessionController(repository: WorkoutRepository());
    addTearDown(session.dispose);
    await session.initialize(templateId: saved.id);
    expect(session.exercises.map((e) => e.exerciseId), [
      'squat',
      'bench_press',
    ]);
    expect(session.exercises.last.sets, hasLength(4));
    expect(session.exercises.last.sets.first.reps, 10);
    expect(session.exercises.last.sets.first.kg, 55);
    expect(session.exercises.last.restSeconds, 120);
  });

  testWidgets('routine editor saves name and exercise targets', (tester) async {
    final seeded = await seedRoutine();
    addTearDown(seeded.controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RoutineEditScreen(
          routine: seeded.routine,
          controller: seeded.controller,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fuerza renovada');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Press banca'));
    await tester.tap(find.text('Press banca'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Series'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ExerciseConfigurationSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Series'), '4');
    await tester.tap(find.text('Fijas'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Repeticiones objetivo'),
      '10',
    );
    final inherit = find.widgetWithText(
      SwitchListTile,
      'Heredar descanso de la sesión',
    );
    await tester.ensureVisible(inherit);
    await tester.tap(inherit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final saved = (await RoutinesRepository().getAllRoutines()).single;
    expect(saved.name, 'Fuerza renovada');
    expect(saved.exercises.single.targetSets, 4);
    expect(saved.exercises.single.targetReps, 10);
    expect(saved.exercises.single.restSeconds, 90);
  });

  testWidgets('catalog addition and reordering persist', (tester) async {
    final seeded = await seedRoutine();
    addTearDown(seeded.controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RoutineEditScreen(
          routine: seeded.routine,
          controller: seeded.controller,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'pecho en maquina');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('Agregar Press de pecho en máquina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Opciones de Press de pecho en máquina'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opciones de Press de pecho en máquina'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover arriba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final saved = (await RoutinesRepository().getAllRoutines()).single;
    expect(saved.exercises.map((exercise) => exercise.id), [
      'chest_press_machine',
      'bench_press',
    ]);
  });

  testWidgets('invalid targets cannot be applied and blank targets clear', (
    tester,
  ) async {
    final seeded = await seedRoutine();
    addTearDown(seeded.controller.dispose);
    await seeded.controller.updateRoutine(
      WorkoutTemplate(
        id: seeded.routine.id,
        name: seeded.routine.name,
        type: seeded.routine.type,
        origin: seeded.routine.origin,
        exercises: [
          seeded.routine.exercises.single.copyWith(
            targetReps: 10,
            targetWeightKg: 40,
            restSeconds: 90,
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RoutineEditScreen(
          routine: seeded.controller.routines.single,
          controller: seeded.controller,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Press banca'));
    await tester.tap(find.text('Press banca'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Series'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ExerciseConfigurationSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Series'), '0');
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    expect(find.text('Usá un entero entre 1 y 30'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Series'), '3');
    await tester.tap(find.text('Rango'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextField, 'Carga externa objetivo (kg)'),
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Carga externa objetivo (kg)'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ExerciseConfigurationSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Carga externa objetivo (kg)'),
      '',
    );
    final inherit = find.widgetWithText(
      SwitchListTile,
      'Heredar descanso de la sesión',
    );
    await tester.ensureVisible(inherit);
    await tester.tap(inherit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar configuración'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    final saved = (await RoutinesRepository().getAllRoutines()).single;
    expect(saved.exercises.single.targetReps, isNull);
    expect(saved.exercises.single.targetWeightKg, isNull);
    expect(saved.exercises.single.restSeconds, isNull);
  });

  testWidgets(
    'duplicate catalog exercises show independent saved configurations in preview',
    (tester) async {
      final seeded = await seedRoutine();
      addTearDown(seeded.controller.dispose);
      final repeated = WorkoutTemplate(
        id: seeded.routine.id,
        name: seeded.routine.name,
        type: seeded.routine.type,
        origin: seeded.routine.origin,
        exercises: [
          seeded.routine.exercises.single,
          seeded.routine.exercises.single.copyWith(targetSets: 4),
        ],
      );
      await seeded.controller.updateRoutine(repeated);
      await tester.pumpWidget(
        MaterialApp(
          home: RoutinePreviewScreen(
            routine: repeated,
            controller: seeded.controller,
            typeLabel: 'Fuerza',
            lastUsedLabel: 'Nunca',
          ),
        ),
      );

      expect(find.textContaining('3 series ·'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('4 series ·'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('4 series ·'), findsOneWidget);
      expect(find.text('Press banca'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
