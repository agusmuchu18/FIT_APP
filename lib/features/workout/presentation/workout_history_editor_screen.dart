import 'package:flutter/material.dart';

import 'widgets/workout_units_host.dart';
import 'widgets/bodyweight_mode_selector.dart';
import 'widgets/sport_measurements_fields.dart';
import '../domain/sport_activity.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/data/repositories.dart';
import '../application/workout_history_mutation_service.dart';
import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';

class WorkoutHistoryEditorScreen extends StatefulWidget {
  const WorkoutHistoryEditorScreen({
    super.key,
    required this.session,
    required this.repository,
    required this.fitness,
    required this.initialRevision,
  });
  final WorkoutSession session;
  final WorkoutRepository repository;
  final FitnessRepository fitness;
  final int initialRevision;
  @override
  State<WorkoutHistoryEditorScreen> createState() =>
      _WorkoutHistoryEditorScreenState();
}

class _WorkoutHistoryEditorScreenState
    extends State<WorkoutHistoryEditorScreen> {
  late final _name = TextEditingController(
        text: widget.session.templateName ?? '',
      ),
      _notes = TextEditingController(text: widget.session.notes ?? ''),
      _duration = TextEditingController(
        text:
            widget.session.durationSeconds?.toString() ??
            (widget.session.durationMinutes == null
                ? ''
                : '${widget.session.durationMinutes! * 60}'),
      );
  late List<WorkoutExercise> _exercises = List.of(widget.session.exercises);
  late bool? _durationIsActive = widget.session.durationIsActive;
  final _invalid = <String>{};
  late final int _revision = widget.initialRevision;
  var _busy = false, _dirty = false, _pending = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _invalid.isNotEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = WorkoutHistoryMutationService(
        widget.repository,
        widget.fitness,
      );
      if (_pending) {
        await service.recover();
      } else {
        final seconds = int.tryParse(_duration.text.trim());
        if (seconds != null &&
            _durationIsActive == true &&
            widget.session.totalDurationSeconds != null &&
            seconds > widget.session.totalDurationSeconds!) {
          throw ArgumentError(
            'El tiempo sin pausas no puede superar el tiempo total registrado.',
          );
        }
        final updated = WorkoutSession.fromJson({
          ...widget.session.toJson(),
          'templateName': _name.text.trim().isEmpty ? null : _name.text.trim(),
          'notes': _notes.text,
          'durationSeconds': seconds,
          'durationMinutes': seconds == null ? null : seconds ~/ 60,
          'durationIsActive': seconds == null ? null : _durationIsActive,
          'exercises': _exercises.map((e) => e.toJson()).toList(),
        });
        await service.correct(updated, expectedRevision: _revision);
      }
      if (mounted) {
        setState(() {
          _dirty = false;
          _pending = false;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.pop(context, true);
      }
    } on HistoryProjectionPending {
      if (mounted) {
        setState(() {
          _pending = true;
          _dirty = false;
          _error = 'El cambio quedó guardado. Falta actualizar el resumen general; reintentá el cierre.';
        });
      }
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } on StateError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo completar el guardado. Tu edición se conserva para reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _set(int exercise, int index, Map<String, dynamic> values) {
    final e = _exercises[exercise];
    setState(() {
      if (values.containsKey('loadType')) {
        _invalid.removeWhere(
          (key) =>
              key.startsWith('$exercise|$index|') &&
              (key.contains('Carga') ||
                  key.contains('Lastre') ||
                  key.contains('Asistencia')),
        );
      }
      _dirty = true;
      _exercises = [..._exercises]
        ..[exercise] = e.copyWith(
          sets: [
            for (var i = 0; i < e.sets.length; i++)
              i == index
                  ? SetEntry.fromJson({...e.sets[i].toJson(), ...values})
                  : e.sets[i],
          ],
        );
    });
  }

  Widget _number(
    String key,
    String label,
    num? value,
    ValueChanged<num?> change, {
    bool integer = false,
    bool positive = true,
  }) => TextFormField(
    key: ValueKey(key),
    initialValue: value?.toString(),
    enabled: !_busy && !_pending,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    decoration: InputDecoration(labelText: label),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (text) {
      if (text?.trim().isEmpty != false) return null;
      final n = num.tryParse(text!.trim().replaceAll(',', '.'));
      return n == null ||
              !n.isFinite ||
              (positive ? n <= 0 : n < 0) ||
              (integer && n != n.round())
          ? 'Revisá este valor'
          : null;
    },
    onChanged: (text) {
      final raw = text.trim().replaceAll(',', '.'),
          n = num.tryParse(text.trim().replaceAll(',', '.'));
      final invalid =
          raw.isNotEmpty &&
          (n == null ||
              !n.isFinite ||
              (positive ? n <= 0 : n < 0) ||
              (integer && n != n.round()));
      setState(() {
        if (invalid) {
          _invalid.add(key);
        } else {
          _invalid.remove(key);
        }
        _dirty = true;
      });
      if (!invalid) change(n);
    },
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content: const Text(
              'Las modificaciones todavía no se aplicaron al historial.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Seguir editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (discard == true && mounted) {
          setState(() => _dirty = false);
          await WidgetsBinding.instance.endOfFrame;
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Corregir sesión'),
          actions: [
            IconButton(
              tooltip: _pending ? 'Reintentar cierre' : 'Guardar corrección',
              onPressed: _busy || _invalid.isNotEmpty ? null : _save,
              icon: const Icon(Icons.check),
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _exercises.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Las correcciones recalculan tus estadísticas y récords. La fecha y la asociación con programas se conservan.',
                  ),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  TextField(
                    controller: _name,
                    enabled: !_busy && !_pending,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de esta sesión',
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    enabled: !_busy && !_pending,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas de la sesión',
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _duration,
                    enabled: !_busy && !_pending,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duración en segundos (opcional)',
                    ),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (text) =>
                        text?.isNotEmpty == true &&
                            (int.tryParse(text!) == null ||
                                int.parse(text) <= 0)
                        ? 'Ingresá segundos positivos'
                        : null,
                    onChanged: (text) => setState(() {
                      _dirty = true;
                      if (text.isNotEmpty &&
                          (int.tryParse(text) == null ||
                              int.parse(text) <= 0)) {
                        _invalid.add('duration');
                      } else {
                        _invalid.remove('duration');
                      }
                    }),
                  ),
                  DropdownButtonFormField<bool?>(
                    initialValue: _durationIsActive,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Qué representa la duración',
                    ),
                    items: const [
                      DropdownMenuItem<bool?>(
                        value: null,
                        child: Text('Criterio histórico no especificado'),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text('Sin pausas; incluye descansos'),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text('Tiempo total transcurrido'),
                      ),
                    ],
                    onChanged: _busy || _pending
                        ? null
                        : (v) => setState(() {
                            _dirty = true;
                            _durationIsActive = v;
                          }),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }
            final e = _exercises[index - 1];
            return _HistoricalExerciseFields(
              exercise: e,
              field:
                  (
                    set,
                    label,
                    value,
                    change, {
                    integer = false,
                    positive = true,
                  }) => _number(
                    '${index - 1}|$set|$label',
                    label,
                    value,
                    change,
                    integer: integer,
                    positive: positive,
                  ),
              onSet: (set, values) => _set(index - 1, set, values),
              onSportChanged: (result) {
                final key = 'sport:${index - 1}';
                setState(() {
                  _dirty = true;
                  if (!e.sportPlan!.resultValid(result)) {
                    _invalid.add(key);
                    return;
                  }
                  _invalid.remove(key);
                  _exercises[index - 1] = e.copyWith(
                    sportResult: result,
                    sets: [
                      for (final s in e.sets)
                        SetEntry.fromJson({
                          ...s.toJson(),
                          'durationSeconds': result!
                              .values[SportMetric.durationSeconds]
                              ?.toInt(),
                        }),
                    ],
                  );
                });
              },
              enabled: !_busy && !_pending,
            );
          },
        ),
      ),
    ),
  );
}

typedef _HistoryNumberField = Widget Function(
  int set,
  String label,
  num? value,
  ValueChanged<num?> change, {
  bool integer,
  bool positive,
});

class _HistoricalExerciseFields extends StatefulWidget {
  const _HistoricalExerciseFields({
    required this.exercise,
    required this.field,
    required this.onSet,
    required this.enabled,
    required this.onSportChanged,
  });
  final WorkoutExercise exercise;
  final _HistoryNumberField field;
  final void Function(int, Map<String, dynamic>) onSet;
  final bool enabled;
  final ValueChanged<SportMeasurements?> onSportChanged;
  @override
  State<_HistoricalExerciseFields> createState() =>
      _HistoricalExerciseFieldsState();
}

class _HistoricalExerciseFieldsState extends State<_HistoricalExerciseFields> {
  var _limit = 30;
  final _sportDraft = SportMeasurementsDraft();
  List<Widget> _loadFields(int index) {
    final e = widget.exercise, s = e.sets[index];
    final body = WorkoutAnalytics.isBodyweight(e);
    final mode =
        s.loadType ??
        WorkoutAnalytics.setLoadType(e, s) ??
        (body ? RoutineExerciseLoadType.bodyweight : e.targetLoadType);
    final units = WorkoutUnits.of(context);
    final assisted = mode == RoutineExerciseLoadType.assistedKg;
    final value = assisted ? s.assistanceKg : s.externalLoadKg;
    final label = s.loadIsAmbiguous
        ? 'Carga sin clasificar'
        : assisted
        ? 'Asistencia'
        : mode == RoutineExerciseLoadType.addedWeightKg
        ? 'Lastre'
        : 'Carga externa';
    return [
      if (body)
        BodyweightModeSelector(
          value: mode,
          onChanged: !widget.enabled
              ? null
              : (type) => widget.onSet(index, {'loadType': type.name}),
          disclosure: true,
        ),
      if (s.loadIsAmbiguous || WorkoutAnalytics.setLoadType(e, s) == null)
        Text(
          'Carga antigua sin clasificar: ${s.externalLoadKg == null ? "sin valor" : units.valueWithUnit("kg", s.externalLoadKg!)}. Se conserva sin contar como lastre ni volumen externo.',
        ),
      if (mode != RoutineExerciseLoadType.bodyweight &&
          e.measurement != 'distance' &&
          (!WorkoutAnalytics.isTimed(e) || body))
        widget.field(
          index,
          '$label (${units.weight.label})',
          value == null ? null : units.weight.fromKg(value),
          (n) => widget.onSet(index, {
            assisted ? 'assistanceKg' : 'externalLoadKg': n == null
                ? null
                : units.weight.toKg(n),
          }),
          positive: false,
        ),
      if (s.loadIsAmbiguous)
        CheckboxListTile(
          title: const Text('Confirmo que la carga corregida es verificable'),
          value: false,
          onChanged: !widget.enabled
              ? null
              : (v) => widget.onSet(index, {
                  'loadIsAmbiguous': v != true,
                  if (v == true) 'loadType': mode.name,
                }),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;
    final units = WorkoutUnits.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(e.name),
        subtitle: Text('${e.sets.length} series'),
        children: [
          if (e.sportPlan != null)
            Padding(
              padding: EdgeInsets.all(16),
              child:
                  footballActivities.any((a) => a.id == e.sportPlan!.activityId)
                  ? SportMeasurementsFields(
                      activity: footballActivities.firstWhere(
                        (a) => a.id == e.sportPlan!.activityId,
                      ),
                      initial: e.sportResult ?? SportMeasurements(),
                      draft: _sportDraft,
                      enabled: widget.enabled,
                      onChanged: widget.onSportChanged,
                    )
                  : const Text(
                      'Esta actividad ya no está en el catálogo. Se conservan sus mediciones originales.',
                    ),
            )
          else
            for (var i = 0; i < e.sets.length && i < _limit; i++)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Serie ${i + 1}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        e.sets[i].done == null
                            ? 'Finalización histórica sin confirmar'
                            : 'Serie completada',
                      ),
                      tristate: true,
                      value: e.sets[i].done,
                      onChanged: !widget.enabled
                          ? null
                          : (v) => widget.onSet(i, {'done': v}),
                    ),
                    ..._loadFields(i),
                    if (!WorkoutAnalytics.isTimed(e) &&
                        e.measurement != 'distance') ...[
                      widget.field(
                        i,
                        'Repeticiones',
                        e.sets[i].reps,
                        (n) => widget.onSet(i, {'reps': n?.toInt()}),
                        integer: true,
                      ),
                    ] else
                      widget.field(
                        i,
                        e.measurement == 'distance'
                            ? 'Distancia (${units.distance.label})'
                            : 'Duración (s)',
                        e.measurement == 'distance'
                            ? e.sets[i].distanceMeters == null
                                  ? null
                                  : units.distance.fromMeters(
                                      e.sets[i].distanceMeters!,
                                    )
                            : e.sets[i].durationSeconds,
                        (n) => widget.onSet(i, {
                          e.measurement == 'distance'
                              ? 'distanceMeters'
                              : 'durationSeconds': e.measurement == 'distance'
                              ? n == null
                                    ? null
                                    : units.distance.toMeters(n)
                              : n?.toInt(),
                        }),
                        integer: e.measurement != 'distance',
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
          if (e.sets.length > _limit)
            TextButton(
              onPressed: () => setState(() => _limit += 30),
              child: const Text('Ver 30 series más'),
            ),
        ],
      ),
    );
  }
}
