import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/account_storage_scope.dart';

/// The existing profile controller, now durable and bound to one local owner.
/// No public profile or upload is implied by editing a name or avatar.
class ProfileController {
  ProfileController({String? owner, this.preferences})
    : owner = owner ?? AccountStorageScope.current {
    ready = _restore();
  }
  static ProfileController? _current;
  static ProfileController get instance {
    final owner = AccountStorageScope.current;
    if (_current == null || _current!.owner != owner) {
      _current = ProfileController(owner: owner).._managed = true;
    }
    return _current!;
  }

  static const storageKey = 'profile.private.v1';
  static const maxAvatarBytes = 300 * 1024;
  final String owner;
  final SharedPreferences? preferences;
  final displayName = ValueNotifier<String>('USUARIO');
  final avatarBytes = ValueNotifier<Uint8List?>(null);
  final failure = ValueNotifier<String?>(null);
  late final Future<void> ready;
  Future<void> _writes = Future.value();
  bool _readFailed = false;
  bool _managed = false;
  void _checkOwner() {
    if (owner != AccountStorageScope.current ||
        (_managed && !identical(_current, this))) {
      throw StateError('La cuenta cambió. Volvé a abrir Perfil.');
    }
  }

  Future<ScopedPreferences> _prefs() async => preferences == null
      ? ScopedPreferences.getInstance(scope: owner)
      : ScopedPreferences(preferences!, scope: owner);
  Future<void> _restore() async {
    try {
      final prefs = await _prefs();
      _checkOwner();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['schemaVersion'] != 1 || data['name'] is! String) {
          throw const FormatException('Perfil no compatible');
        }
        final name = data['name'] as String;
        final avatar = data['avatar'] == null
            ? null
            : base64Decode(data['avatar'] as String);
        if (name.length > 80 || (avatar?.length ?? 0) > maxAvatarBytes) {
          throw const FormatException('Perfil inválido');
        }
        displayName.value = name.isEmpty ? 'USUARIO' : name;
        avatarBytes.value = avatar;
      }
      _readFailed = false;
      failure.value = null;
    } catch (_) {
      _readFailed = true;
      if (owner == AccountStorageScope.current) {
        failure.value =
            'No se pudo recuperar el perfil. Los datos guardados se conservan.';
      }
    }
  }

  Future<void> retryRestore() async {
    await ready;
    await _restore();
  }

  Future<void> save({
    String? name,
    Uint8List? avatar,
    bool clearAvatar = false,
  }) {
    final avatarSnapshot = avatar == null ? null : Uint8List.fromList(avatar);
    final operation = _writes.then((_) async {
      await ready;
      _checkOwner();
      if (_readFailed) {
        throw StateError('No se sobrescribe un perfil ilegible.');
      }
      final nextName = name?.trim() ?? displayName.value;
      final nextAvatar = clearAvatar
          ? null
          : avatarSnapshot ?? avatarBytes.value;
      if (nextName.isEmpty || nextName.length > 80) {
        throw ArgumentError('Usá un nombre de 1 a 80 caracteres.');
      }
      if ((nextAvatar?.length ?? 0) > maxAvatarBytes) {
        throw ArgumentError('Elegí una imagen de menos de 300 KB.');
      }
      final prefs = await _prefs();
      _checkOwner();
      await prefs.setString(
        storageKey,
        jsonEncode({
          'schemaVersion': 1,
          'name': nextName,
          'avatar': nextAvatar == null ? null : base64Encode(nextAvatar),
        }),
      );
      _checkOwner();
      displayName.value = nextName;
      avatarBytes.value = nextAvatar == null
          ? null
          : Uint8List.fromList(nextAvatar);
      failure.value = null;
    });
    _writes = operation.catchError((Object _) {
      if (owner == AccountStorageScope.current) failure.value = 'No se pudo guardar el perfil. Reintentá; tus datos anteriores se conservan.';
    });
    return operation;
  }

  // Compatible callbacks for the existing avatar viewer. Failures remain observable.
  void updateName(String name) {
    unawaited(save(name: name).catchError((Object _) {}));
  }

  void updateAvatar(Uint8List? bytes) {
    unawaited(
      save(avatar: bytes, clearAvatar: bytes == null).catchError((Object _) {}),
    );
  }
}
