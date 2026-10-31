import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/domain/routine_catalog.dart';
import 'package:fit_app/features/workout/training_home/catalog_routine_detail_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_search_screen.dart';
import 'package:fit_app/features/workout/training_home/routines_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (
      var attempt = 0;
      attempt < 25 && target.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
  }

  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool light = false,
    bool detail = false,
  }) async {
    for (final entry in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await rootBundle.load(entry.value);
      await ui.loadFontFromList(
        data.buffer.asUint8List(),
        fontFamily: entry.key,
      );
    }
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? AppTheme.light : AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: detail
            ? CatalogRoutineDetailScreen(
                routine: RoutineCatalog.routines.first,
                repository: RoutinesRepository(),
              )
            : const WorkoutRoutineSearchScreen(),
      ),
    );
    final context = tester.element(find.byType(Scaffold).first);
    await tester.runAsync(() async {
      await Future.wait([
        for (final r in RoutineCatalog.routines)
          precacheImage(
            ResizeImage.resizeIfNeeded(1024, null, AssetImage(r.imageAsset)),
            context,
          ),
        precacheImage(
          const AssetImage('assets/images/workout/exercises/plank.webp'),
          context,
        ),
      ]);
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'catalog and detail have readable imagery and controls at mobile size',
    (tester) async {
      await mount(tester);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('routine_catalog_mobile.png'),
      );
      await tester.tap(find.text('Primeros pasos en el gym'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('routine_catalog_detail.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('light wide catalog uses two columns and readable surface text', (
    tester,
  ) async {
    await mount(tester, width: 900, light: true);
    final context = tester.element(find.byType(CatalogRoutineCover).first);
    final colors = Theme.of(context).colorScheme;
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    expect(
      contrast(colors.onSurface, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(colors.onSurfaceVariant, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('routine_catalog_wide_light.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '320px and 200 percent keep filters and detail action reachable with reduced motion',
    (tester) async {
      await mount(tester, width: 320, scale: 2);
      await reveal(tester, find.widgetWithText(ChoiceChip, 'Avanzado'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Avanzado'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Torso: volumen y control'));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('routine_catalog_accessible.png'),
      );
      await tester.tap(find.text('Torso: volumen y control'));
      await tester.pumpAndSettle();
      expect(find.text('Personalizar y guardar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await reveal(tester, find.text('Orden de ejercicios'));
      expect(tester.takeException(), isNull);
    },
  );
}
