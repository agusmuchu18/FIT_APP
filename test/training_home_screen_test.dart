import 'dart:convert';

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:fit_app/features/workout/training_home/routine_library_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final viewport in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'rutinas guardadas adaptables a ${viewport.$1}px y escala ${viewport.$2}',
      (tester) async {
        tester.view.physicalSize = Size(viewport.$1, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'pro_workout_templates': jsonEncode([
            {
              'id': 'responsive-routine',
              'name': 'Rutina guardada',
              'type': 'strength',
              'origin': 'user',
              'exercises': [
                {'id': 'bench_press', 'name': 'Press banca', 'sets': []},
              ],
            },
          ]),
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(viewport.$2)),
              child: child!,
            ),
            home: const TrainingHomeScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -1100),
        );
        await tester.pumpAndSettle();
        expect(find.text('Rutina guardada'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TrainingHomeScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'renderiza estado vacío con entrada fotográfica y acciones claras',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'pro_workout_templates': jsonEncode([]),
        'pro_workout_sessions': jsonEncode([]),
      });

      await pumpHome(tester);

      expect(find.text('Entrenamiento libre'), findsOneWidget);
      expect(
        find.text('Ideal para sesiones improvisadas o deportes'),
        findsNothing,
      );
      expect(find.text('Gym'), findsNothing);
      expect(find.text('Casa'), findsNothing);
      expect(find.text('Outdoor'), findsNothing);
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text('Todavía no tenés rutinas guardadas.'), findsOneWidget);
      expect(
        find.text('Usá ‘Nueva rutina’ o ‘Buscar rutinas’ para empezar.'),
        findsOneWidget,
      );
      expect(find.text('Importar plantilla'), findsNothing);
      expect(find.text('Crear desde cero'), findsNothing);
    },
  );

  testWidgets('renderiza Mis rutinas y botón Ordenar cuando hay rutinas', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'pro_workout_templates': jsonEncode([
        {
          'id': 'r1',
          'name': 'Push Day',
          'type': 'strength',
          'origin': 'user',
          'activityName': 'Gym',
          'exercises': [
            {'id': 'e1', 'name': 'Press banca', 'sets': []},
          ],
        },
      ]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await pumpHome(tester);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mis rutinas'), findsOneWidget);
    expect(find.text('Ordenar'), findsOneWidget);
    expect(find.byType(RoutineLibraryCard), findsAtLeastNWidgets(1));
    expect(
      tester.getSize(find.byType(RoutineLibraryCard).first).width,
      greaterThan(330),
    );
    expect(find.text('Gym Gym'), findsNothing);
    expect(find.text('Press banca'), findsOneWidget);
  });

  testWidgets('mantiene las acciones legibles a 320 px y texto al 200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'pro_workout_templates': jsonEncode([]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const TrainingHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrenamiento libre'), findsOneWidget);
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -550),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nueva rutina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
