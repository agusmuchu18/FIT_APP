import 'package:flutter/material.dart';

import '../../core/data/app_preferences.dart';
import '../common/theme/app_colors.dart';
import '../profile/profile_settings_screen.dart';
import 'widgets/settings_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    AppPreferences.load().then((value) {
      if (!mounted) return;
      setState(() => _prefs = value);
    });
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro querés cerrar sesión ahora?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/auth/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final appearance = _prefs?.appearanceMode.name ?? 'dark';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'CUENTA'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.person_rounded, title: 'Editar perfil', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()))),
            const Divider(height: 1),
            const SettingsTile(icon: Icons.workspace_premium_rounded, title: 'Suscripción / Plan', subtitle: 'Premium activo'),
            const Divider(height: 1),
            const SettingsTile(icon: Icons.flag_rounded, title: 'Objetivos', subtitle: 'Mantener constancia y mejorar composición'),
          ]),
          const SectionHeader(title: 'VISUALIZACIÓN'),
          SettingsCardGroup(children: [
            SettingsTile(
              icon: Icons.palette_rounded,
              title: 'Tema / estilo',
              subtitle: 'Modo: $appearance',
              onTap: () => Navigator.of(context).pushNamed('/settings/appearance'),
            ),
          ]),
          const SectionHeader(title: 'NOTIFICACIONES'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.notifications_rounded, title: 'Preferencias de notificaciones', onTap: () => Navigator.of(context).pushNamed('/settings/notifications')),
          ]),
          const SectionHeader(title: 'PRIVACIDAD Y SEGURIDAD'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.lock_rounded, title: 'Privacidad y seguridad', onTap: () => Navigator.of(context).pushNamed('/settings/privacy')),
          ]),
          const SectionHeader(title: 'INTEGRACIONES A DISPOSITIVOS'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.watch_rounded, title: 'Integraciones', onTap: () => Navigator.of(context).pushNamed('/settings/integrations')),
          ]),
          const SectionHeader(title: 'EXPORTAR E IMPORTAR DATOS'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.sync_alt_rounded, title: 'Datos', onTap: () => Navigator.of(context).pushNamed('/settings/data')),
          ]),
          const SectionHeader(title: 'ACCESIBILIDAD'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.accessibility_new_rounded, title: 'Opciones de accesibilidad', onTap: () => Navigator.of(context).pushNamed('/settings/accessibility')),
          ]),
          const SectionHeader(title: 'ACERCA DE NOSOTROS'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.info_rounded, title: 'Acerca de FIT_APP', onTap: () => Navigator.of(context).pushNamed('/settings/about')),
          ]),
          const SectionHeader(title: 'ZONA DE PELIGRO'),
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.logout_rounded, title: 'Cerrar sesión', danger: true, onTap: _confirmLogout),
            const Divider(height: 1),
            const SettingsTile(icon: Icons.delete_forever_rounded, title: 'Eliminar cuenta', subtitle: 'Próximamente', danger: true),
          ]),
        ],
      ),
    );
  }
}
