import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import 'profile_photo_viewer.dart';

/// Avatar interactivo para abrir el visor fullscreen sin navegar de pantalla.
class ProfileAvatarWidget extends StatelessWidget {
  const ProfileAvatarWidget({
    super.key,
    required this.displayName,
    required this.avatarBytes,
    required this.onAvatarChanged,
    this.radius = 28,
  });

  final String displayName;
  final Uint8List? avatarBytes;
  final ValueChanged<Uint8List?> onAvatarChanged;
  final double radius;

  String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'US';
    final parts = trimmed.split(RegExp(r'\\s+'));
    if (parts.length == 1) {
      final word = parts.first;
      return word.length > 1
          ? word.substring(0, 2).toUpperCase()
          : word.substring(0, 1).toUpperCase();
    }
    return ((parts[0].isNotEmpty ? parts[0][0] : '') +
            (parts[1].isNotEmpty ? parts[1][0] : ''))
        .toUpperCase();
  }

  Future<void> _openViewer(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar visor',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        return ProfilePhotoViewer(
          displayName: displayName,
          avatarBytes: avatarBytes,
          onAvatarChanged: onAvatarChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openViewer(context),
      borderRadius: BorderRadius.circular(radius + 6),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.accentSecondary.withOpacity(0.2),
        backgroundImage: avatarBytes == null ? null : MemoryImage(avatarBytes!),
        child: avatarBytes == null
            ? Text(
                _initialsFromName(displayName),
                style: const TextStyle(
                  color: AppColors.accentSecondary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}
