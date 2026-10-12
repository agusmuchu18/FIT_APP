import 'package:flutter/material.dart';

import '../data/workout_preferences.dart';

class WorkoutSettingsScreen extends StatefulWidget {
  const WorkoutSettingsScreen({super.key});

  @override
  State<WorkoutSettingsScreen> createState() => _WorkoutSettingsScreenState();
}

class _WorkoutSettingsScreenState extends State<WorkoutSettingsScreen> {
  WorkoutPreferences? _preferences;
  Object? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await WorkoutPreferences.load();
      if (mounted) setState(() => _preferences = preferences);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _save(WorkoutPreferences next) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await next.save();
      if (mounted) setState(() => _preferences = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron guardar los ajustes.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    final durations = <int>{60, 90, 120, 180};
    if (preferences != null) durations.add(preferences.defaultRestSeconds);
    final sortedDurations = durations.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes de entrenamiento')),
      body: _loadError != null
          ? Center(
              child: TextButton(
                onPressed: () {
                  setState(() => _loadError = null);
                  _load();
                },
                child: const Text(
                  'No se pudieron cargar los ajustes. Reintentar',
                ),
              ),
            )
          : preferences == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Descanso entre series',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estos valores se aplican a los ejercicios que agregues en sesiones nuevas. Podés cambiarlos en cada ejercicio.',
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  title: const Text('Activar descanso predeterminado'),
                  value: preferences.defaultRestEnabled,
                  onChanged: _saving
                      ? null
                      : (enabled) => _save(
                          preferences.copyWith(defaultRestEnabled: enabled),
                        ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(preferences.defaultRestSeconds),
                  initialValue: preferences.defaultRestSeconds,
                  decoration: const InputDecoration(
                    labelText: 'Duración predeterminada',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final seconds in sortedDurations)
                      DropdownMenuItem(
                        value: seconds,
                        child: Text('$seconds segundos'),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (seconds) {
                          if (seconds != null) {
                            _save(
                              preferences.copyWith(defaultRestSeconds: seconds),
                            );
                          }
                        },
                ),
              ],
            ),
    );
  }
}
