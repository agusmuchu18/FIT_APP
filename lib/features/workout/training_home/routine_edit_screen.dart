import 'package:flutter/material.dart';

import '../pro/data/exercise_definition.dart';
import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';
import 'training_home_controller.dart';

class RoutineEditScreen extends StatefulWidget {
  const RoutineEditScreen({
    super.key,
    required this.routine,
    required this.controller,
  });

  final WorkoutTemplate routine;
  final TrainingHomeController controller;

  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  late final TextEditingController _nameController;
  late WorkoutType _type;
  late String _folderId;
  late List<WorkoutExercise> _exercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.routine.name);
    _type = widget.routine.type;
    _folderId = widget.routine.folderId ?? '';
    _exercises = [...widget.routine.exercises];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folders = widget.controller.folders;
    if (_folderId.isNotEmpty &&
        !folders.any((folder) => folder.id == _folderId)) {
      _folderId = '';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Editar rutina')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          TextField(
            controller: _nameController,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre de la rutina',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WorkoutType>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Tipo',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final type in WorkoutType.values)
                DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _folderId,
            decoration: const InputDecoration(
              labelText: 'Carpeta',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Sin carpeta')),
              for (final folder in folders)
                DropdownMenuItem(value: folder.id, child: Text(folder.name)),
            ],
            onChanged: (value) => setState(() => _folderId = value ?? ''),
          ),
          const SizedBox(height: 24),
          Text('Ejercicios', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var index = 0; index < _exercises.length; index++)
            Card(
              key: ValueKey('exercise-$index'),
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(_exercises[index].name),
                subtitle: Text(_exerciseSummary(_exercises[index])),
                onTap: () => _editExercise(index),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Opciones de ${_exercises[index].name}',
                  onSelected: (action) => _exerciseAction(index, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Editar objetivos'),
                    ),
                    if (index > 0)
                      const PopupMenuItem(
                        value: 'up',
                        child: Text('Mover arriba'),
                      ),
                    if (index < _exercises.length - 1)
                      const PopupMenuItem(
                        value: 'down',
                        child: Text('Mover abajo'),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Quitar ejercicio'),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Agregar ejercicio'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
        ),
      ),
    );
  }

  void _exerciseAction(int index, String action) {
    if (action == 'edit') {
      _editExercise(index);
      return;
    }
    setState(() {
      if (action == 'remove') {
        _exercises.removeAt(index);
      } else if (action == 'up' && index > 0) {
        final exercise = _exercises.removeAt(index);
        _exercises.insert(index - 1, exercise);
      } else if (action == 'down' && index < _exercises.length - 1) {
        final exercise = _exercises.removeAt(index);
        _exercises.insert(index + 1, exercise);
      }
    });
  }

  Future<void> _editExercise(int index) async {
    final updated = await showDialog<WorkoutExercise>(
      context: context,
      builder: (_) => _ExerciseTargetsDialog(exercise: _exercises[index]),
    );
    if (updated != null && mounted) {
      setState(() => _exercises[index] = updated);
    }
  }

  Future<void> _addExercise() async {
    var query = '';
    final selected = await showModalBottomSheet<ExerciseDefinition>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final needle = _foldSearch(query.trim());
          final matches = exerciseLibrary
              .where(
                (exercise) =>
                    _foldSearch(exercise.name).contains(needle) ||
                    exercise.aliases.any(
                      (alias) => _foldSearch(alias).contains(needle),
                    ) ||
                    _foldSearch(exercise.equipment).contains(needle),
              )
              .take(60)
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Buscar ejercicio',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                  ),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(
                            child: Text('No hay ejercicios para esa búsqueda.'),
                          )
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final exercise = matches[index];
                              return ListTile(
                                title: Text(exercise.name),
                                subtitle: Text(exercise.equipment),
                                onTap: () =>
                                    Navigator.pop(sheetContext, exercise),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _exercises.add(
        WorkoutExercise(
          id: selected.id,
          name: selected.name,
          muscleGroup: selected.primaryMuscles.isEmpty
              ? null
              : selected.primaryMuscles.first,
          equipment: selected.equipment,
          measurement: selected.defaultMeasurement,
          targetSets: 3,
          targetReps: selected.isTimed ? null : 10,
          targetDurationSeconds: selected.isTimed ? 30 : null,
          targetLoadType: _loadTypeFor(selected),
        ),
      );
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá un nombre y al menos un ejercicio.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.controller.updateRoutine(
        WorkoutTemplate(
          id: widget.routine.id,
          name: name,
          type: _type,
          origin: widget.routine.origin,
          activityName: widget.routine.activityName,
          folderId: _folderId.isEmpty ? null : _folderId,
          exercises: _exercises,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar la rutina. Reintentá.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ExerciseTargetsDialog extends StatefulWidget {
  const _ExerciseTargetsDialog({required this.exercise});

  final WorkoutExercise exercise;

  @override
  State<_ExerciseTargetsDialog> createState() => _ExerciseTargetsDialogState();
}

class _ExerciseTargetsDialogState extends State<_ExerciseTargetsDialog> {
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  late RoutineExerciseLoadType _loadType;
  String? _error;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    _sets = TextEditingController(text: '${exercise.targetSets}');
    _reps = TextEditingController(
      text:
          (exercise.isTimed
                  ? exercise.targetDurationSeconds
                  : exercise.targetReps)
              ?.toString() ??
          '',
    );
    _weight = TextEditingController(
      text: exercise.targetWeightKg?.toString() ?? '',
    );
    _rest = TextEditingController(text: exercise.restSeconds?.toString() ?? '');
    _loadType = exercise.targetLoadType;
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numberField(_sets, 'Series'),
            _numberField(
              _reps,
              widget.exercise.isTimed
                  ? 'Duración objetivo (segundos)'
                  : 'Repeticiones objetivo',
            ),
            DropdownButtonFormField<RoutineExerciseLoadType>(
              initialValue: _loadType,
              decoration: const InputDecoration(labelText: 'Tipo de carga'),
              items: [
                for (final type in RoutineExerciseLoadType.values)
                  DropdownMenuItem(value: type, child: Text(_loadLabel(type))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _loadType = value);
              },
            ),
            _numberField(_weight, 'Carga objetivo (kg)', decimal: true),
            _numberField(_rest, 'Descanso (segundos)'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _apply, child: const Text('Aplicar')),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  void _apply() {
    final sets = int.tryParse(_sets.text.trim());
    final repsText = _reps.text.trim();
    final reps = repsText.isEmpty ? null : int.tryParse(repsText);
    final weightText = _weight.text.trim();
    final weight = weightText.isEmpty
        ? null
        : double.tryParse(weightText.replaceAll(',', '.'));
    final restText = _rest.text.trim();
    final rest = restText.isEmpty ? null : int.tryParse(restText);
    if (sets == null ||
        sets < 1 ||
        sets > 30 ||
        (repsText.isNotEmpty &&
            (reps == null ||
                reps < 1 ||
                reps > (widget.exercise.isTimed ? 86400 : 1000))) ||
        (weightText.isNotEmpty &&
            (weight == null || !weight.isFinite || weight < 0)) ||
        (restText.isNotEmpty && (rest == null || rest < 5 || rest > 3600))) {
      setState(
        () => _error = 'Revisá las series, repeticiones, carga y descanso.',
      );
      return;
    }
    Navigator.pop(
      context,
      widget.exercise.copyWith(
        targetSets: sets,
        targetReps: widget.exercise.isTimed ? null : reps,
        clearTargetReps: widget.exercise.isTimed || reps == null,
        targetDurationSeconds: widget.exercise.isTimed ? reps : null,
        clearTargetDuration: widget.exercise.isTimed && reps == null,
        targetLoadType: _loadType,
        targetWeightKg: weight,
        clearTargetWeightKg: weight == null,
        restSeconds: rest,
        clearRestSeconds: rest == null,
      ),
    );
  }
}

String _typeLabel(WorkoutType type) => switch (type) {
  WorkoutType.strength => 'Fuerza',
  WorkoutType.cardio => 'Cardio',
  WorkoutType.functional => 'Funcional',
  WorkoutType.sport => 'Deporte',
  WorkoutType.custom => 'Personalizado',
};

String _foldSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàäâ]'), 'a')
    .replaceAll(RegExp('[éèëê]'), 'e')
    .replaceAll(RegExp('[íìïî]'), 'i')
    .replaceAll(RegExp('[óòöô]'), 'o')
    .replaceAll(RegExp('[úùüû]'), 'u')
    .replaceAll('ñ', 'n');

String _loadLabel(RoutineExerciseLoadType type) => switch (type) {
  RoutineExerciseLoadType.bodyweight => 'Peso corporal',
  RoutineExerciseLoadType.weightedKg => 'Peso externo',
  RoutineExerciseLoadType.assistedKg => 'Asistido',
  RoutineExerciseLoadType.machineKg => 'Máquina',
};

RoutineExerciseLoadType _loadTypeFor(ExerciseDefinition exercise) {
  if (exercise.loadType == LoadType.assistedBodyweight) {
    return RoutineExerciseLoadType.assistedKg;
  }
  if (exercise.loadType == LoadType.bodyweightEffective) {
    return RoutineExerciseLoadType.bodyweight;
  }
  if (exercise.equipment.toLowerCase().contains('máquina')) {
    return RoutineExerciseLoadType.machineKg;
  }
  return RoutineExerciseLoadType.weightedKg;
}

String _exerciseSummary(WorkoutExercise exercise) {
  if (exercise.isTimed) {
    return '${exercise.targetSets} series · ${exercise.targetDurationSeconds ?? 30} s por serie';
  }
  final reps = exercise.targetReps == null
      ? '${exercise.targetRepsMin ?? 8}-${exercise.targetRepsMax ?? 12}'
      : '${exercise.targetReps}';
  return '${exercise.targetSets} series · $reps reps'
      '${exercise.restSeconds == null ? '' : ' · ${exercise.restSeconds} s descanso'}';
}
