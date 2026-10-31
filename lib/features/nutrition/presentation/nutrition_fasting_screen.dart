import 'widgets/nutrition_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/nutrition_day_repository.dart';

class NutritionFastingScreen extends StatefulWidget {
  const NutritionFastingScreen({super.key, required this.repository});
  final NutritionDayRepository repository;
  @override
  State<NutritionFastingScreen> createState() => _NutritionFastingScreenState();
}

class _NutritionFastingScreenState extends State<NutritionFastingScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _rows = [];
  bool _enabled = false, _loading = true, _busy = false;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.repository.fastingHistory();
      final enabled = await widget.repository.fastingEnabled();
      if (mounted) {
        setState(() {
          _rows = rows;
          _enabled = enabled;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo abrir el registro. Tus datos se conservan.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. Si hay un registro activo, finalizalo antes de desactivar.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _duration(Map<String, dynamic> row) {
    final start = DateTime.parse(row['start'] as String);
    final end = row['end'] == null
        ? DateTime.now()
        : DateTime.parse(row['end'] as String);
    final minutes = end.difference(start).inMinutes.clamp(0, 999999);
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  @override
  Widget build(BuildContext context) {
    final active = _rows.where((r) => r['end'] == null).firstOrNull;
    return NutritionTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ventanas de ayuno')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: TextButton(
                  onPressed: _load,
                  child: Text('$_error Reintentar'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Herramienta opcional de registro, sin objetivos automáticos ni recomendaciones de restricción.',
                  ),
                  SwitchListTile(
                    title: const Text('Habilitar registro'),
                    value: _enabled,
                    onChanged: _busy
                        ? null
                        : (v) => _act(
                            () => widget.repository.setFastingEnabled(v),
                          ),
                  ),
                  if (_enabled)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              active == null
                                  ? 'Sin ventana activa'
                                  : _duration(active),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _busy
                                  ? null
                                  : () => _act(
                                      () => active == null
                                          ? widget.repository.startFast()
                                          : widget.repository.finishFast(),
                                    ),
                              child: Text(
                                active == null
                                    ? 'Registrar inicio ahora'
                                    : 'Registrar finalización ahora',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    'Historial privado',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_rows.isEmpty)
                    const Text('Todavía no registraste ventanas.'),
                  for (final row in _rows)
                    ListTile(
                      title: Text(_duration(row)),
                      subtitle: Text(
                        'Inicio: ${DateFormat.yMd('es').add_Hm().format(DateTime.parse(row['start'] as String).toLocal())}\n${row['end'] == null ? 'En curso' : 'Fin: ${DateFormat.yMd('es').add_Hm().format(DateTime.parse(row['end'] as String).toLocal())}'}',
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
