import 'package:fit_app/features/settings/presentation/integrations/integration_models.dart';
import 'package:fit_app/features/settings/presentation/integrations/integration_readiness.dart';
import 'package:fit_app/features/settings/presentation/integrations/integrations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'eighteen connectors do not treat old flags as authorization or last sync',
    () {
      expect(IntegrationId.values.length, 18);
      for (final id in IntegrationId.values) {
        expect(IntegrationReadiness.canConnect(id), isFalse);
        final s = IntegrationReadiness.verifiedStatus(
          id,
          IntegrationStatus(
            connected: true,
            enabled: true,
            lastSync: DateTime(2026),
          ),
        );
        expect(s.connected, isFalse);
        expect(s.lastSync, isNull);
        expect(IntegrationReadiness.reason(id), isNotEmpty);
      }
    },
  );
  testWidgets(
    'a stale connection flag cannot show connected or call missing native handlers',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'app.integrations.statuses': '{"fitbit":{"connected":true,"enabled":true,"lastSync":"2026-10-01"}}',
      });
      await t.pumpWidget(const MaterialApp(home: IntegrationsSettingsScreen()));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Fitbit');
      await t.pumpAndSettle();
      expect(find.text('Conectado'), findsNothing);
      expect(find.text('Conectar'), findsNothing);
      expect(find.text('Autorización pendiente'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'app.integrations.statuses',
        ),
        contains('"connected":true'),
      );
      expect(t.takeException(), isNull);
    },
  );
}
