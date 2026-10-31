import 'package:flutter/material.dart';

import '../data/workout_preferences.dart';
import '../domain/training_units.dart';
import '../../../core/data/account_storage_scope.dart';

class WorkoutSettingsScreen extends StatefulWidget {
  const WorkoutSettingsScreen({super.key});

  @override
  State<WorkoutSettingsScreen> createState() => _WorkoutSettingsScreenState();
}

class _WorkoutSettingsScreenState extends State<WorkoutSettingsScreen> {
  WorkoutPreferences? _preferences;
  Object? _loadError;
  bool _saving = false;
  final _scope = AccountStorageScope.current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final preferences = await WorkoutPreferences.load(scope: _scope);
      if (mounted) setState(() => _preferences = preferences);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _save(WorkoutPreferences next) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await next.save(scope: _scope);
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
                  'Unidades de presentación',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Cambiar estas unidades conserva los registros originales. Las cargas se convierten al ingresar y al mostrar resultados.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WeightUnit>(
                  key: ValueKey(preferences.units.weight),
                  initialValue: preferences.units.weight,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unidad de carga',
                  ),
                  items: [
                    for (final unit in WeightUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                  ],
                  onChanged: _saving
                      ? null
                      : (unit) {
                          if (unit != null) {
                            _save(
                              preferences.copyWith(
                                units: TrainingUnits(
                                  weight: unit,
                                  distance: preferences.units.distance,
                                ),
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DistanceUnit>(
                  key: ValueKey(preferences.units.distance),
                  initialValue: preferences.units.distance,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Unidad de distancia',
                  ),
                  items: [
                    for (final unit in DistanceUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                  ],
                  onChanged: _saving
                      ? null
                      : (unit) {
                          if (unit != null) {
                            _save(
                              preferences.copyWith(
                                units: TrainingUnits(
                                  weight: preferences.units.weight,
                                  distance: unit,
                                ),
                              ),
                            );
                          }
                        },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  key: ValueKey(
                    '${preferences.units.weight}|${preferences.loadIncrementKg}',
                  ),
                  initialValue: preferences.loadIncrementKg,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Paso de los botones de carga',
                  ),
                  items: [
                    for (final kg in <double>{
                      preferences.loadIncrementKg,
                      for (final display in [0.5, 1.0, 2.5, 5.0, 10.0])
                        preferences.units.weight.toKg(display),
                    })
                      DropdownMenuItem(
                        value: kg,
                        child: Text(
                          '${TrainingUnits.number(preferences.units.weight.fromKg(kg))} ${preferences.units.weight.label}',
                        ),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (kg) {
                          if (kg != null) {
                            _save(preferences.copyWith(loadIncrementKg: kg));
                          }
                        },
                ),
                const SizedBox(height: 24),
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
