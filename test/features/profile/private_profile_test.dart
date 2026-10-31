import 'dart:convert';
import 'dart:typed_data';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/profile/profile_controller.dart';
import 'package:fit_app/features/profile/profile_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  var sequence = 0;
  setUp(() {
    AccountStorageScope.current = 'profile-test-${++sequence}';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  test('name and private avatar persist after controller recreation', () async {
    final profile = ProfileController();
    await profile.ready;
    await profile.save(
      name: 'Nombre guardado',
      avatar: Uint8List.fromList([1, 2, 3]),
    );
    final restored = ProfileController();
    await restored.ready;
    expect(restored.displayName.value, 'Nombre guardado');
    expect(restored.avatarBytes.value, [1, 2, 3]);
    await restored.save(clearAvatar: true);
    final reread = ProfileController();
    await reread.ready;
    expect(reread.avatarBytes.value, isNull);
    expect(reread.displayName.value, 'Nombre guardado');
  });
  test('guest and two accounts do not inherit private identity', () async {
    AccountStorageScope.current = '';
    await ProfileController().save(name: 'Invitado');
    AccountStorageScope.current = 'a';
    final a = ProfileController();
    await a.ready;
    expect(a.displayName.value, 'USUARIO');
    await a.save(name: 'Cuenta A');
    AccountStorageScope.current = 'b';
    final b = ProfileController();
    await b.ready;
    expect(b.displayName.value, 'USUARIO');
    expect(b.avatarBytes.value, isNull);
    await expectLater(a.save(name: 'Tardío'), throwsStateError);
    AccountStorageScope.current = '';
    final guest = ProfileController();
    await guest.ready;
    expect(guest.displayName.value, 'Invitado');
  });
  test(
    'managed singleton rejects a previous controller after switching owners',
    () async {
      final previous = ProfileController.instance;
      await previous.ready;
      AccountStorageScope.current = 'other';
      await ProfileController.instance.ready;
      AccountStorageScope.current = previous.owner;
      final current = ProfileController.instance;
      await current.ready;
      await expectLater(previous.save(name: 'Stale'), throwsStateError);
      expect(current.displayName.value, 'USUARIO');
    },
  );
  test(
    'concurrent name/avatar changes preserve both fields and snapshot bytes',
    () async {
      final profile = ProfileController();
      await profile.ready;
      final bytes = Uint8List.fromList([10, 20]);
      final saveAvatar = profile.save(avatar: bytes);
      bytes[0] = 99;
      await Future.wait([saveAvatar, profile.save(name: 'Concurrente')]);
      final restored = ProfileController();
      await restored.ready;
      expect(restored.displayName.value, 'Concurrente');
      expect(restored.avatarBytes.value, [10, 20]);
    },
  );
  test('invalid or future data cannot be overwritten', () async {
    final prefs = await ScopedPreferences.getInstance();
    final raw = jsonEncode({'schemaVersion': 99, 'name': 'No borrar'});
    await prefs.setString(ProfileController.storageKey, raw);
    final profile = ProfileController();
    await profile.ready;
    expect(profile.failure.value, isNotNull);
    await expectLater(profile.save(name: 'Reemplazo'), throwsStateError);
    expect(prefs.getString(ProfileController.storageKey), raw);
  });
  test(
    'invalid name or oversized avatar does not replace saved identity',
    () async {
      final profile = ProfileController();
      await profile.save(name: 'Anterior');
      await expectLater(profile.save(name: ' '), throwsArgumentError);
      await expectLater(
        profile.save(avatar: Uint8List(ProfileController.maxAvatarBytes + 1)),
        throwsArgumentError,
      );
      expect(profile.displayName.value, 'Anterior');
      expect(profile.avatarBytes.value, isNull);
    },
  );
  testWidgets(
    'existing editor reports a durable save and validates visible name',
    (t) async {
      final profile = ProfileController();
      await t.pumpWidget(
        MaterialApp(home: ProfileSettingsScreen(controller: profile)),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Mi nombre persistente');
      await t.ensureVisible(find.byType(ElevatedButton));
      await t.pumpAndSettle();
      await t.tap(find.byType(ElevatedButton));
      await t.pumpAndSettle();
      final restored = ProfileController();
      await restored.ready;
      expect(restored.displayName.value, 'Mi nombre persistente');
      expect(find.text('Perfil guardado en esta cuenta'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
