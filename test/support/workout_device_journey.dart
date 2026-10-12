import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/local_storage_service.dart';
import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/presentation/workout_in_progress_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/template_exercise_picker_screen.dart';
import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:fit_app/features/workout/training_home/workout_history_screen.dart';
import 'package:fit_app/features/workout/training_home/workout_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Real local projection; remote sync and authentication are outside this journey.
class LocalJourneyRepository implements FitnessRepository {
  LocalJourneyRepository(this.storage);
  final LocalStorageService storage;
  @override
  final workoutsRevision = ValueNotifier<int>(0);
  @override
  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    await storage.saveWorkout(entry);
    workoutsRevision.value++;
  }

  @override
  Future<List<WorkoutEntry>> getWorkouts() => storage.fetchWorkouts();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> runWorkoutDeviceJourney(
  WidgetTester tester,
  LocalJourneyRepository fitness,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: const TrainingHomeScreen(),
      routes: {
        '/workout/routines/new': (_) => const TemplateExercisePickerScreen(),
        '/workout/session': (_) =>
            WorkoutInProgressScreen(fitnessRepository: fitness),
        '/workout/history': (_) => const WorkoutHistoryScreen(),
        '/workout/settings': (_) => const WorkoutSettingsScreen(),
      },
    ),
  );
  await _ready(tester, find.text('Nueva rutina'));
  await tester.tap(find.text('Nueva rutina'));
  await _ready(tester, find.byTooltip('Agregar Press banca'));
  await tester.tap(find.byTooltip('Agregar Press banca'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Listo'));
  final name = find.widgetWithText(TextField, 'Nombre de la rutina');
  await _ready(tester, name);
  await tester.enterText(name, 'Rutina de verificación');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guardar'));
  await _ready(tester, find.text('Mis rutinas'));
  final routines = await tester.runAsync(
    () => RoutinesRepository().getAllRoutines(),
  );
  expect(routines!.single.name, 'Rutina de verificación');
  await tester.ensureVisible(find.text('Rutina de verificación'));
  await tester.tap(find.text('Rutina de verificación'));
  await _ready(tester, find.text('Iniciar rutina'));
  await tester.tap(find.text('Iniciar rutina'));
  await _ready(tester, find.text('Tu sesión'));
  await _ready(tester, find.text('Press banca').first);
  await tester.tap(find.text('Press banca').first);
  await tester.pumpAndSettle();
  final reps = find.widgetWithText(TextField, 'Reps').first;
  await tester.ensureVisible(reps);
  await tester.pumpAndSettle();
  await tester.enterText(reps, '9');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  // Back must flush the latest keystroke before navigating away.
  await tester.tap(find.byType(BackButton));
  await _ready(tester, find.text('Iniciar rutina'));
  final rich = WorkoutRepository();
  final draft = await tester.runAsync(rich.loadDraftExercises);
  expect(draft!.single.sets.first.reps, 9);
  await tester.tap(find.text('Iniciar rutina'));
  await _ready(tester, find.text('Tu sesión'));
  await tester.tap(find.text('Pausar sesión'));
  await _ready(tester, find.text('Reanudar sesión'));
  expect((await tester.runAsync(rich.loadDraftIdentity))!.isPaused, isTrue);
  await tester.tap(find.text('Reanudar sesión'));
  await tester.tap(find.text('Press banca').first);
  await tester.pumpAndSettle();
  final check = find.byType(Checkbox).first;
  await tester.ensureVisible(check);
  await tester.pumpAndSettle();
  await tester.tap(check);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Más opciones'));
  await _ready(tester, find.text('Finalizar anticipadamente'));
  await tester.tap(find.text('Finalizar anticipadamente'));
  await _ready(tester, find.text('Guardar entrenamiento'));
  await tester.tap(find.text('Guardar entrenamiento'));
  await _ready(tester, find.text('Entrenamiento completado'));
  final sessions = await tester.runAsync(rich.listSessions);
  final projected = await tester.runAsync(fitness.getWorkouts);
  expect(sessions, hasLength(1));
  expect(projected!.single.id, sessions!.single.id);
  expect(await tester.runAsync(rich.loadDraftExercises), isNull);
  await tester.scrollUntilVisible(find.text('Volver al inicio'), 400);
  await tester.tap(find.text('Volver al inicio'));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
  await _ready(tester, find.text('Hoy: sesión registrada'));
  await tester.tap(find.byTooltip('Historial'));
  await _ready(tester, find.text('Actividad semanal'));
  await tester.scrollUntilVisible(
    find.text('Rutina de verificación'),
    400,
    scrollable: find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last,
  );
  await _ready(tester, find.text('Rutina de verificación'));
  expect(tester.takeException(), isNull);
}

Future<void> _ready(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    // Give real disk/plugin completions an event-loop turn in host rehearsals.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(
    finder,
    findsWidgets,
    reason: 'El recorrido no alcanzó su próximo estado',
  );
}
