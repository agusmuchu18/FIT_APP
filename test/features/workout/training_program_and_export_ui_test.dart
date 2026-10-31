import 'dart:typed_data';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/data/training_library_repository.dart';
import 'package:fit_app/features/workout/domain/training_export.dart';
import 'package:fit_app/features/workout/domain/training_program.dart';
import 'package:fit_app/features/workout/domain/training_examples.dart';
import 'package:fit_app/features/workout/domain/routine_plan_validation.dart';
import 'package:fit_app/features/workout/presentation/training_export_screen.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/training_programs_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_examples_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'training_test_fixtures.dart';

class ProgramLibraryFixture extends TrainingLibraryRepository {
  final values = <TrainingProgram>[];
  @override
  Future<List<TrainingProgram>> programs() async => List.of(values);
  @override
  Future<void> saveProgram(TrainingProgram program) async {
    if (program.validationError case final error?) throw ArgumentError(error);
    values.removeWhere((p) => p.id == program.id);
    values.add(program);
  }

  @override
  Future<void> deleteProgram(String id) async =>
      values.removeWhere((p) => p.id == id);
}

class RoutineLibraryFixture extends RoutinesRepository {
  RoutineLibraryFixture(this.values);
  final List<WorkoutTemplate> values;
  @override
  Future<List<WorkoutTemplate>> getAllRoutines() async => values;
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.workout, home: child));
    await tester.pumpAndSettle();
  }

  Finder scrolling(WidgetTester tester) => find
      .descendant(
        of: find.byType(ListView).hitTestable().last,
        matching: find.byType(Scrollable),
      )
      .first;
  testWidgets(
    'program editor adds an explicit rest, duplicates weeks and persists real routine IDs',
    (tester) async {
      final library = ProgramLibraryFixture()
        ..values.add(
          const TrainingProgram(
            id: 'p',
            name: 'Programa original',
            weeks: 1,
            days: [ProgramDay(id: 'd', week: 0, weekday: 1, routineId: 'r')],
          ),
        );
      final routine = WorkoutTemplate(
        id: 'r',
        name: 'Mi rutina',
        type: WorkoutType.strength,
        exercises: [trainingFixtureExercise()],
      );
      await mount(
        tester,
        TrainingProgramsScreen(
          library: library,
          repository: TrainingFixtureRepository([]),
          routinesRepository: RoutineLibraryFixture([routine]),
        ),
      );
      await tester.tap(find.text('Programa original'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre'),
        'Programa editado',
      );
      await tester.scrollUntilVisible(
        find.text('Agregar día'),
        400,
        scrollable: scrolling(tester),
      );
      await tester.tap(find.text('Agregar día'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Miércoles').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Descanso planificado'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar día'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Duplicar semana'),
        200,
        scrollable: scrolling(tester),
      );
      await tester.ensureVisible(find.text('Duplicar semana').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicar semana').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar programa'));
      await tester.pumpAndSettle();
      expect(library.values.single.name, 'Programa editado');
      expect(library.values.single.weeks, 2);
      expect(library.values.single.days.where((d) => d.rest).length, 2);
      expect(library.values.single.days.map((d) => d.id).toSet().length, 4);
      expect(
        library.values.single.days
            .where((d) => !d.rest)
            .map((d) => d.routineId),
        everyElement('r'),
      );
      expect(routine.name, 'Mi rutina');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'example review saves a user copy and leaves the existing creator draft untouched',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        RoutineDraftController.storageKey,
        'existing-user-draft',
      );
      await mount(tester, const RoutineExamplesScreen());
      await tester.tap(find.text(TrainingExamples.routines.first.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar rutina'));
      await tester.pumpAndSettle();
      final saved = (await RoutinesRepository().getAllRoutines()).single;
      expect(saved.name, TrainingExamples.routines.first.name);
      expect(saved.origin, TemplateOrigin.user);
      expect(
        saved.exercises.every(
          (e) => e.sets.isEmpty && e.targetWeightKg == null,
        ),
        isTrue,
      );
      expect(
        prefs.getString(RoutineDraftController.storageKey),
        'existing-user-draft',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'export previews only selected fields, excludes private notes and creates a real PNG',
    (tester) async {
      Uint8List? png;
      final shared = Completer<void>();
      await mount(
        tester,
        TrainingExportScreen(
          data: const TrainingExportData(
            kind: 'ENTRENAMIENTO',
            sections: [
              TrainingExportSection('metrics', 'Resultados', [
                '8 series registradas',
              ]),
              TrainingExportSection('notes', 'Notas privadas', [
                'SECRETO PERSONAL',
              ], private: true),
            ],
          ),
          sharer: (bytes, origin) async {
            png = bytes;
            shared.complete();
            expect(origin.width, greaterThan(0));
            return const ShareResult('', ShareResultStatus.dismissed);
          },
        ),
      );
      expect(find.text('SECRETO PERSONAL'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Crear imagen y compartir'),
        300,
        scrollable: scrolling(tester),
      );
      await tester.tap(find.text('Crear imagen y compartir'));
      await tester.pump();
      final captureDeadline = Stopwatch()..start();
      while (!shared.isCompleted &&
          captureDeadline.elapsed < const Duration(seconds: 15)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        shared.isCompleted,
        isTrue,
        reason: 'La captura PNG debe completar el callback de compartir.',
      );
      await tester.pumpAndSettle();
      expect(png, isNotNull);
      expect(png!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png!);
        try {
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 1080);
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      });
      expect(find.text('SECRETO PERSONAL'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('examples use valid catalogue goals and program structure never mutates routines', () {
    for (final example in TrainingExamples.routines) {
      expect(
        example.plan.map(RoutinePlanValidation.error),
        everyElement(isNull),
      );
      expect(example.equipment, isNotEmpty);
      final routine = WorkoutTemplate(
        id: 'r',
        name: 'Elegida',
        type: WorkoutType.strength,
        exercises: example.plan,
      );
      for (final count in [3, 4]) {
        final program = TrainingExamples.programStructure(
          routine,
          daysPerWeek: count,
        );
        expect(program.validationError, isNull);
        expect(program.days.where((d) => !d.rest).length, count * 4);
        expect(program.days.map((d) => d.id).toSet().length, 28);
        expect(routine.exercises.every((e) => e.sets.isEmpty), isTrue);
      }
    }
  });
}
