import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import 'profile_controller.dart';
import 'profile_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Perfil',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                children: [
                  ValueListenableBuilder(
                    valueListenable: ProfileController.instance.avatarBytes,
                    builder: (context, bytes, _) {
                      return ValueListenableBuilder(
                        valueListenable: ProfileController.instance.displayName,
                        builder: (context, name, __) {
                          return CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                AppColors.accentSecondary.withOpacity(0.2),
                            backgroundImage:
                                bytes == null ? null : MemoryImage(bytes),
                            child: bytes == null
                                ? Text(
                                    _initialsFromName(name),
                                    style: const TextStyle(
                                      color: AppColors.accentSecondary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  ValueListenableBuilder(
                    valueListenable: ProfileController.instance.displayName,
                    builder: (context, name, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Plan Premium activo',
                            style: TextStyle(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ProfileOption(
              icon: Icons.settings_rounded,
              label: 'Ajustes',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileSettingsScreen(),
                  ),
                );
              },
            ),
            _ProfileOption(
              icon: Icons.flag_rounded,
              label: 'Objetivos',
            ),
            _ProfileOption(
              icon: Icons.straighten_rounded,
              label: 'Unidades',
            ),
            _ProfileOption(
              icon: Icons.logout_rounded,
              label: 'Cerrar sesión',
              danger: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.label,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: danger ? AppColors.danger : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}
