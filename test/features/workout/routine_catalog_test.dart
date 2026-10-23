import 'dart:io';

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/domain/routine_catalog.dart';
import 'package:fit_app/features/workout/domain/routine_plan_validation.dart';
import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/training_home/catalog_routine_detail_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_draft_controller.dart';
import 'package:fit_app/features/workout/training_home/routine_review_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_search_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingCatalogRepository extends RoutinesRepository {
  bool fail = true;
  @override
  Future<List<WorkoutTemplate>> getAllRoutines() async {
    if (fail) throw StateError('Local read failure');
    return [];
  }
}

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 20 && target.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
  }

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: child));
    await tester.pumpAndSettle();
  }

  test('12 distinct editorial plans, four per level, use real valid exercises and local covers', () {
    expect(RoutineCatalog.routines.length, 12);
    expect(RoutineCatalog.routines.map((r) => r.id).toSet().length, 12);
    expect(RoutineCatalog.routines.map((r) => r.imageAsset).toSet().length, 12);
    for (final level in RoutineLevel.values) {
      expect(RoutineCatalog.routines.where((r) => r.level == level).length, 4);
    }
    for (final routine in RoutineCatalog.routines) {
      expect(File(routine.imageAsset).existsSync(), isTrue);
      expect(routine.exerciseIds.toSet().length, routine.exerciseIds.length);
      expect(routine.plan.length, routine.exerciseIds.length);
      for (final e in routine.plan) {
        expect(exerciseLibrary.any((d) => d.id == e.id), isTrue);
        expect(
          RoutinePlanValidation.error(e),
          isNull,
          reason: '${routine.id}: ${e.name}',
        );
        expect(e.targetWeightKg, isNull);
        expect(e.sets, isEmpty);
        expect(e.restEnabled, isTrue);
        if (e.isTimed) expect(e.targetDurationSeconds, greaterThan(0));
      }
    }
  });
  test('search combines accents, exercise/equipment terms and level', () {
    expect(RoutineCatalog.search('').length, 12);
    expect(RoutineCatalog.search('', level: RoutineLevel.basic).length, 4);
    expect(RoutineCatalog.search('tríceps').any((r) => r.id == 'push'), isTrue);
    expect(
      RoutineCatalog.search(
        'MÁQUINA',
        level: RoutineLevel.basic,
      ).map((r) => r.id),
      contains('gym_start'),
    );
    expect(
      RoutineCatalog.search('sentadilla', level: RoutineLevel.advanced).length,
      2,
    );
    expect(RoutineCatalog.search('no-existe'), isEmpty);
  });
  testWidgets(
    'first visit is populated without saving anything or opening the keyboard',
    (tester) async {
      await mount(tester, const WorkoutRoutineSearchScreen());
      expect(find.text('Primeros pasos en el gym'), findsOneWidget);
      expect(find.byType(CatalogRoutineCover), findsWidgets);
      expect(
        FocusManager.instance.primaryFocus?.hasFocus == true &&
            FocusManager.instance.primaryFocus?.context?.widget is EditableText,
        isFalse,
      );
      expect(await RoutinesRepository().getAllRoutines(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('level filter and empty search can be reset', (tester) async {
    await mount(tester, const WorkoutRoutineSearchScreen());
    await tester.tap(find.widgetWithText(ChoiceChip, 'Avanzado'));
    await tester.pumpAndSettle();
    expect(find.text('Torso: volumen y control'), findsOneWidget);
    expect(find.text('Primeros pasos en el gym'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no-existe');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restablecer búsqueda'));
    await tester.tap(find.text('Restablecer búsqueda'));
    await tester.pumpAndSettle();
    expect(find.text('Primeros pasos en el gym'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'detail is read-only, double tap opens one editor and saving preserves targets and the ordinary draft',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        RoutineDraftController.storageKey,
        'unfinished-user-draft',
      );
      final routine = RoutineCatalog.routines.first;
      final repo = RoutinesRepository();
      await mount(tester, const WorkoutRoutineSearchScreen());
      await reveal(tester, find.text(routine.name));
      await tester.tap(find.text(routine.name));
      await tester.tap(find.text(routine.name), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byType(CatalogRoutineDetailScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(await repo.getAllRoutines(), isEmpty);
      await tester.tap(find.text('Personalizar y guardar'));
      await tester.tap(
        find.text('Personalizar y guardar'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(RoutineReviewScreen), findsOneWidget);
      final draft = tester
          .widget<RoutineReviewScreen>(find.byType(RoutineReviewScreen))
          .draftController;
      expect(draft.items.first.targetSets, 2);
      expect(draft.items.last.targetDurationSeconds, 20);
      await tester.tap(find.text('Guardar rutina'));
      await tester.pumpAndSettle();
      final saved = (await repo.getAllRoutines()).single;
      expect(saved.id, isNot(routine.template().id));
      expect(saved.origin, TemplateOrigin.user);
      expect(saved.exercises.first.targetSets, 2);
      expect(saved.exercises.first.targetRepsMin, 10);
      expect(saved.exercises.last.targetDurationSeconds, 20);
      expect(
        saved.exercises.every(
          (e) => e.sets.isEmpty && e.targetWeightKg == null,
        ),
        isTrue,
      );
      expect(
        saved.exercises.map((e) => e.instanceId).toSet().length,
        saved.exercises.length,
      );
      expect(
        prefs.getString(RoutineDraftController.storageKey),
        'unfinished-user-draft',
      );
      expect(find.text('Mis rutinas'), findsOneWidget);
      AccountStorageScope.current = 'different-account';
      expect(await RoutinesRepository().getAllRoutines(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('canceling a detail never inserts a routine', (tester) async {
    await mount(tester, const WorkoutRoutineSearchScreen());
    await reveal(tester, find.text(RoutineCatalog.routines.first.name));
    await tester.tap(find.text(RoutineCatalog.routines.first.name));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await RoutinesRepository().getAllRoutines(), isEmpty);
  });
  testWidgets(
    'a saved-library failure is recoverable and does not block the bundled catalog',
    (tester) async {
      final repo = FailingCatalogRepository();
      await mount(tester, WorkoutRoutineSearchScreen(repository: repo));
      expect(find.text('Primeros pasos en el gym'), findsOneWidget);
      await tester.tap(find.text('Mis rutinas'));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      repo.fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Explorar rutinas'), findsOneWidget);
      await tester.tap(find.text('Explorar rutinas'));
      await tester.pumpAndSettle();
      expect(find.text('Primeros pasos en el gym'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
