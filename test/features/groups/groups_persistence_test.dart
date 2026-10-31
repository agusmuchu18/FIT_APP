import 'dart:convert';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/groups/domain/entities/group.dart';
import 'package:fit_app/features/groups/domain/groups_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AccountStorageScope.current = '');
  test(
    'empty groups persist after recreating service, without health metrics',
    () async {
      final service = GroupsService();
      expect(await service.fetchGroups(), isEmpty);
      final created = await service.createGroup('Mi equipo');
      final updated = await service.addMemberToGroup(
        groupId: created.id,
        name: 'Contacto del usuario',
        role: 'Corredor',
      );
      final loaded = (await GroupsService().fetchGroups()).single;
      expect(loaded.id, created.id);
      expect(loaded.members.single.id, updated!.members.single.id);
      expect(loaded.members.single.metrics, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {GroupsService.storageKey});
      expect(
        prefs.getString(GroupsService.storageKey),
        isNot(contains('metrics')),
      );
    },
  );
  test(
    'guest and two accounts are isolated; member IDs do not grant access',
    () async {
      final service = GroupsService(),
          guest = await GroupsService().createGroup('Invitado');
      AccountStorageScope.current = 'a';
      expect(await service.getGroup(guest.id), isNull);
      final a = await service.createGroup('A');
      AccountStorageScope.current = 'b';
      expect(await service.fetchGroups(), isEmpty);
      expect(
        await service.addMemberToGroup(
          groupId: a.id,
          name: 'Intruso',
          role: 'Admin',
        ),
        isNull,
      );
      AccountStorageScope.current = 'a';
      expect((await service.fetchGroups()).single.members, isEmpty);
      AccountStorageScope.current = '';
      expect((await service.fetchGroups()).single.id, guest.id);
    },
  );
  test(
    'concurrent service instances preserve all groups and contacts',
    () async {
      final groups = await Future.wait(
        List.generate(8, (i) => GroupsService().createGroup('Grupo $i')),
      );
      expect((await GroupsService().fetchGroups()).length, 8);
      await Future.wait(
        List.generate(
          12,
          (i) => GroupsService().addMemberToGroup(
            groupId: groups.first.id,
            name: 'Contacto $i',
            role: 'Atleta',
          ),
        ),
      );
      final members = (await GroupsService().getGroup(groups.first.id))!
          .members;
      expect(members.length, 12);
      expect(members.map((m) => m.id).toSet().length, 12);
    },
  );
  test(
    'corrupt and future schema storage is preserved without overwrite',
    () async {
      final prefs = await SharedPreferences.getInstance();
      for (final raw in [
        'broken',
        jsonEncode({'schemaVersion': 99, 'groups': []}),
      ]) {
        await prefs.setString(GroupsService.storageKey, raw);
        await expectLater(
          GroupsService().createGroup('Nuevo'),
          throwsA(anything),
        );
        expect(prefs.getString(GroupsService.storageKey), raw);
      }
    },
  );
  test('a pending operation aborts when identity changes', () async {
    final pending = GroupsService().createGroup('Anterior');
    AccountStorageScope.current = 'new';
    await expectLater(pending, throwsStateError);
    expect(await GroupsService().fetchGroups(), isEmpty);
    AccountStorageScope.current = '';
    expect(await GroupsService().fetchGroups(), isEmpty);
  });
  test(
    'legacy IDs stay in guest; exact known demonstration is not real people',
    () async {
      final real = Group(
        id: 'old-42',
        name: 'Grupo anterior',
        members: [
          GroupMember(id: 'old-person', name: 'Usuario', role: 'Atleta'),
        ],
      );
      final service = GroupsService(
        legacyGroups: [
          real,
          Group(
            id: 'group-elite',
            name: 'Equipo élite',
            members: [
              GroupMember(
                id: 'member-andrea',
                name: 'Andrea Gómez',
                role: 'Velocista',
              ),
            ],
          ),
        ],
      );
      AccountStorageScope.current = 'first-login';
      expect(await service.fetchGroups(), isEmpty);
      AccountStorageScope.current = '';
      final migrated = (await GroupsService().fetchGroups()).single;
      expect(migrated.id, real.id);
      expect(migrated.members.single.id, 'old-person');
    },
  );
  test(
    'similar IDs outside exact demo are preserved and names validated',
    () async {
      final service = GroupsService(
        legacyGroups: [
          Group(
            id: 'other',
            name: 'Mi grupo',
            members: [
              GroupMember(
                id: 'member-andrea',
                name: 'Persona real',
                role: 'Atleta',
              ),
            ],
          ),
        ],
      );
      expect(
        (await service.fetchGroups()).single.members.single.id,
        'member-andrea',
      );
      await expectLater(service.createGroup('  '), throwsArgumentError);
      expect(
        () => Group.fromJson({'id': 'x', 'name': ' ', 'members': []}),
        throwsFormatException,
      );
    },
  );
  test(
    'legacy collisions preserve saved fields and archive alternate values',
    () async {
      final created = await GroupsService().createGroup('Nombre guardado');
      final stored = (await GroupsService().addMemberToGroup(
        groupId: created.id,
        name: 'Contacto guardado',
        role: 'Atleta',
      ))!;
      final legacy = Group(
        id: stored.id,
        name: 'Nombre anterior',
        members: [
          GroupMember(
            id: stored.members.single.id,
            name: 'Nombre alternativo',
            role: 'Corredor',
          ),
          GroupMember(
            id: 'legacy-contact',
            name: 'Contacto anterior',
            role: 'Atleta',
          ),
        ],
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        final merged = (await GroupsService(
          legacyGroups: [legacy],
        ).fetchGroups()).single;
        expect(merged.id, stored.id);
        expect(merged.name, 'Nombre guardado');
        expect(merged.members.map((m) => m.id), [
          stored.members.single.id,
          'legacy-contact',
        ]);
        expect(merged.members.first.name, 'Contacto guardado');
        final prefs = await SharedPreferences.getInstance();
        final archive = jsonDecode(
          prefs.getString(GroupsService.legacyConflictsKey)!,
        ) as Map;
        expect((archive['groups'] as List).single, legacy.toJson());
      }
    },
  );
  test('a corrupt conflict archive stops migration without dropping legacy data', () async {
    final stored = await GroupsService().createGroup('Guardado');
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString(GroupsService.storageKey);
    await prefs.setString(GroupsService.legacyConflictsKey, 'corrupt');
    final service = GroupsService(
      legacyGroups: [stored.copyWith(name: 'Anterior')],
    );
    await expectLater(service.fetchGroups(), throwsFormatException);
    expect(prefs.getString(GroupsService.storageKey), before);
    expect(prefs.getString(GroupsService.legacyConflictsKey), 'corrupt');
    // Removing only the deliberately corrupt test fixture permits a safe retry.
    await prefs.remove(GroupsService.legacyConflictsKey);
    expect((await service.fetchGroups()).single.name, 'Guardado');
    expect(
      prefs.getString(GroupsService.legacyConflictsKey),
      contains('Anterior'),
    );
  });
}
