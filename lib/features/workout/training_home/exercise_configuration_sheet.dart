import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

import '../domain/routine_labels.dart';
import '../domain/workout_analytics.dart';
import '../presentation/widgets/bodyweight_mode_selector.dart';
import '../domain/routine_plan_validation.dart';
import '../domain/exercise_technique.dart';
import '../domain/sport_activity.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import '../presentation/widgets/sport_measurements_fields.dart';
import '../presentation/widgets/workout_rest_selector.dart';
import '../presentation/widgets/workout_units_host.dart';
import '../domain/training_units.dart';

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
      data: AppTheme.workoutFor(Theme.of(context)),
      child: ExerciseConfigurationSheet(
        exercise: exercise,
        definition: definition,
        action: action,
        sportGym: sportGym,
      ),
    ),
  ),
);

/// Ephemeral raw form state. Valid selected values belong to RoutineDraftController.
/// Kept by the explorer, so lazy rows may unmount without losing unfinished input.
class ExerciseConfigurationMemory {
  WorkoutExercise? value;
  bool? range;
  List<RoutineSetTarget>? targets;
  final raw = <String, String>{};
  final sport = SportMeasurementsDraft();
  WeightUnit? weightUnit;
  bool valid = true;
  bool? advanced;
}

class ExerciseConfigurationSheet extends StatefulWidget {
  const ExerciseConfigurationSheet({
    super.key,
    required this.exercise,
    this.definition,
    required this.action,
    this.sportGym = false,
    this.inline = false,
    this.memory,
    this.onChanged,
  });
  final WorkoutExercise exercise;
  final ExerciseDefinition? definition;
  final String action;
  final bool sportGym;
  final bool inline;
  final ExerciseConfigurationMemory? memory;
  final ValueChanged<WorkoutExercise?>? onChanged;
  @override
  State<ExerciseConfigurationSheet> createState() =>
      _ExerciseConfigurationSheetState();
}

class _ExerciseConfigurationSheetState
    extends State<ExerciseConfigurationSheet> {
  final _form = GlobalKey<FormState>();
  late final _memory = widget.memory ?? ExerciseConfigurationMemory();
  late WorkoutExercise _value = _memory.value ?? widget.exercise;
  late final _sets = TextEditingController(
    text: _memory.raw['sets'] ?? '${_value.targetSets}',
  );
  late final _reps = TextEditingController(
    text: _memory.raw['reps'] ?? '${_value.targetReps ?? 10}',
  );
  late final _min = TextEditingController(
    text: _memory.raw['min'] ?? '${_value.targetRepsMin ?? 8}',
  );
  late final _max = TextEditingController(
    text: _memory.raw['max'] ?? '${_value.targetRepsMax ?? 12}',
  );
  late final _seconds = TextEditingController(
    text: _memory.raw['seconds'] ?? '${_value.targetDurationSeconds ?? 30}',
  );
  late final _weight = TextEditingController(
    text:
        _memory.raw['weight'] ??
        (_value.targetLoadType == RoutineExerciseLoadType.assistedKg &&
                _value.loadSchemaVersion == 0 &&
                _value.targetAssistanceKg == null
            ? ''
            : _value.targetWeightKg?.toString()) ??
        '',
  );
  late final _assistance = TextEditingController(
    text:
        _memory.raw['assistance'] ??
        (_value.targetLoadType == RoutineExerciseLoadType.assistedKg
                ? _value.plannedLoad
                : _value.targetAssistanceKg)
            ?.toString() ??
        '',
  );
  bool get _bodyweight => WorkoutAnalytics.isBodyweight(_value);
  TextEditingController get _activeWeight =>
      _value.targetLoadType == RoutineExerciseLoadType.assistedKg
      ? _assistance
      : _weight;
  double? _loadValue(String raw, double? original) {
    if (raw == _displayWeight(original)) return original;
    final n = double.tryParse(raw.replaceAll(',', '.'));
    return n == null ? null : _weightUnit.toKg(n);
  }

  late bool _range = _memory.range ?? (_value.targetReps == null);
  late List<RoutineSetTarget> _targets = [
    for (final target in _memory.targets ?? _value.setTargets)
      if (_value.loadSchemaVersion == 0 &&
          target.loadType == null &&
          _value.targetLoadType == RoutineExerciseLoadType.assistedKg &&
          target.assistanceKg == null)
        target.copyWith(
          loadType: RoutineExerciseLoadType.assistedKg,
          assistanceKg: target.weightKg,
          clearWeight: true,
        )
      else
        target,
  ];
  SportMeasurements? _sportTargets;
  late bool _invalidSport = _value.sportPlan != null && !_memory.valid;
  WeightUnit get _weightUnit => WorkoutUnits.of(context).weight;

  String _displayWeight(double? value) => value == null
      ? ''
      : _weightUnit
            .fromKg(value)
            .toStringAsFixed(4)
            .replaceFirst(RegExp(r'\.?0+$'), '');
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = _weightUnit;
    final previous = _memory.weightUnit ?? WeightUnit.kg;
    if (next != previous) {
      String convert(String raw) {
        final value = double.tryParse(raw.replaceAll(',', '.'));
        return value == null
            ? raw
            : next
                  .fromKg(previous.toKg(value))
                  .toStringAsFixed(4)
                  .replaceFirst(RegExp(r'\.?0+$'), '');
      }

      _weight.text = convert(_weight.text);
      _assistance.text = convert(_assistance.text);
      for (final key in _memory.raw.keys.toList()) {
        if (key == 'weight' ||
            key == 'assistance' ||
            key.endsWith(':weight') ||
            key.endsWith(':assistance')) {
          _memory.raw[key] = convert(_memory.raw[key]!);
        }
      }
    }
    _memory.weightUnit = next;
  }

  @override
  void dispose() {
    for (final c in [
      _sets,
      _reps,
      _min,
      _max,
      _seconds,
      _weight,
      _assistance,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _change(VoidCallback update) {
    setState(update);
    _memory.value = _value;
    _memory.range = _range;
    _memory.targets = [..._targets];
    for (final entry in {
      'sets': _sets,
      'reps': _reps,
      'min': _min,
      'max': _max,
      'seconds': _seconds,
      'weight': _weight,
      'assistance': _assistance,
    }.entries) {
      _memory.raw[entry.key] = entry.value.text;
    }
    final candidate = _validValue;
    _memory.valid = candidate != null;
    widget.onChanged?.call(candidate);
  }

  WorkoutExercise? get _validValue {
    if (_invalidSport) return null;
    if (_value.sportPlan case final plan?) {
      final value = _value.copyWith(
        sportPlan: SportActivityPlan(
          activityId: plan.activityId,
          mode: plan.mode,
          targets: _sportTargets ?? plan.targets,
          objective: plan.objective,
        ),
      );
      return RoutinePlanValidation.error(value) == null ? value : null;
    }
    if (_positive(_sets.text, max: 30) != null ||
        (_value.isTimed
            ? _positive(_seconds.text) != null
            : _range
            ? _positive(_min.text) != null || _positive(_max.text) != null
            : _positive(_reps.text) != null)) {
      return null;
    }
    bool validWeight(String raw) {
      final n = double.tryParse(raw.replaceAll(',', '.'));
      return raw.trim().isEmpty || (n != null && n.isFinite && n >= 0);
    }

    if (_value.targetLoadType != RoutineExerciseLoadType.bodyweight &&
        !validWeight(_activeWeight.text)) {
      return null;
    }
    for (final entry in _memory.raw.entries.where(
      (e) => e.key.startsWith('series:'),
    )) {
      final parts = entry.key.split(':');
      final i = int.tryParse(parts[1]);
      if (i == null || i >= _targets.length) continue;
      final mode = _targets[i].loadType ?? _value.targetLoadType;
      final loadKey = mode == RoutineExerciseLoadType.assistedKg
          ? 'assistance'
          : 'weight';
      if (parts.last == 'weight' || parts.last == 'assistance') {
        if (mode != RoutineExerciseLoadType.bodyweight &&
            parts.last == loadKey &&
            !validWeight(entry.value)) {
          return null;
        }
      } else if (_positive(entry.value) != null) {
        return null;
      }
    }
    final value = _preview.copyWith(
      targetRepsMin: _range
          ? int.tryParse(_min.text)
          : int.tryParse(_reps.text),
      targetRepsMax: _range
          ? int.tryParse(_max.text)
          : int.tryParse(_reps.text),
      clearTargetWeightKg: _weight.text.trim().isEmpty,
    );
    return RoutinePlanValidation.error(value) == null ? value : null;
  }

  WorkoutExercise get _preview => _value.copyWith(
    loadSchemaVersion: 1,
    targetSets: int.tryParse(_sets.text),
    targetReps: _range || _value.isTimed ? null : int.tryParse(_reps.text),
    clearTargetReps: _range || _value.isTimed,
    targetRepsMin: int.tryParse(_min.text),
    targetRepsMax: int.tryParse(_max.text),
    targetDurationSeconds: _value.isTimed ? int.tryParse(_seconds.text) : null,
    clearTargetDuration: !_value.isTimed,
    targetWeightKg: _loadValue(_weight.text, _value.targetWeightKg),
    targetAssistanceKg: _loadValue(
      _assistance.text,
      _value.targetAssistanceKg ??
          (_value.targetLoadType == RoutineExerciseLoadType.assistedKg &&
                  _value.loadSchemaVersion == 0
              ? _value.targetWeightKg
              : null),
    ),
    clearTargetAssistanceKg: _assistance.text.trim().isEmpty,
    clearTargetWeightKg: _weight.text.isEmpty,
    setTargets: _targets,
  );

  String? _positive(String? v, {int max = 9999}) {
    final n = int.tryParse(v ?? '');
    return n != null && n > 0 && n <= max
        ? null
        : 'Usá un entero entre 1 y $max';
  }

  Widget _labeled(String label, Widget Function(InputDecoration) field) {
    final large = MediaQuery.textScalerOf(context).scale(16) > 24;
    final input = field(
      InputDecoration(
        labelText: large ? null : label,
        hintText: large ? label : null,
      ),
    );
    return large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Semantics(label: label, child: input),
            ],
          )
        : input;
  }

  Widget _number(String label, TextEditingController c, {int max = 9999}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _labeled(
          label,
          (decoration) => TextFormField(
            controller: c,
            keyboardType: TextInputType.number,
            decoration: decoration,
            validator: (v) => _positive(v, max: max),
            onChanged: (_) => _change(() {}),
          ),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final activity = footballActivities
        .where((e) => e.id == _value.sportPlan?.activityId)
        .firstOrNull;
    final content = Form(
      key: _form,
      autovalidateMode: widget.inline
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _configurationBody(context, [
            if (!widget.inline) ...[
              Center(child: ExerciseThumbnail(exercise: _value, size: 180)),
              const SizedBox(height: 16),
              Text(
                RoutineLabels.exerciseName(_value.name),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (!ExerciseArtRegistry.specific.contains(_value.id))
                const Text(
                  'Ilustración genérica de categoría',
                  style: TextStyle(fontSize: 12),
                ),
            ],
            if (definition != null) ...[
              if (!widget.inline)
                Text(
                  'Principales: ${RoutineLabels.muscles(definition.primaryMuscles)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (definition.secondaryMuscles.isNotEmpty)
                Text(
                  'Secundarios: ${RoutineLabels.muscles(definition.secondaryMuscles)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              Text(
                exerciseTechniques[_value.id]?.summary ?? 'Configurá tus objetivos. La técnica ampliada está disponible desde el nombre.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            SizedBox(height: widget.inline ? 16 : 24),
            Text(
              widget.inline ? 'Configuración rápida' : 'Objetivos de la rutina',
              style: widget.inline
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge,
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
                onChanged: (v) => _change(
                  () => _value = _value.copyWith(
                    sportPlan: SportActivityPlan(
                      activityId: activity.id,
                      mode: activity.mode,
                      targets: _sportTargets ?? _value.sportPlan!.targets,
                      objective: v,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SportMeasurementsFields(
                activity: activity,
                initial: _value.sportPlan!.targets,
                draft: _memory.sport,
                onChanged: (v) => _change(() {
                  _sportTargets = v;
                  _invalidSport = v == null;
                  if (v != null) {
                    _value = _value.copyWith(
                      sportPlan: SportActivityPlan(
                        activityId: activity.id,
                        mode: activity.mode,
                        targets: v,
                        objective: _value.sportPlan!.objective,
                      ),
                    );
                  }
                }),
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
                  onChanged: (p) =>
                      _change(() => _value = _value.copyWith(sportPurpose: p)),
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
                      if (n > 1) _change(() => _sets.text = '${n - 1}');
                    },
                    tooltip: 'Quitar una serie',
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(child: _number('Series', _sets, max: 30)),
                  IconButton(
                    onPressed: () {
                      final n = int.tryParse(_sets.text) ?? 3;
                      if (n < 30) _change(() => _sets.text = '${n + 1}');
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
                  direction: MediaQuery.textScalerOf(context).scale(16) > 24
                      ? Axis.vertical
                      : Axis.horizontal,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Fijas')),
                    ButtonSegment(value: true, label: Text('Rango')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (v) => _change(() => _range = v.first),
                ),
                const SizedBox(height: 12),
                if (_range) ...[
                  _number('Mínimo de repeticiones', _min),
                  _number('Máximo de repeticiones', _max),
                ] else
                  _number('Repeticiones objetivo', _reps),
              ],
              if (_bodyweight)
                BodyweightModeSelector(
                  value: _value.targetLoadType,
                  disclosure: true,
                  onChanged: (type) => _change(
                    () => _value = _value.copyWith(targetLoadType: type),
                  ),
                )
              else
                _labeled(
                  'Tipo de carga',
                  (
                    decoration,
                  ) => DropdownButtonFormField<RoutineExerciseLoadType>(
                    initialValue: _value.targetLoadType,
                    isExpanded: true,
                    decoration: decoration,
                    isDense: MediaQuery.textScalerOf(context).scale(16) <= 24,
                    itemHeight: MediaQuery.textScalerOf(context).scale(16) > 24
                        ? null
                        : kMinInteractiveDimension,
                    items: [
                      for (final type in RoutineExerciseLoadType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(RoutineLabels.load(type)),
                        ),
                    ],
                    onChanged: (type) {
                      if (type != null) {
                        _change(() {
                          _value = _value.copyWith(targetLoadType: type);
                        });
                      }
                    },
                  ),
                ),
              if (_value.targetLoadType !=
                  RoutineExerciseLoadType.bodyweight) ...[
                const SizedBox(height: 12),
                _labeled(
                  '${RoutineLabels.load(_value.targetLoadType)} objetivo (${_weightUnit.label})',
                  (decoration) => TextFormField(
                    controller: _activeWeight,
                    onChanged: (_) => _change(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: decoration,
                    validator: (v) {
                      if (v?.trim().isEmpty != false) return null;
                      final n = double.tryParse(v!.replaceAll(',', '.'));
                      return n != null && n.isFinite && n >= 0
                          ? null
                          : 'Carga inválida';
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (widget.inline)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Opciones avanzadas'),
                  initiallyExpanded: _memory.advanced ?? _targets.isNotEmpty,
                  maintainState: true,
                  expansionAnimationStyle:
                      MediaQuery.disableAnimationsOf(context)
                      ? AnimationStyle.noAnimation
                      : const AnimationStyle(
                          duration: Duration(milliseconds: 200),
                        ),
                  onExpansionChanged: (value) => _memory.advanced = value,
                  children: _seriesOptions(),
                )
              else
                ..._seriesOptions(),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Heredar descanso de la sesión'),
              value: _value.restSeconds == null && _value.restEnabled != false,
              onChanged: (inherit) => _change(
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
                onToggle: (v) =>
                    _change(() => _value = _value.copyWith(restEnabled: v)),
                onChanged: (v) =>
                    _change(() => _value = _value.copyWith(restSeconds: v)),
              ),
            const SizedBox(height: 16),
            Text(
              RoutineLabels.summary(_preview, units: WorkoutUnits.of(context)),
            ),
            if (widget.inline && !_memory.valid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Revisá los valores. Se conserva la última configuración válida.',
                ),
              ),
          ]),
          if (!widget.inline)
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
    );
    return widget.inline
        ? content
        : SizedBox(
            height: MediaQuery.sizeOf(context).height * .92,
            child: content,
          );
  }

  Widget _configurationBody(BuildContext context, List<Widget> children) {
    if (widget.inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }

  List<Widget> _seriesOptions() => [
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Objetivos por serie'),
      subtitle: const Text(
        'Los objetivos individuales se conservan al cambiar los generales.',
      ),
      value: _targets.isNotEmpty,
      onChanged: (enabled) => _change(() {
        _memory.raw.removeWhere((key, _) => key.startsWith('series:'));
        _targets = enabled
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
                  loadType: _value.targetLoadType,
                  weightKg: _loadValue(_weight.text, _value.targetWeightKg),
                  assistanceKg: _loadValue(
                    _assistance.text,
                    _value.targetAssistanceKg,
                  ),
                  durationSeconds: _value.isTimed
                      ? int.tryParse(_seconds.text)
                      : null,
                ),
              )
            : [];
      }),
    ),
    for (var i = 0; i < _targets.length; i++) _individual(i),
  ];

  Widget _individual(int index) {
    final target = _targets[index];
    final mode = target.loadType ?? _value.targetLoadType;
    Widget number(String label, int? value, void Function(int?) change) =>
        TextFormField(
          initialValue:
              _memory.raw['series:$index:$label'] ?? value?.toString() ?? '',
          decoration: InputDecoration(labelText: '$label · serie ${index + 1}'),
          keyboardType: TextInputType.number,
          validator: _positive,
          onChanged: (v) => _change(() {
            _memory.raw['series:$index:$label'] = v;
            change(int.tryParse(v));
          }),
        );
    final key = mode == RoutineExerciseLoadType.assistedKg
        ? 'assistance'
        : 'weight';
    final load = target.loadFor(_value.targetLoadType);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Serie ${index + 1}'),
          if (_bodyweight)
            BodyweightModeSelector(
              value: mode,
              onChanged: (type) => _change(
                () => _targets[index] = target.copyWith(loadType: type),
              ),
            ),
          if (_value.isTimed)
            number(
              'Segundos',
              target.durationSeconds,
              (v) => _targets[index] = target.copyWith(durationSeconds: v),
            )
          else if (target.repsMin != null && target.reps == null) ...[
            number(
              'Repeticiones mínimas',
              target.repsMin,
              (v) => _targets[index] = target.copyWith(repsMin: v),
            ),
            number(
              'Repeticiones máximas',
              target.repsMax,
              (v) => _targets[index] = target.copyWith(repsMax: v),
            ),
          ] else
            number(
              'Repeticiones',
              target.reps,
              (v) => _targets[index] = target.copyWith(reps: v),
            ),
          if (mode != RoutineExerciseLoadType.bodyweight)
            TextFormField(
              key: ValueKey('target-$index-${mode.name}'),
              initialValue:
                  _memory.raw['series:$index:$key'] ?? _displayWeight(load),
              decoration: InputDecoration(
                labelText:
                    '${RoutineLabels.load(mode)} (${_weightUnit.label}) · serie ${index + 1}',
                errorMaxLines: 3,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) => _change(() {
                _memory.raw['series:$index:$key'] = v;
                final n = _loadValue(v, load);
                _targets[index] = mode == RoutineExerciseLoadType.assistedKg
                    ? target.copyWith(
                        loadType: mode,
                        assistanceKg: n,
                        clearAssistance: v.trim().isEmpty,
                      )
                    : target.copyWith(
                        loadType: mode,
                        weightKg: n,
                        clearWeight: v.trim().isEmpty,
                      );
              }),
            ),
        ],
      ),
    );
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    final result = _validValue;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisá los objetivos y los rangos de cada serie.'),
        ),
      );
      return;
    }
    Navigator.pop(context, result);
  }
}
