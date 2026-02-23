import 'package:flutter/material.dart';

import '../../../core/data/app_preferences.dart';
import '../../common/theme/app_colors.dart';
import '../widgets/settings_widgets.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  AppPreferences? _prefs;
  AppAppearanceMode _selected = AppAppearanceMode.dark;

  @override
  void initState() {
    super.initState();
    AppPreferences.load().then((value) {
      if (!mounted) return;
      setState(() {
        _prefs = value;
        _selected = value.appearanceMode;
      });
    });
  }

  Future<void> _select(AppAppearanceMode mode) async {
    setState(() => _selected = mode);
    await _prefs?.setAppearanceMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: AppAppearanceMode.values
            .map((mode) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.06))),
                  child: RadioListTile<AppAppearanceMode>(
                    value: mode,
                    groupValue: _selected,
                    onChanged: (value) => value == null ? null : _select(value),
                    title: Text(_appearanceLabel(mode)),
                    subtitle: Text(_appearanceHint(mode), style: const TextStyle(color: AppColors.textMuted)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  String _appearanceLabel(AppAppearanceMode mode) {
    switch (mode) {
      case AppAppearanceMode.classic:
        return 'Clásico';
      case AppAppearanceMode.dark:
        return 'Dark Mode';
      case AppAppearanceMode.light:
        return 'Light Mode';
      case AppAppearanceMode.pink:
        return 'Pink Mode';
    }
  }

  String _appearanceHint(AppAppearanceMode mode) {
    switch (mode) {
      case AppAppearanceMode.classic:
        return 'Balanceado y neutro';
      case AppAppearanceMode.dark:
        return 'Contraste en ambientes oscuros';
      case AppAppearanceMode.light:
        return 'Más luminoso para el día';
      case AppAppearanceMode.pink:
        return 'Toque vibrante con acento rosa';
    }
  }
}

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  AppPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    AppPreferences.load().then((v) {
      if (!mounted) return;
      setState(() => _prefs = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsCardGroup(children: [
            SwitchListTile(
              value: prefs.notificationsEnabled,
              onChanged: (v) async {
                await prefs.setNotificationsEnabled(v);
                setState(() {});
              },
              title: const Text('Activar/Desactivar'),
            ),
            const Divider(height: 1),
            _buildSwitch('Recordatorios de hábitos', prefs.habitReminders, (v) => prefs.setHabitReminders(v)),
            _buildSwitch('Recordatorios de entrenamiento', prefs.workoutReminders, (v) => prefs.setWorkoutReminders(v)),
            _buildSwitch('Recordatorios de sueño', prefs.sleepReminders, (v) => prefs.setSleepReminders(v)),
            _buildSwitch('Resumen diario', prefs.dailySummary, (v) => prefs.setDailySummary(v)),
          ]),
          const SizedBox(height: 12),
          const Text('Se activarán cuando el módulo de push notifications esté habilitado.', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, Future<void> Function(bool) onSave) {
    return SwitchListTile(
      value: value,
      onChanged: (v) async {
        await onSave(v);
        setState(() {});
      },
      title: Text(title),
    );
  }
}

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  AppPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    AppPreferences.load().then((value) {
      if (!mounted) return;
      setState(() => _prefs = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y seguridad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsCardGroup(children: [
            SwitchListTile(
              value: prefs.biometricLock,
              onChanged: (v) async {
                await prefs.setBiometricLock(v);
                setState(() {});
              },
              title: const Text('Bloqueo con biometría / PIN'),
              subtitle: const Text('Se habilitará cuando se configure seguridad del dispositivo.'),
            ),
            const Divider(height: 1),
            ListTile(
              title: const Text('Visibilidad de fotos de progreso'),
              subtitle: Text(prefs.progressVisibility == ProgressVisibilityMode.privateOnly ? 'Solo yo' : 'Compartir en grupos'),
              trailing: DropdownButton<ProgressVisibilityMode>(
                value: prefs.progressVisibility,
                underline: const SizedBox.shrink(),
                onChanged: (value) async {
                  if (value == null) return;
                  await prefs.setProgressVisibility(value);
                  setState(() {});
                },
                items: const [
                  DropdownMenuItem(value: ProgressVisibilityMode.privateOnly, child: Text('Solo yo')),
                  DropdownMenuItem(value: ProgressVisibilityMode.groupShared, child: Text('Grupos')),
                ],
              ),
            ),
            const Divider(height: 1),
            SettingsTile(icon: Icons.folder_shared_rounded, title: 'Gestión de datos', onTap: () => Navigator.of(context).pushNamed('/settings/data')),
          ]),
        ],
      ),
    );
  }
}

class DataSettingsScreen extends StatelessWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar e importar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.upload_file_rounded, title: 'Exportar datos (JSON/CSV)', subtitle: 'TODO: conectar con módulo de exportación', onTap: () {}),
            const Divider(height: 1),
            SettingsTile(
              icon: Icons.download_rounded,
              title: 'Importar datos',
              subtitle: 'Puede reemplazar información existente',
              onTap: () async {
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Importar datos'),
                    content: const Text('Próximamente: podrás importar backups de tu cuenta.'),
                    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 12),
          const Text('Nota de privacidad: tus exportaciones pueden contener datos sensibles.', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  AppPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    AppPreferences.load().then((value) {
      if (!mounted) return;
      setState(() => _prefs = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Accesibilidad')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsCardGroup(children: [
            ListTile(
              leading: const Icon(Icons.text_fields_rounded),
              title: const Text('Tamaño de texto'),
              trailing: DropdownButton<AppTextSize>(
                value: prefs.textSize,
                underline: const SizedBox.shrink(),
                onChanged: (value) async {
                  if (value == null) return;
                  await prefs.setTextSize(value);
                  setState(() {});
                },
                items: const [
                  DropdownMenuItem(value: AppTextSize.small, child: Text('Pequeño')),
                  DropdownMenuItem(value: AppTextSize.normal, child: Text('Normal')),
                  DropdownMenuItem(value: AppTextSize.large, child: Text('Grande')),
                ],
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: prefs.highContrast,
              onChanged: (v) async {
                await prefs.setHighContrast(v);
                setState(() {});
              },
              title: const Text('Alto contraste'),
            ),
            SwitchListTile(
              value: prefs.reduceAnimations,
              onChanged: (v) async {
                await prefs.setReduceAnimations(v);
                setState(() {});
              },
              title: const Text('Reducir animaciones'),
            ),
          ]),
        ],
      ),
    );
  }
}

class AboutSettingsScreen extends StatelessWidget {
  const AboutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de nosotros')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SettingsCardGroup(children: [
            SettingsTile(icon: Icons.info_outline_rounded, title: 'Acerca de FIT_APP'),
            Divider(height: 1),
            SettingsTile(icon: Icons.description_outlined, title: 'Términos y condiciones'),
            Divider(height: 1),
            SettingsTile(icon: Icons.privacy_tip_outlined, title: 'Política de privacidad'),
          ]),
          SizedBox(height: 12),
          Text('Versión de la app: ver pubspec.yaml', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
