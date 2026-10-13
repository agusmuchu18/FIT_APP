import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

import '../domain/routine_labels.dart';
import '../domain/sport_activity.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import '../presentation/widgets/sport_measurements_fields.dart';
import '../presentation/widgets/workout_rest_selector.dart';

Future<WorkoutExercise?> showExerciseConfiguration(
  BuildContext context,
  WorkoutExercise exercise, {
  ExerciseDefinition? definition,
  String action = 'Guardar configuración',
  bool sportGym = false,
}) => showModalBottomSheet<WorkoutExercise>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: Theme(
      data: AppTheme.workout,
      child: ExerciseConfigurationSheet(
        exercise: exercise,
        definition: definition,
        action: action,
        sportGym: sportGym,
      ),
    ),
  ),
);

class ExerciseConfigurationSheet extends StatefulWidget {
  const ExerciseConfigurationSheet({
    super.key,
    required this.exercise,
    this.definition,
    required this.action,
    this.sportGym = false,
  });
  final WorkoutExercise exercise;
  final ExerciseDefinition? definition;
  final String action;
  final bool sportGym;
  @override
  State<ExerciseConfigurationSheet> createState() =>
      _ExerciseConfigurationSheetState();
}

class _ExerciseConfigurationSheetState
    extends State<ExerciseConfigurationSheet> {
  final _form = GlobalKey<FormState>();
  late WorkoutExercise _value = widget.exercise;
  late final _sets = TextEditingController(text: '${_value.targetSets}');
  late final _reps = TextEditingController(text: '${_value.targetReps ?? 10}');
  late final _min = TextEditingController(text: '${_value.targetRepsMin ?? 8}');
  late final _max = TextEditingController(
    text: '${_value.targetRepsMax ?? 12}',
  );
  late final _seconds = TextEditingController(
    text: '${_value.targetDurationSeconds ?? 30}',
  );
  late final _weight = TextEditingController(
    text: _value.targetWeightKg?.toString() ?? '',
  );
  late bool _range = _value.targetReps == null;
  late List<RoutineSetTarget> _targets = [..._value.setTargets];
  SportMeasurements? _sportTargets;
  bool _invalidSport = false;
  @override
  void dispose() {
    for (final c in [_sets, _reps, _min, _max, _seconds, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  WorkoutExercise get _preview => _value.copyWith(
    targetSets: int.tryParse(_sets.text),
    targetReps: _range || _value.isTimed ? null : int.tryParse(_reps.text),
    clearTargetReps: _range || _value.isTimed,
    targetRepsMin: int.tryParse(_min.text),
    targetRepsMax: int.tryParse(_max.text),
    targetDurationSeconds: int.tryParse(_seconds.text),
    targetWeightKg: double.tryParse(_weight.text.replaceAll(',', '.')),
    clearTargetWeightKg: _weight.text.isEmpty,
    setTargets: _targets,
  );

  String? _positive(String? v, {int max = 9999}) {
    final n = int.tryParse(v ?? '');
    return n != null && n > 0 && n <= max
        ? null
        : 'Usá un entero entre 1 y $max';
  }

  Widget _number(String label, TextEditingController c, {int max = 9999}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
          validator: (v) => _positive(v, max: max),
          onChanged: (_) => setState(() {}),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final activity = footballActivities
        .where((e) => e.id == _value.sportPlan?.activityId)
        .firstOrNull;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .92,
      child: Form(
        key: _form,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Center(child: ExerciseThumbnail(exercise: _value, size: 180)),
                  const SizedBox(height: 16),
                  Text(
                    RoutineLabels.exerciseName(_value.name),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    activity != null
                        ? 'Fútbol · ${activity.mode.label}'
                        : '${definition?.primaryMuscles.join(', ') ?? _value.muscleGroup ?? 'Músculo sin datos'} · ${RoutineLabels.equipmentName(_value.equipment)}',
                  ),
                  if (!ExerciseArtRegistry.specific.contains(_value.id))
                    const Text(
                      'Ilustración genérica de categoría',
                      style: TextStyle(fontSize: 12),
                    ),
                  if (definition != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Músculos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Principales: ${definition.primaryMuscles.isEmpty ? 'Sin datos' : definition.primaryMuscles.join(', ')}',
                    ),
                    Text(
                      'Secundarios: ${definition.secondaryMuscles.isEmpty ? 'Sin datos' : definition.secondaryMuscles.join(', ')}',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Técnica',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _technique[_value.id] ?? 'El catálogo no incluye una ficha técnica revisada para este ejercicio. Consultá una demostración profesional antes de practicar un movimiento nuevo.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Objetivos de la rutina',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (activity != null) ...[
                    Text(activity.description),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _value.sportPlan!.objective,
                      decoration: const InputDecoration(
                        labelText: 'Objetivo / descripción',
                      ),
                      onChanged: (v) => _value = _value.copyWith(
                        sportPlan: SportActivityPlan(
                          activityId: activity.id,
                          mode: activity.mode,
                          targets: _sportTargets ?? _value.sportPlan!.targets,
                          objective: v,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SportMeasurementsFields(
                      activity: activity,
                      initial: _value.sportPlan!.targets,
                      onChanged: (v) {
                        _sportTargets = v;
                        _invalidSport = v == null;
                      },
                    ),
                  ] else ...[
                    if (widget.sportGym) ...[
                      DropdownButtonFormField<FootballGymPurpose>(
                        initialValue: _value.sportPurpose,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo deportivo (opcional)',
                        ),
                        isExpanded: true,
                        items: [
                          for (final p in FootballGymPurpose.values)
                            DropdownMenuItem(value: p, child: Text(p.label)),
                        ],
                        onChanged: (p) => setState(
                          () => _value = _value.copyWith(sportPurpose: p),
                        ),
                      ),
                      const Text(
                        'Esta etiqueta organiza tu plan; no estima beneficios ni rendimiento.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            final n = int.tryParse(_sets.text) ?? 3;
                            if (n > 1) setState(() => _sets.text = '${n - 1}');
                          },
                          tooltip: 'Quitar una serie',
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(child: _number('Series', _sets, max: 30)),
                        IconButton(
                          onPressed: () {
                            final n = int.tryParse(_sets.text) ?? 3;
                            if (n < 30) setState(() => _sets.text = '${n + 1}');
                          },
                          tooltip: 'Agregar una serie',
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    if (_value.isTimed)
                      _number('Duración objetivo (segundos)', _seconds)
                    else ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('Fijas')),
                          ButtonSegment(value: true, label: Text('Rango')),
                        ],
                        selected: {_range},
                        onSelectionChanged: (v) =>
                            setState(() => _range = v.first),
                      ),
                      const SizedBox(height: 12),
                      if (_range) ...[
                        _number('Mínimo de repeticiones', _min),
                        _number('Máximo de repeticiones', _max),
                      ] else
                        _number('Repeticiones objetivo', _reps),
                    ],
                    DropdownButtonFormField<RoutineExerciseLoadType>(
                      initialValue: _value.targetLoadType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de carga',
                      ),
                      items: [
                        for (final type in RoutineExerciseLoadType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(RoutineLabels.load(type)),
                          ),
                      ],
                      onChanged: (type) {
                        if (type != null) {
                          setState(() {
                            _value = _value.copyWith(
                              targetLoadType: type,
                              clearTargetWeightKg:
                                  type == RoutineExerciseLoadType.bodyweight,
                            );
                            if (type == RoutineExerciseLoadType.bodyweight) {
                              _weight.clear();
                            }
                          });
                        }
                      },
                    ),
                    if (_value.targetLoadType !=
                        RoutineExerciseLoadType.bodyweight) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _weight,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              '${RoutineLabels.load(_value.targetLoadType)} objetivo (kg)',
                        ),
                        validator: (v) {
                          if (v?.trim().isEmpty != false) return null;
                          final n = double.tryParse(v!.replaceAll(',', '.'));
                          return n != null && n.isFinite && n >= 0
                              ? null
                              : 'Carga inválida';
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Objetivos por serie'),
                      subtitle: const Text(
                        'Los objetivos individuales se conservan al cambiar los generales.',
                      ),
                      value: _targets.isNotEmpty,
                      onChanged: (enabled) => setState(
                        () => _targets = enabled
                            ? List.generate(
                                int.tryParse(_sets.text)?.clamp(1, 30) ?? 3,
                                (_) => RoutineSetTarget(
                                  reps: _range || _value.isTimed
                                      ? null
                                      : int.tryParse(_reps.text),
                                  repsMin: _range && !_value.isTimed
                                      ? int.tryParse(_min.text)
                                      : null,
                                  repsMax: _range && !_value.isTimed
                                      ? int.tryParse(_max.text)
                                      : null,
                                  weightKg: double.tryParse(
                                    _weight.text.replaceAll(',', '.'),
                                  ),
                                  durationSeconds: _value.isTimed
                                      ? int.tryParse(_seconds.text)
                                      : null,
                                ),
                              )
                            : [],
                      ),
                    ),
                    for (var i = 0; i < _targets.length; i++) _individual(i),
                  ],
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Heredar descanso de la sesión'),
                    value:
                        _value.restSeconds == null &&
                        _value.restEnabled != false,
                    onChanged: (inherit) => setState(
                      () => _value = _value.copyWith(
                        restEnabled: true,
                        restSeconds: inherit ? null : 90,
                        clearRestSeconds: inherit,
                      ),
                    ),
                  ),
                  if (_value.restSeconds != null || _value.restEnabled == false)
                    WorkoutRestSelector(
                      enabled: _value.restEnabled != false,
                      seconds: _value.restSeconds ?? 90,
                      onToggle: (v) => setState(
                        () => _value = _value.copyWith(restEnabled: v),
                      ),
                      onChanged: (v) => setState(
                        () => _value = _value.copyWith(restSeconds: v),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(RoutineLabels.summary(_preview)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _apply,
                    child: Text(widget.action),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _individual(int index) {
    final target = _targets[index];
    Widget number(String label, int? value, void Function(int?) change) =>
        TextFormField(
          initialValue: value?.toString() ?? '',
          decoration: InputDecoration(labelText: '$label · serie ${index + 1}'),
          keyboardType: TextInputType.number,
          validator: _positive,
          onChanged: (v) => setState(() => change(int.tryParse(v))),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Serie ${index + 1}'),
          if (_value.isTimed)
            number(
              'Segundos',
              target.durationSeconds,
              (v) => _targets[index] = RoutineSetTarget(
                durationSeconds: v,
                weightKg: target.weightKg,
              ),
            )
          else if (target.repsMin != null && target.reps == null) ...[
            number(
              'Repeticiones mínimas',
              target.repsMin,
              (v) => _targets[index] = RoutineSetTarget(
                repsMin: v,
                repsMax: target.repsMax,
                weightKg: target.weightKg,
              ),
            ),
            number(
              'Repeticiones máximas',
              target.repsMax,
              (v) => _targets[index] = RoutineSetTarget(
                repsMin: target.repsMin,
                repsMax: v,
                weightKg: target.weightKg,
              ),
            ),
          ] else
            number(
              'Repeticiones',
              target.reps,
              (v) => _targets[index] = RoutineSetTarget(
                reps: v,
                weightKg: target.weightKg,
              ),
            ),
          if (_value.targetLoadType != RoutineExerciseLoadType.bodyweight)
            TextFormField(
              initialValue: target.weightKg?.toString() ?? '',
              decoration: InputDecoration(
                labelText:
                    '${RoutineLabels.load(_value.targetLoadType)} (kg) · serie ${index + 1}',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v?.trim().isEmpty != false) return null;
                final n = double.tryParse(v!.replaceAll(',', '.'));
                return n != null && n.isFinite && n >= 0
                    ? null
                    : 'Carga inválida';
              },
              onChanged: (v) => setState(
                () => _targets[index] = RoutineSetTarget(
                  reps: target.reps,
                  repsMin: target.repsMin,
                  repsMax: target.repsMax,
                  durationSeconds: target.durationSeconds,
                  weightKg: double.tryParse(v.replaceAll(',', '.')),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _apply() {
    if (!_form.currentState!.validate() || _invalidSport) return;
    if (_value.sportPlan != null) {
      final p = _value.sportPlan!;
      Navigator.pop(
        context,
        _value.copyWith(
          sportPlan: SportActivityPlan(
            activityId: p.activityId,
            mode: p.mode,
            targets: _sportTargets ?? p.targets,
            objective: p.objective,
          ),
        ),
      );
      return;
    }
    if (_range &&
        !_value.isTimed &&
        int.parse(_max.text) < int.parse(_min.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El máximo no puede ser menor que el mínimo.'),
        ),
      );
      return;
    }
    if (_targets.any(
      (t) =>
          t.repsMin != null && (t.repsMax == null || t.repsMax! < t.repsMin!),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisá el rango de repeticiones de cada serie.'),
        ),
      );
      return;
    }
    final sets = int.parse(_sets.text);
    if (_targets.isNotEmpty && _targets.length != sets) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La cantidad de series debe coincidir con los objetivos individuales.',
          ),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _value.copyWith(
        targetSets: sets,
        targetReps: _range || _value.isTimed ? null : int.parse(_reps.text),
        clearTargetReps: _range || _value.isTimed,
        targetRepsMin: _range ? int.parse(_min.text) : int.parse(_reps.text),
        targetRepsMax: _range ? int.parse(_max.text) : int.parse(_reps.text),
        targetDurationSeconds: _value.isTimed ? int.parse(_seconds.text) : null,
        targetWeightKg:
            _value.targetLoadType == RoutineExerciseLoadType.bodyweight
            ? null
            : double.tryParse(_weight.text.replaceAll(',', '.')),
        clearTargetWeightKg:
            _value.targetLoadType == RoutineExerciseLoadType.bodyweight ||
            _weight.text.isEmpty,
        setTargets: _targets,
      ),
    );
  }
}

const _technique = {
  'bench_press': 'Inicio: acostado en banco, pies apoyados y agarre estable. Ejecución: bajá la barra de forma controlada y empujá. Evitá rebotar la barra; usá soportes y asistencia adecuados.',
  'pull_up': 'Inicio: agarre prono de la barra. Ejecución: elevá el cuerpo de forma controlada y descendé sin dejarte caer. Evitá balanceos para completar repeticiones.',
  'back_squat': 'Inicio: barra apoyada en la parte alta de la espalda y pies firmes. Ejecución: flexioná cadera y rodillas con control; volvé a extender. Mantené una profundidad que puedas controlar.',
  'deadlift': 'Inicio: barra cerca de las piernas y agarre firme. Ejecución: extendé cadera y rodillas manteniendo la barra próxima al cuerpo. Evitá tirones y movimientos bruscos.',
  'military_press': 'Inicio: de pie, barra delante de los hombros. Ejecución: empujá por encima de la cabeza y bajá con control. Evitá compensar con una extensión excesiva del tronco.',
  'plank': 'Inicio: antebrazos y puntas de pies apoyados. Mantené el cuerpo alineado y respiración regular. Finalizá cuando no puedas sostener una posición controlada.',
};
