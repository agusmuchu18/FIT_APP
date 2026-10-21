import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/data/workout_preferences.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/domain/sport_activity.dart';
import 'package:fit_app/features/workout/domain/training_export.dart';
import 'package:fit_app/features/workout/domain/training_program.dart';
import 'package:fit_app/features/workout/domain/training_units.dart';
import 'package:fit_app/features/workout/domain/workout_analytics.dart';
import 'package:fit_app/features/workout/presentation/widgets/set_row.dart';
import 'package:fit_app/features/workout/presentation/widgets/sport_measurements_fields.dart';
import 'package:fit_app/features/workout/presentation/widgets/workout_units_host.dart';
import 'package:fit_app/features/workout/presentation/workout_insights_screen.dart';
import 'package:fit_app/features/workout/training_home/exercise_configuration_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'training_test_fixtures.dart';

class _CalendarLibrary extends TrainingFixtureLibrary {
  @override
  Future<List<TrainingProgram>> programs() async => [
    TrainingProgram(
      id: 'p',
      name: 'Semana real',
      weeks: 1,
      active: true,
      startDate: DateTime(2026, 10, 12),
      days: const [
        ProgramDay(id: 'train', week: 0, weekday: 1, routineId: 'r'),
        ProgramDay(id: 'rest', week: 0, weekday: 6, rest: true),
      ],
    ),
  ];
}

void main() {
  const imperial = TrainingUnits(
    weight: WeightUnit.lb,
    distance: DistanceUnit.miles,
  );
  setUpAll(() => initializeDateFormatting('es'));
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    TrainingUnits units = imperial,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutUnits(
          preferences: WorkoutPreferences(units: units),
          child: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'conversions preserve canonical values and distinguish load from volume',
    () {
      expect(
        imperial.weight.toKg(imperial.weight.fromKg(32.125)),
        closeTo(32.125, 1e-10),
      );
      expect(imperial.distance.toMeters(1), 1609.344);
      expect(imperial.distance.fromMeters(1609.344), 1);
      expect(imperial.metricUnit('kg·rep'), 'lb·rep');
      expect(imperial.metricValue('km', 1.609344), closeTo(1, 1e-10));
      expect(imperial.metricValue('s', 30), 30);
    },
  );
  test('preferences migrate old rest settings, retain unknown fields and isolate guest', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      WorkoutPreferences.storageKey,
      jsonEncode({
        'defaultRestEnabled': true,
        'defaultRestSeconds': 120,
        'preserve': 'unchanged',
      }),
    );
    final prior = await WorkoutPreferences.load(scope: '');
    expect(prior.defaultRestSeconds, 120);
    expect(prior.units.weight, WeightUnit.kg);
    await prior
        .copyWith(units: imperial, loadIncrementKg: imperial.weight.toKg(5))
        .save(scope: '');
    expect(
      jsonDecode(prefs.getString(WorkoutPreferences.storageKey)!)['preserve'],
      'unchanged',
    );
    final account = AccountStorageScope.forUser('units-account');
    expect(
      (await WorkoutPreferences.load(scope: account)).units.weight,
      WeightUnit.kg,
    );
    expect(
      (await WorkoutPreferences.load(scope: '')).units.weight,
      WeightUnit.lb,
    );
    expect(WorkoutPreferences.watch(account).value.units.weight, WeightUnit.kg);
  });
  test(
    'future preference schemas remain intact when a save is refused',
    () async {
      final prefs = await SharedPreferences.getInstance();
      const raw = '{"schemaVersion":99,"future":"preserve"}';
      await prefs.setString(WorkoutPreferences.storageKey, raw);
      await expectLater(
        const WorkoutPreferences(units: imperial).save(),
        throwsFormatException,
      );
      expect(prefs.getString(WorkoutPreferences.storageKey), raw);
    },
  );
  testWidgets(
    'live load input in pounds emits kg and preserves explicit clearing',
    (tester) async {
      double? result;
      bool? cleared;
      await mount(
        tester,
        SetRow(
          set: const SetInSession(id: 's', index: 1, kg: 10, reps: 8),
          onChanged: ({kg, clearKg, reps, clearReps, done}) {
            result = kg;
            cleared = clearKg;
          },
        ),
      );
      final field = find.widgetWithText(TextField, 'Lb');
      await tester.enterText(field, '22,046226218487757');
      expect(result, closeTo(10, 1e-10));
      expect(cleared, isFalse);
      await tester.enterText(field, '');
      expect(result, isNull);
      expect(cleared, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('distance input in miles emits meters without inventing a load', (
    tester,
  ) async {
    double? meters;
    await mount(
      tester,
      SetRow(
        set: const SetInSession(id: 's', index: 1),
        isDistance: true,
        onChanged: ({kg, clearKg, reps, clearReps, done}) {},
        onDistanceChanged: (v) => meters = v,
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Millas'), '1');
    expect(meters, 1609.344);
    expect(tester.takeException(), isNull);
  });
  testWidgets('routine target entered in pounds remains a canonical goal', (
    tester,
  ) async {
    double? kg;
    await mount(
      tester,
      SingleChildScrollView(
        child: ExerciseConfigurationSheet(
          exercise: trainingFixtureExercise(),
          action: 'Guardar',
          inline: true,
          onChanged: (e) => kg = e?.targetWeightKg,
        ),
      ),
    );
    final field = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          (w.decoration?.labelText?.contains('objetivo (lb)') == true),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, '22,046226218487757');
    await tester.pump();
    expect(kg, closeTo(10, 1e-10));
    expect(tester.takeException(), isNull);
  });
  test(
    'share snapshots convert presentation without mutating a recorded session',
    () {
      final report = WorkoutReport(trainingFixtureSessions().first),
          before = jsonEncode(trainingFixtureSessions().first.toJson());
      final card = TrainingExportData.session(
        report,
        const [],
        units: imperial,
      );
      expect(
        card.sections.firstWhere((s) => s.id == 'metrics').lines.join(' '),
        contains('lb·rep'),
      );
      expect(jsonEncode(report.session.toJson()), before);
      expect(card.defaults, isNot(contains('notes')));
    },
  );
  testWidgets(
    'sport distance is converted on entry and original values survive an untouched form',
    (tester) async {
      SportMeasurements? result;
      final initial = SportMeasurements(
        values: {SportMetric.distanceMeters: 1609.344},
      );
      await mount(
        tester,
        SportMeasurementsFields(
          activity: const FootballActivity(
            'test',
            'Carrera',
            FootballMode.physical,
            '',
          ),
          initial: initial,
          onChanged: (v) => result = v,
        ),
      );
      final field = find.widgetWithText(TextFormField, 'Distancia (mi)');
      expect(tester.widget<TextFormField>(field).initialValue, '1.0');
      await tester.enterText(field, '2');
      expect(result!.values[SportMetric.distanceMeters], 3218.688);
      expect(initial.values[SportMetric.distanceMeters], 1609.344);
    },
  );
  testWidgets(
    'calendar distinguishes planned rest from missing actual sessions',
    (tester) async {
      await mount(
        tester,
        WorkoutInsightsScreen(
          repository: TrainingFixtureRepository([]),
          library: _CalendarLibrary(),
          now: DateTime(2026, 10, 17),
        ),
      );
      await tester.ensureVisible(find.text('Calendario'));
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.text('Sin sesiones registradas.'), findsOneWidget);
      expect(find.text('Descanso planificado'), findsOneWidget);
      expect(find.textContaining('Semana real · Semana 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
