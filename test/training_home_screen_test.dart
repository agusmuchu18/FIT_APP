import 'dart:convert';

import 'package:fit_app/features/workout/training_home/training_home_screen.dart';
import 'package:fit_app/features/workout/training_home/training_home_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renderiza estado vacío con CTA compacto y banner sin acciones redundantes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pro_workout_templates': jsonEncode([]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await pumpHome(tester);

    expect(find.text('Registrar entrenamiento (sin rutina)'), findsOneWidget);
    expect(find.text('Ideal para sesiones improvisadas o deportes'), findsNothing);
    expect(find.text('Gym'), findsNothing);
    expect(find.text('Casa'), findsNothing);
    expect(find.text('Outdoor'), findsNothing);
    expect(find.text('Todavía no tenés rutinas guardadas.'), findsOneWidget);
    expect(find.text('Usá ‘Nueva rutina’ o ‘Buscar rutinas’ para empezar.'), findsOneWidget);
    expect(find.text('Importar plantilla'), findsNothing);
    expect(find.text('Crear desde cero'), findsNothing);
  });

  testWidgets('renderiza Mis rutinas y botón Ordenar cuando hay rutinas', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pro_workout_templates': jsonEncode([
        {
          'id': 'r1',
          'name': 'Push Day',
          'type': 'strength',
          'origin': 'user',
          'activityName': 'Gym',
          'exercises': [
            {'id': 'e1', 'name': 'Press banca', 'sets': []}
          ],
        }
      ]),
      'pro_workout_sessions': jsonEncode([]),
    });

    await pumpHome(tester);

    expect(find.text('Mis rutinas'), findsOneWidget);
    expect(find.text('Ordenar'), findsOneWidget);
    expect(find.byType(RoutineMiniCard), findsAtLeastNWidgets(1));
    expect(find.text('Gym Gym'), findsNothing);
    expect(find.text('Press banca'), findsOneWidget);
  });
}
