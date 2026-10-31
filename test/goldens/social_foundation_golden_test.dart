import 'dart:ui' as ui;

import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/groups/domain/groups_service.dart';
import 'package:fit_app/features/groups/presentation/pages/group_detail_screen.dart';
import 'package:fit_app/features/groups/presentation/pages/group_entry_form.dart';
import 'package:fit_app/features/settings/presentation/integrations/integrations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> mount(
    WidgetTester t,
    Widget home, {
    double width = 390,
    double scale = 1,
    bool light = false,
  }) async {
    for (final e in {
      'Inter': 'assets/fonts/Inter-Variable.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final data = await rootBundle.load(e.value);
      await ui.loadFontFromList(data.buffer.asUint8List(), fontFamily: e.key);
    }
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: light ? AppTheme.light : AppTheme.dark,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: home,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'private local group uses real stored contacts without fabricated metrics',
    (t) async {
      final service = GroupsService(),
          group = await GroupsService().createGroup('Equipo de prueba');
      await service.addMemberToGroup(
        groupId: group.id,
        name: 'Contacto de prueba',
        role: 'Disciplina elegida',
      );
      await mount(
        t,
        GroupDetailScreen(groupId: group.id, groupName: group.name),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('social_private_group.png'),
      );
      expect(t.takeException(), isNull);
      await mount(
        t,
        Scaffold(body: GroupEntryForm(member: true, onSave: (_, _) async {})),
        width: 320,
        scale: 2,
        light: true,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('social_contact_accessible.png'),
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unavailable integration remains truthful at narrow width and large text',
    (t) async {
      await mount(t, const IntegrationsSettingsScreen(), width: 320, scale: 2);
      await t.enterText(find.byType(TextField), 'Fitbit');
      await t.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('social_integration_accessible.png'),
      );
      expect(t.takeException(), isNull);
      await t.tap(find.text('Fitbit (reloj)'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('No hay una conexión verificada'),
        findsOneWidget,
      );
      await t.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -500),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
