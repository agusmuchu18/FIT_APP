import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/features/workout/presentation/widgets/workout_rest_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'rest duration edits inline, validates, normalizes and preserves disabled duration',
    (tester) async {
      var seconds = 90, enabled = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.workout,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => WorkoutRestSelector(
                enabled: enabled,
                seconds: seconds,
                onToggle: (v) => update(() => enabled = v),
                onChanged: (v) => update(() => seconds = v),
              ),
            ),
          ),
        ),
      );
      expect(find.text('1:30'), findsOneWidget);
      await tester.tap(find.text('1:30'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.byTooltip('Guardar duración'));
      await tester.pumpAndSettle();
      expect(seconds, 90);
      expect(find.textContaining('Ingresá de 1'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '75');
      await tester.tap(find.byTooltip('Guardar duración'));
      await tester.pumpAndSettle();
      expect(find.text('1:15'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
      expect(seconds, 75);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aumentar descanso 15 segundos'));
      await tester.pumpAndSettle();
      expect(find.text('1:30'), findsOneWidget);
      await tester.tap(find.text('1:30'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2:05');
      await tester.tap(find.byTooltip('Guardar duración'));
      await tester.pumpAndSettle();
      expect(seconds, 125);
      expect(find.text('2:05'), findsOneWidget);
      await tester.tap(find.text('2:05'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1:90');
      await tester.tap(find.byTooltip('Guardar duración'));
      await tester.pumpAndSettle();
      expect(seconds, 125);
      await tester.tap(find.byTooltip('Cancelar edición'));
      await tester.pumpAndSettle();
      expect(find.text('2:05'), findsOneWidget);
    },
  );
}
