import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Empty namespace preserves existing installations as guest-owned data.
class AccountStorageScope {
  AccountStorageScope._();
  static String current = '';

  static String forUser(String? userId) => userId == null
      ? ''
      : utf8
            .encode(userId)
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join();

  static String boxName(String base, String scope) =>
      scope.isEmpty ? base : '${base}_$scope';
}

/// Captures ownership before the first await, including late writes after logout.
class ScopedPreferences {
  ScopedPreferences(this._preferences, {String? scope})
    : scope = scope ?? AccountStorageScope.current;
  final SharedPreferences _preferences;
  final String scope;
  static Future<ScopedPreferences> getInstance({String? scope}) async {
    final owner = scope ?? AccountStorageScope.current;
    return ScopedPreferences(
      await SharedPreferences.getInstance(),
      scope: owner,
    );
  }

  String _key(String key) => scope.isEmpty ? key : 'account:$scope:$key';
  String? getString(String key) => _preferences.getString(_key(key));
  List<String>? getStringList(String key) =>
      _preferences.getStringList(_key(key));
  Object? get(String key) => _preferences.get(_key(key));
  Future<bool> _checked(Future<bool> write) async {
    if (!await write) throw StateError('No se pudo persistir el cambio local.');
    return true;
  }

  Future<bool> setString(String key, String value) =>
      _checked(_preferences.setString(_key(key), value));
  Future<bool> setStringList(String key, List<String> value) =>
      _checked(_preferences.setStringList(_key(key), value));
  Future<bool> remove(String key) => _checked(_preferences.remove(_key(key)));
}
