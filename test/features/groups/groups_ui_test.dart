import 'package:fit_app/app/theme/app_theme.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/groups/domain/groups_service.dart';
import 'package:fit_app/features/groups/presentation/pages/groups_list_screen.dart';
import 'package:fit_app/features/groups/presentation/pages/group_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  Future<void> mount(WidgetTester t, Widget screen, {double scale = 1}) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: screen,
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'create and add local contact persist without generated health activity',
    (t) async {
      await mount(t, const GroupsListScreen());
      expect(find.text('Equipo élite'), findsNothing);
      await t.tap(find.text('Crear grupo'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Equipo propio');
      await t.tap(find.text('Crear'));
      await t.pumpAndSettle();
      final group = (await GroupsService().fetchGroups()).single;
      await t.tap(find.text('Equipo propio'));
      await t.pumpAndSettle();
      await t.tap(find.text('Agregar atleta').last);
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'Nombre completo'),
        'Mi atleta',
      );
      await t.tap(find.text('Agregar'));
      await t.pumpAndSettle();
      expect(
        (await GroupsService().getGroup(group.id))!.members.single.metrics,
        isNull,
      );
      expect(find.textContaining('Sin métricas compartidas'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('save error keeps input; corrupt storage is not replaced', (
    t,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(GroupsService.storageKey, 'damaged');
    await mount(t, const GroupsListScreen());
    await t.tap(find.text('Crear grupo'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Conservar nombre');
    await t.tap(find.text('Crear'));
    await t.pumpAndSettle();
    expect(find.textContaining('No se pudo guardar'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'Conservar nombre',
    );
    expect(prefs.getString(GroupsService.storageKey), 'damaged');
    expect(t.takeException(), isNull);
  });
  testWidgets('missing group and read failure are distinct at 200 percent', (
    t,
  ) async {
    await mount(
      t,
      const GroupDetailScreen(groupId: 'missing', groupName: 'Grupo'),
      scale: 2,
    );
    expect(find.text('No se encontró el grupo'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(GroupsService.storageKey, 'damaged');
    await t.pumpWidget(const SizedBox());
    await mount(
      t,
      const GroupDetailScreen(groupId: 'missing', groupName: 'Grupo'),
      scale: 2,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
