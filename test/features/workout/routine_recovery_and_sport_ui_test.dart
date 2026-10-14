import 'dart:async';
import 'dart:convert';

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/application/workout_session_controller.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';
import 'package:fit_app/features/workout/domain/routine_plan_validation.dart';
import 'package:fit_app/features/workout/domain/sport_activity.dart';
import 'package:fit_app/features/workout/presentation/widgets/sport_session_card.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/pro/providers/workout_pro_provider.dart';
import 'package:fit_app/features/workout/training_home/exercise_configuration_sheet.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routine_library_card.dart';
import 'package:fit_app/features/workout/training_home/routine_review_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/training_home_controller.dart';
import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RetryRepository extends RoutinesRepository {
  final failure = Completer<void>();
  int calls = 0;
  @override
  Future<WorkoutTemplate> saveRoutine({
    required String name,
    required WorkoutType workoutType,
    required List<WorkoutExercise> exercises,
    String? activityName,
    String? folderId,
    String? routineId,
    String? notes,
    FootballMode? footballMode,
  }) async {
    calls++;
    if (calls == 1) await failure.future;
    return super.saveRoutine(
      name: name,
      workoutType: workoutType,
      exercises: exercises,
      activityName: activityName,
      folderId: folderId,
      routineId: routineId,
      notes: notes,
      footballMode: footballMode,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'fast sport selection does not invent a hidden duration goal or result',
    (tester) async {
      final draft = RoutineDraftController();
      addTearDown(draft.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: TemplateExercisePickerScreen(draftController: draft),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deporte'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Agregar ${footballActivities.first.name}'),
      );
      await tester.pumpAndSettle();
      expect(draft.items.single.targetDurationSeconds, isNull);
      expect(draft.items.single.sportPlan!.targets.values, isEmpty);
      expect(draft.items.single.sportResult, isNull);
      await draft.flush();
    },
  );
  testWidgets(
    'review and modal configuration keep their save action above the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final draft = RoutineDraftController()
        ..add(RoutineLabels.defaults(exerciseLibrary.first))
        ..updateHeader(name: 'Teclado');
      addTearDown(draft.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: RoutineReviewScreen(
            draftController: draft,
            exercisesById: {for (final e in exerciseLibrary) e.id: e},
            repository: RoutinesRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Guardar rutina')).bottom,
        lessThanOrEqualTo(544),
      );
      tester.view.resetViewInsets();
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.workout,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showExerciseConfiguration(
                  context,
                  draft.items.single,
                  definition: exerciseLibrary.first,
                ),
                child: const Text('Abrir ficha'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir ficha'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Guardar configuración')).bottom,
        lessThanOrEqualTo(544),
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('legacy continuation copies per-set goals, lastre and rest without changing the template', () async {
    final provider = WorkoutProProvider();
    addTearDown(provider.dispose);
    await provider.initialize();
    final template = WorkoutTemplate(
      id: 'legacy-compatible',
      name: 'Dominadas',
      type: WorkoutType.strength,
      origin: TemplateOrigin.user,
      exercises: [
        WorkoutExercise(
          id: 'pull_up',
          name: 'Dominadas pronas',
          targetSets: 2,
          targetLoadType: RoutineExerciseLoadType.addedWeightKg,
          targetWeightKg: 10,
          restEnabled: false,
          setTargets: [
            const RoutineSetTarget(reps: 6, weightKg: 3),
            const RoutineSetTarget(reps: 8, weightKg: 5),
          ],
        ),
      ],
    );
    provider.selectTemplate(template);
    expect(provider.exercises.single.sets.map((s) => s.externalLoadKg), [3, 5]);
    expect(provider.exercises.single.sets.map((s) => s.reps), [6, 8]);
    expect(
      provider.exercises.single.sets.every((s) => s.done == false),
      isTrue,
    );
    expect(provider.exercises.single.restEnabled, isFalse);
    expect(template.exercises.single.id, 'pull_up');
    expect(template.exercises.single.sets, isEmpty);
    await Future<void>.delayed(Duration.zero);
  });
  test(
    'unreadable draft is retained and cannot be silently replaced',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('workout_routine_draft_v2', '{broken');
      final draft = RoutineDraftController();
      addTearDown(draft.dispose);
      await draft.restore();
      expect(draft.restoreFailed, isTrue);
      expect(() => draft.updateHeader(name: 'replacement'), throwsStateError);
      await expectLater(draft.flush(), throwsStateError);
      expect(prefs.getString('workout_routine_draft_v2'), '{broken');
    },
  );
  test(
    'damaged folders remain readable in part but reject destructive overwrite',
    () async {
      final raw = jsonEncode([
        {'id': 'good', 'name': 'Fuerza', 'sortOrder': 0},
        'broken',
      ]);
      SharedPreferences.setMockInitialValues({'pro_workout_folders': raw});
      final controller = TrainingHomeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.folders.single.name, 'Fuerza');
      await expectLater(controller.createFolder('Nueva'), throwsStateError);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'pro_workout_folders',
        ),
        raw,
      );
    },
  );
  test(
    'folder deletion conserves complete plans, sport metadata and routine IDs',
    () async {
      final controller = TrainingHomeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.createFolder('Fútbol');
      final folder = controller.folders.single.id;
      final routine = await RoutinesRepository().saveRoutine(
        name: 'Potencia',
        workoutType: WorkoutType.sport,
        footballMode: FootballMode.gym,
        folderId: folder,
        notes: 'Notas conservadas',
        exercises: [
          WorkoutExercise(
            id: 'pull_up',
            name: 'Dominadas pronas',
            sportPurpose: FootballGymPurpose.power,
            targetLoadType: RoutineExerciseLoadType.addedWeightKg,
            targetWeightKg: 5,
          ),
        ],
      );
      await controller.renameFolder(folder, 'Plan semanal');
      await controller.deleteFolder(folder);
      final saved = (await RoutinesRepository().getAllRoutines()).single;
      expect(saved.id, routine.id);
      expect(saved.folderId, isNull);
      expect(saved.notes, 'Notas conservadas');
      expect(saved.footballMode, FootballMode.gym);
      expect(saved.exercises.single.sportPurpose, FootballGymPurpose.power);
      expect(saved.exercises.single.targetWeightKg, 5);
    },
  );
  test('plan validation rejects invalid ranges, nonfinite load and mismatched sets', () {
    final base = RoutineLabels.defaults(exerciseLibrary.first);
    expect(RoutinePlanValidation.error(base), isNull);
    for (final e in [
      base.copyWith(targetSets: 0),
      base.copyWith(targetWeightKg: double.nan),
      base.copyWith(targetRepsMin: 12, targetRepsMax: 8),
      base.copyWith(setTargets: [const RoutineSetTarget(reps: 8)]),
    ]) {
      expect(RoutinePlanValidation.error(e), isNotNull);
    }
  });
  testWidgets(
    'failed save keeps the complete draft; duplicate tap and retry save once',
    (tester) async {
      final draft = RoutineDraftController();
      addTearDown(draft.dispose);
      draft.add(
        RoutineLabels.defaults(exerciseLibrary.first)
            .copyWith(restSeconds: 120, targetWeightKg: 42),
      );
      draft.updateHeader(name: 'Plan recuperable', notes: 'Se conserva');
      final id = draft.draftId;
      final repo = RetryRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => RoutineReviewScreen(
                      draftController: draft,
                      exercisesById: {for (final e in exerciseLibrary) e.id: e},
                      repository: repo,
                    ),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar rutina'));
      await tester.tap(find.text('Guardar rutina'));
      await tester.pump();
      expect(repo.calls, 1);
      repo.failure.completeError(StateError('disk unavailable'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tus cambios se conservan'), findsOneWidget);
      expect(draft.items.single.targetWeightKg, 42);
      expect(draft.items.single.restSeconds, 120);
      expect(draft.notes, 'Se conserva');
      await tester.tap(find.text('Guardar rutina'));
      await tester.pumpAndSettle();
      final saved = (await repo.getAllRoutines()).single;
      expect(saved.id, id);
      expect(saved.exercises.single.targetWeightKg, 42);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'workout_routine_draft_v2',
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'individual range targets initialize from general goals and survive later changes',
    (tester) async {
      WorkoutExercise? result;
      final e = RoutineLabels.defaults(exerciseLibrary.first);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showExerciseConfiguration(
                    context,
                    e,
                    definition: exerciseLibrary.first,
                  );
                },
                child: const Text('Configurar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configurar'));
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(ExerciseConfigurationSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      final switcher = find.widgetWithText(
        SwitchListTile,
        'Objetivos por serie',
      );
      await tester.scrollUntilVisible(switcher, 200, scrollable: scroll);
      await tester.tap(switcher);
      await tester.pumpAndSettle();
      final minimum = find.widgetWithText(
        TextField,
        'Repeticiones mínimas · serie 1',
      );
      await tester.scrollUntilVisible(minimum, 150, scrollable: scroll);
      await tester.enterText(minimum, '6');
      await tester.pump();
      final general = find.widgetWithText(TextField, 'Mínimo de repeticiones');
      await tester.scrollUntilVisible(general, -200, scrollable: scroll);
      await tester.enterText(general, '10');
      await tester.tap(find.text('Guardar configuración'));
      await tester.pumpAndSettle();
      expect(result!.targetRepsMin, 10);
      expect(result!.setTargets, hasLength(3));
      expect(result!.setTargets.first.repsMin, 6);
      expect(result!.setTargets.first.repsMax, 12);
      expect(result!.setTargets.last.repsMin, 8);
    },
  );
  testWidgets(
    'football results require real values and invalid edits clear completion',
    (tester) async {
      final routine = await RoutinesRepository().saveRoutine(
        name: 'Velocidad',
        workoutType: WorkoutType.sport,
        footballMode: FootballMode.physical,
        exercises: [
          WorkoutExercise(
            id: 'football_sprint',
            name: 'Sprint de 20 metros',
            targetSets: 1,
            measurement: 'seconds',
            sportPlan: SportActivityPlan(
              activityId: 'football_sprint',
              mode: FootballMode.physical,
              targets: SportMeasurements(
                values: {
                  SportMetric.distanceMeters: 20,
                  SportMetric.repetitions: 6,
                },
              ),
            ),
          ),
        ],
      );
      final controller = WorkoutSessionController(
        repository: WorkoutRepository(),
      );
      addTearDown(controller.dispose);
      await controller.initialize(templateId: routine.id);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final e = controller.exercises.single;
                return SingleChildScrollView(
                  child: SportSessionCard(
                    exercise: e,
                    onChanged: (v) => controller.updateSportResult(e.id, v),
                    onDone: (v) =>
                        controller.updateSet(e.id, e.sets.first.id, done: v),
                    onRest: (_, _) {},
                    onRemove: () {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextField, label);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, value);
        await tester.pump();
      }

      expect(controller.exercises.single.sportResult, isNull);
      await enter('Duración del bloque (s)', '30');
      await enter('Distancia (m)', '20');
      await enter('Repeticiones', '6');
      await tester.ensureVisible(find.text('Actividad completada'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actividad completada'));
      await tester.pump();
      expect(controller.exercises.single.sets.single.done, isTrue);
      await enter('Repeticiones', '-1');
      expect(controller.exercises.single.sets.single.done, isFalse);
      expect(controller.exercises.single.sportResult, isNull);
      expect(find.widgetWithText(TextField, 'Kg'), findsNothing);
      await controller.saveDraft();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'large library builds visible cards instead of the whole collection',
    (tester) async {
      await RoutinesRepository().replaceRoutines(
        List.generate(
          500,
          (i) => WorkoutTemplate(
            id: 'r$i',
            name: 'Rutina $i',
            type: WorkoutType.strength,
            origin: TemplateOrigin.user,
            exercises: [RoutineLabels.defaults(exerciseLibrary.first)],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.workout, home: const TrainingHomeScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoutineLibraryCard).evaluate().length, lessThan(10));
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
