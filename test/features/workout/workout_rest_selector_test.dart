import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/presentation/widgets/workout_rest_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'one duration, presets, custom validation and disabled preservation',
    (tester) async {
      var seconds = 90;
      var enabled = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => WorkoutRestSelector(
                enabled: enabled,
                seconds: seconds,
                onToggle: (value) => update(() => enabled = value),
                onChanged: (value) => update(() => seconds = value),
              ),
            ),
          ),
        ),
      );
      expect(find.text('1:30'), findsOneWidget);
      expect(find.text('90s'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('1:30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('120 segundos'));
      await tester.tap(find.text('Guardar duración'));
      await tester.pumpAndSettle();
      expect(find.text('2:00'), findsOneWidget);
      await tester.tap(find.text('2:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personalizado'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Guardar duración'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresá un número entre 1 y 3600.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '75');
      await tester.tap(find.text('Guardar duración'));
      await tester.pumpAndSettle();
      expect(find.text('1:15'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(seconds, 75);
      expect(enabled, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aumentar descanso 15 segundos'));
      await tester.pumpAndSettle();
      expect(find.text('1:30'), findsOneWidget);
    },
  );
}
