import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/account_storage_scope.dart';
import 'entities/group.dart';

/// Owner-private local groups. Contacts are not remote authenticated members.
/// Following or adding a contact never grants access to their health data.
class GroupsService {
  GroupsService({this.preferences, List<Group> legacyGroups = const []}) {
    for (final group in legacyGroups) {
      _groups[group.id] = group;
    }
  }
  static const storageKey = 'groups.private.v1';
  static const legacyConflictsKey = 'groups.private.legacy_conflicts.v1';
  final SharedPreferences? preferences;
  // Keep this field for importing old in-process groups; old versions had no disk store.
  final Map<String, Group> _groups = {};
  static final Map<String, Future<void>> _writes = {};

  void _check(String owner) {
    if (owner != AccountStorageScope.current) {
      throw StateError('La cuenta cambió. Volvé a abrir Grupos.');
    }
  }

  Future<ScopedPreferences> _prefs(String owner) async => preferences == null
      ? ScopedPreferences.getInstance(scope: owner)
      : ScopedPreferences(preferences!, scope: owner);
  Future<T> _serial<T>(String owner, Future<T> Function() action) async {
    final previous = _writes[owner], gate = Completer<void>();
    _writes[owner] = gate.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      if (identical(_writes[owner], gate.future)) _writes.remove(owner);
      gate.complete();
    }
  }

  List<Group> _read(
    ScopedPreferences prefs, {
    String key = storageKey,
    bool uniqueIds = true,
  }) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Versión de grupos no compatible');
    }
    final groups = (data['groups'] as List)
        .map((g) => Group.fromJson(Map<String, dynamic>.from(g as Map)))
        .toList();
    if (uniqueIds && groups.map((g) => g.id).toSet().length != groups.length) {
      throw const FormatException('Grupos duplicados');
    }
    return groups;
  }

  Future<void> _save(
    ScopedPreferences prefs,
    List<Group> groups, {
    String key = storageKey,
  }) => prefs.setString(
    key,
    jsonEncode({
      'schemaVersion': 1,
      'groups': groups.map((g) => g.toJson()).toList(),
    }),
  );

  Future<void> _preserveLegacy() async {
    if (_groups.isEmpty) return;
    // Previously unowned entries belong to guest, never to the first account to log in.
    await _serial('', () async {
      if (_groups.isEmpty) return;
      final prefs = await _prefs('');
      final saved = _read(prefs);
      List<Group>? conflicts;
      const demoMembers = {
        'member-andrea': 'Andrea Gómez',
        'member-julián': 'Julián Rivas',
        'member-marcela': 'Marcela Ríos',
      };
      for (final group in _groups.values) {
        final members = group.members
            .where(
              (m) =>
                  group.id != 'group-elite' ||
                  group.name != 'Equipo élite' ||
                  demoMembers[m.id] != m.name,
            )
            .toList();
        if (group.id == 'group-elite' &&
            group.name == 'Equipo élite' &&
            members.isEmpty) {
          continue;
        }
        final incoming = group.copyWith(members: members);
        final index = saved.indexWhere((g) => g.id == group.id);
        if (index < 0) {
          saved.add(incoming);
        } else if (jsonEncode(saved[index].toJson()) !=
            jsonEncode(incoming.toJson())) {
          // Keep both versions recoverable without replacing saved identities.
          conflicts ??= _read(prefs, key: legacyConflictsKey, uniqueIds: false);
          final snapshot = jsonEncode(incoming.toJson());
          if (!conflicts.any((g) => jsonEncode(g.toJson()) == snapshot)) {
            conflicts.add(incoming);
          }
          final current = saved[index];
          final memberIds = current.members.map((m) => m.id).toSet();
          saved[index] = current.copyWith(
            members: [
              ...current.members,
              ...members.where((m) => memberIds.add(m.id)),
            ],
          );
        }
      }
      if (conflicts != null) {
        await _save(prefs, conflicts, key: legacyConflictsKey);
      }
      await _save(prefs, saved);
      _groups.clear();
    });
  }

  Future<List<Group>> fetchGroups() async {
    final owner = AccountStorageScope.current;
    await _preserveLegacy();
    final prefs = await _prefs(owner);
    _check(owner);
    return _read(prefs);
  }

  Future<Group?> getGroup(String id) async =>
      (await fetchGroups()).where((g) => g.id == id).firstOrNull;
  Future<Group> createGroup(String name) async {
    final owner = AccountStorageScope.current, trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 120) {
      throw ArgumentError('Usá un nombre de 1 a 120 caracteres.');
    }
    await _preserveLegacy();
    return _serial(owner, () async {
      final prefs = await _prefs(owner);
      _check(owner);
      final groups = _read(prefs);
      final group = Group(
        id: 'group-${const Uuid().v4()}',
        name: trimmed,
        members: [],
      );
      groups.add(group);
      await _save(prefs, groups);
      _check(owner);
      return group;
    });
  }

  Future<Group?> addMemberToGroup({
    required String groupId,
    required String name,
    required String role,
  }) async {
    final owner = AccountStorageScope.current, trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 120 || role.trim().length > 80) {
      throw ArgumentError('Revisá el nombre y la descripción del atleta.');
    }
    await _preserveLegacy();
    return _serial(owner, () async {
      final prefs = await _prefs(owner);
      _check(owner);
      final groups = _read(prefs);
      final index = groups.indexWhere((g) => g.id == groupId);
      if (index < 0) return null;
      final group = groups[index];
      final member = GroupMember(
        id: 'member-${const Uuid().v4()}',
        name: trimmed,
        role: role.trim(),
      );
      groups[index] = group.copyWith(members: [...group.members, member]);
      await _save(prefs, groups);
      _check(owner);
      return groups[index];
    });
  }
}

final groupsService = GroupsService();
