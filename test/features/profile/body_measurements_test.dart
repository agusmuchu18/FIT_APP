import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/profile/body_measurement.dart';
import 'package:fit_app/features/profile/body_measurement_form.dart';
import 'package:fit_app/features/profile/body_measurements_screen.dart';
import 'package:fit_app/features/profile/data/body_measurement_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late BodyMeasurementRepository repo;
  final date = DateTime(2026, 10, 10);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fit_body_test_');
    Hive.init(dir.path);
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
    repo = BodyMeasurementRepository();
  });
  tearDown(() async {
    AccountStorageScope.current = '';
    await Hive.close();
    await dir.delete(recursive: true); // This test owns this exact temp folder.
  });
  Future<void> seed({double weight = 80, DateTime? at}) => repo.save(
    date: at ?? date,
    values: {BodyMetric.weight: BodyValue(weight, 'kg')},
  );
  test('reopen preserves original values, units, IDs and partial manual observations', () async {
    await repo.save(
      date: date,
      values: const {
        BodyMetric.weight: BodyValue(176.3698097479, 'lb'),
        BodyMetric.leftBiceps: BodyValue(14, 'in'),
      },
      notes: 'Privado',
    );
    final before = (await repo.records()).single;
    await Hive.close();
    final after = (await BodyMeasurementRepository().records()).single;
    expect(after.id, before.id);
    expect(after.toJson(), before.toJson());
    expect(after.values[BodyMetric.weight]!.canonical, closeTo(80, 1e-9));
    expect(after.values[BodyMetric.leftBiceps]!.canonical, 35.56);
    expect(after.values.containsKey(BodyMetric.bodyFat), false);
    expect(after.toJson()['source'], 'manual');
  });
  test(
    'guest stays separate and old repositories cannot access another account',
    () async {
      await seed();
      AccountStorageScope.current = AccountStorageScope.forUser('a');
      await expectLater(repo.records(), throwsStateError);
      await expectLater(seed(), throwsStateError);
      final a = BodyMeasurementRepository();
      expect(await a.records(), isEmpty);
      await a.save(
        date: date,
        values: const {BodyMetric.waist: BodyValue(82, 'cm')},
      );
      AccountStorageScope.current = AccountStorageScope.forUser('b');
      expect(await BodyMeasurementRepository().records(), isEmpty);
      AccountStorageScope.current = '';
      expect((await repo.records()).single.values.keys, [BodyMetric.weight]);
    },
  );
  test('concurrent adds across repositories keep every record', () async {
    await Future.wait([
      for (var i = 0; i < 12; i++)
        BodyMeasurementRepository().save(
          date: date,
          values: {BodyMetric.weight: BodyValue(70.0 + i, 'kg')},
        ),
    ]);
    expect((await repo.records()).length, 12);
    expect((await repo.records()).map((e) => e.id).toSet().length, 12);
  });
  test(
    'edits and deletes reject stale revisions instead of losing another edit',
    () async {
      await seed();
      final original = (await repo.records()).single;
      await repo.save(
        editingId: original.id,
        expectedRevision: original.revision,
        date: date,
        values: original.values,
        notes: 'Nueva nota',
      );
      await expectLater(
        repo.save(
          editingId: original.id,
          expectedRevision: original.revision,
          date: date,
          values: original.values,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.delete(original.id, expectedRevision: original.revision),
        throwsStateError,
      );
      final changed = (await repo.records()).single;
      expect(changed.notes, 'Nueva nota');
      expect(changed.createdAt, original.createdAt);
      await repo.delete(changed.id, expectedRevision: changed.revision);
      await repo.delete(changed.id, expectedRevision: changed.revision);
      expect(await repo.records(), isEmpty);
    },
  );
  test('corrupt or future records remain intact and prevent writes', () async {
    await seed();
    final box = Hive.box<String>(repo.boxName);
    final row = box.keys.firstWhere((key) => key != 'schema');
    final good = box.get(row)!;
    for (final damaged in [
      '{bad',
      jsonEncode({...jsonDecode(good) as Map, 'schemaVersion': 9}),
    ]) {
      await box.put(row, damaged);
      await expectLater(repo.records(), throwsA(anything));
      await expectLater(seed(), throwsA(anything));
      expect(box.get(row), damaged);
      expect(box.length, 2);
    }
    await box.put(row, good);
    expect((await repo.records()).length, 1);
    await box.put('schema', '9');
    await expectLater(seed(), throwsFormatException);
    expect(box.get('schema'), '9');
    expect(box.get(row), good);
  });
  test('failed opening leaves saved data unchanged and allows retry', () async {
    await seed();
    var fail = true;
    final fragile = BodyMeasurementRepository(
      openBox: (name) async {
        if (fail) throw const FileSystemException('test only');
        return Hive.box<String>(name);
      },
    );
    await expectLater(
      fragile.save(
        date: date,
        values: const {BodyMetric.weight: BodyValue(90, 'kg')},
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect((await repo.records()).single.values[BodyMetric.weight]!.value, 80);
    fail = false;
    await fragile.save(
      date: date,
      values: const {BodyMetric.weight: BodyValue(90, 'kg')},
    );
    expect((await repo.records()).length, 2);
  });
  test(
    'invalid units, nonfinite, empty and future dates do not create records',
    () async {
      for (final values in <Map<BodyMetric, BodyValue>>[
        {},
        {BodyMetric.weight: const BodyValue(20, 'cm')},
        {BodyMetric.bodyFat: const BodyValue(101, '%')},
        {BodyMetric.weight: BodyValue(double.nan, 'kg')},
        {BodyMetric.waist: const BodyValue(-1, 'cm')},
      ]) {
        await expectLater(
          repo.save(date: date, values: values),
          throwsFormatException,
        );
      }
      await expectLater(
        repo.save(
          date: DateTime(2200),
          values: const {BodyMetric.weight: BodyValue(80, 'kg')},
        ),
        throwsFormatException,
      );
      expect(await repo.records(), isEmpty);
    },
  );

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'optional form saves one value, remembers fields and never infers body fat',
    (tester) async {
      await tester.runAsync(() => Hive.openBox<String>(repo.boxName));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: BodyMeasurementsScreen(
            repository: repo,
            now: DateTime(2026, 10, 24),
          ),
        ),
      );
      await flush(tester);
      await tester.tap(find.text('Registrar medidas'));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(r'Peso \(kg\).*Peso \(kg\)')),
        findsNothing,
      );
      expect(find.bySemanticsLabel(RegExp(r'Peso \(kg\)')), findsOneWidget);
      semantics.dispose();
      await tester.enterText(
        find.byKey(const ValueKey('body-weight')),
        '80,25',
      );
      await tester.scrollUntilVisible(
        find.text('Guardar medidas'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar medidas'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await flush(tester);
      final records = await tester.runAsync(repo.records);
      expect(records!.single.values.keys, [BodyMetric.weight]);
      expect(records.single.values[BodyMetric.weight]!.value, 80.25);
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.maxY, greaterThan(chart.data.minY));
      await tester.scrollUntilVisible(find.text('80,25 kg'), 250);
      expect(find.text('80,25 kg'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Registrar medidas'), -300);
      await tester.tap(find.text('Registrar medidas'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('body-weight')), findsOneWidget);
      expect(find.byKey(const ValueKey('body-waist')), findsNothing);
    },
  );
  testWidgets(
    'untouched edit keeps original precision and units across conversion',
    (tester) async {
      await tester.runAsync(
        () => repo.save(
          date: date,
          values: const {BodyMetric.weight: BodyValue(80.123456789123, 'kg')},
        ),
      );
      final original = (await tester.runAsync(repo.records))!.single;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BodyMeasurementForm(
            repository: repo,
            existing: original,
            unitFor: (_) => 'lb',
            now: DateTime(2026, 10, 24),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Guardar medidas'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Guardar medidas'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await flush(tester);
      final after = (await tester.runAsync(repo.records))!.single;
      expect(
        after.values[BodyMetric.weight]!.value,
        original.values[BodyMetric.weight]!.value,
      );
      expect(after.values[BodyMetric.weight]!.unit, 'kg');
    },
  );
  testWidgets(
    'private trend and comparison remain legible at 320px and 200 percent',
    (tester) async {
      await tester.runAsync(() async {
        await seed(weight: 82, at: DateTime(2026, 10, 1));
        await seed(weight: 80, at: DateTime(2026, 10, 24));
      });
      for (final font in {
        'Inter': 'assets/fonts/Inter-Variable.ttf',
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final bytes = await rootBundle.load(font.value);
        await ui.loadFontFromList(
          bytes.buffer.asUint8List(),
          fontFamily: font.key,
        );
      }
      tester.view.physicalSize = const Size(320, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: BodyMeasurementsScreen(
            repository: repo,
            now: DateTime(2026, 10, 24),
          ),
        ),
      );
      await flush(tester);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile('../../goldens/body_measurements_accessible.png'),
      );
      await tester.ensureVisible(find.text('Comparar dos registros'));
      await tester.tap(find.text('Comparar dos registros'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Diferencia entre los registros elegidos; no es una valoración de salud.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'light form validates optional inputs and reflows at 200 percent',
    (tester) async {
      await tester.runAsync(() => Hive.openBox<String>(repo.boxName));
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BodyMeasurementForm(
            repository: repo,
            unitFor: (m) => m.unit,
            now: DateTime(2026, 10, 24),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('../../goldens/body_measurement_form_light.png'),
      );
      await tester.enterText(find.byKey(const ValueKey('body-weight')), '-2');
      await tester.scrollUntilVisible(
        find.text('Guardar medidas'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar medidas'));
      await tester.pumpAndSettle();
      expect(find.text('Usá un valor positivo y finito'), findsOneWidget);
      expect(await tester.runAsync(repo.records), isEmpty);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(320, 1000);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: BodyMeasurementForm(
            repository: repo,
            unitFor: (m) => m.unit,
            now: DateTime(2026, 10, 24),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('../../goldens/body_measurement_form_accessible.png'),
      );
      await tester.scrollUntilVisible(
        find.text('Guardar medidas'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'corrupt history shows recovery instead of an empty successful history',
    (tester) async {
      await tester.runAsync(() async {
        await seed();
        final box = Hive.box<String>(repo.boxName);
        await box.put('schema', '9');
      });
      await tester.pumpWidget(
        MaterialApp(home: BodyMeasurementsScreen(repository: repo)),
      );
      await flush(tester);
      expect(
        find.textContaining('No se pudo leer tu historial'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Registrar medidas'),
            )
            .onPressed,
        isNull,
      );
      await tester.runAsync(
        () => Hive.box<String>(repo.boxName).put('schema', '1'),
      );
      await tester.tap(find.text('Reintentar'));
      await flush(tester);
      expect(find.textContaining('No se pudo leer tu historial'), findsNothing);
      expect((await tester.runAsync(repo.records))!.length, 1);
    },
  );
}
