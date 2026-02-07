import 'dart:typed_data';

import 'package:flutter/foundation.dart';

class ProfileController {
  ProfileController._();

  static final ProfileController instance = ProfileController._();

  final ValueNotifier<String> displayName = ValueNotifier<String>('USUARIO');
  final ValueNotifier<Uint8List?> avatarBytes = ValueNotifier<Uint8List?>(null);

  void updateName(String name) {
    final trimmed = name.trim();
    displayName.value = trimmed.isEmpty ? 'USUARIO' : trimmed;
  }

  void updateAvatar(Uint8List? bytes) {
    avatarBytes.value = bytes;
  }
}
