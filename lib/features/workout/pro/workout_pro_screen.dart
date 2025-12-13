import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/statistics_service.dart';
import 'data/exercise_definition.dart';
import 'data/exercise_library.dart';
import 'models/workout_models.dart';
import 'providers/workout_pro_provider.dart';
import 'widgets/exercise_card.dart';
import 'widgets/template_section.dart';
import 'widgets/workout_bottom_bar.dart';
import 'widgets/workout_type_selector.dart';

Widget _metric(BuildContext context, String label, String value) {
  return Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class WorkoutProScreen extends StatelessWidget {
  const WorkoutProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkoutProProvider()..initialize(),
      child: const _WorkoutProContent(),
    );
  }
}

class _WorkoutProContent extends StatefulWidget {
  const _WorkoutProContent();

  @override
  State<_WorkoutProContent> createState() => _WorkoutProContentState();
}

class _WorkoutProContentState extends State<_WorkoutProContent> {
  late final ExerciseLibraryIndex _exerciseIndex;

  @override
  void initState() {
    super.initState();
    _exerciseIndex = ExerciseLibraryIndex(exerciseLibrary);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProProvider>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _AppBarTitle(dateLabel: StatisticsService.formatShortDate(DateTime.now())),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, provider, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'save_template', child: Text('Guardar como plantilla')),
              PopupMenuItem(value: 'load_template', child: Text('Cargar plantilla')),
              PopupMenuItem(value: 'reset', child: Text('Reiniciar entrenamiento')),
              PopupMenuItem(value: 'export', child: Text('Exportar JSON (debug)')),
            ],
          ),
        ],
      ),
      body: provider.initialized
          ? SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SessionSummary(provider: provider),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tipo de entrenamiento', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            WorkoutTypeSelector(
                              selected: provider.selectedType,
                              customName: provider.customTypeName,
                              onCustomNameChanged: provider.setCustomTypeName,
                              onSelected: (type) async {
                                if (provider.selectedType == WorkoutType.strength &&
                                    type != WorkoutType.strength &&
                                    provider.exercises.isNotEmpty) {
                                  final confirmed = await _confirmDialog(
                                    context,
                                    'Cambiar tipo borrará ejercicios. ¿Continuar?',
                                  );
                                  if (!confirmed) return;
                                  provider.setType(type, force: true);
                                } else {
                                  provider.setType(type);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TemplateSection(
                      standardTemplates: provider.standardTemplates,
                      userTemplates: provider.userTemplates,
                      selected: provider.selectedTemplate,
                      suggestions: provider.suggestedTemplates(),
                      onSelect: provider.selectTemplate,
                      onClear: provider.clearTemplate,
                    ),
                    const SizedBox(height: 12),
                    _buildDynamicSection(provider),
                    const SizedBox(height: 12),
                    ClosingSection(provider: provider),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: WorkoutBottomBar(
        exerciseCount: provider.selectedType == WorkoutType.strength ? provider.totalExercises : 0,
        setCount: provider.selectedType == WorkoutType.strength ? provider.totalSets : 0,
        durationLabel: provider.getDurationLabel(),
        onSave: () => _saveSession(context, provider, finalize: false),
        onFinish: () => _saveSession(context, provider, finalize: true),
      ),
    );
  }

  Widget _buildDynamicSection(WorkoutProProvider provider) {
    switch (provider.selectedType) {
      case WorkoutType.strength:
        return StrengthSection(
          provider: provider,
          exerciseIndex: _exerciseIndex,
        );
      case WorkoutType.cardio:
        return SimpleWorkoutSection(
          provider: provider,
          title: 'Cardio',
        );
      case WorkoutType.functional:
        return SimpleWorkoutSection(
          provider: provider,
          title: 'Funcional',
        );
      case WorkoutType.sport:
        return SimpleWorkoutSection(
          provider: provider,
          title: 'Deporte',
        );
      case WorkoutType.custom:
        return SimpleWorkoutSection(
          provider: provider,
          title: 'Otro',
        );
    }
  }

  Future<void> _saveSession(
    BuildContext context,
    WorkoutProProvider provider, {
    required bool finalize,
  }) async {
    final ok = await provider.saveSession();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faltan datos mínimos para guardar.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(finalize ? 'Entrenamiento finalizado' : 'Entrenamiento guardado')),
    );
    if (finalize) {
      await provider.reset();
    }
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WorkoutProProvider provider,
    String value,
  ) async {
    switch (value) {
      case 'save_template':
        final name = await _promptName(context, 'Nombre de la plantilla');
        if (name != null && name.isNotEmpty) {
          await provider.saveTemplate(name);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Plantilla "$name" guardada')),
          );
        }
        break;
      case 'load_template':
        await showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (_) => TemplateSection(
            standardTemplates: provider.standardTemplates,
            userTemplates: provider.userTemplates,
            selected: provider.selectedTemplate,
            suggestions: provider.suggestedTemplates(),
            onSelect: (template) {
              provider.selectTemplate(template);
              Navigator.of(context).pop();
            },
            onClear: provider.clearTemplate,
          ),
        );
        break;
      case 'reset':
        final confirmed = await _confirmDialog(
          context,
          '¿Reiniciar entrenamiento actual? Se perderán los datos no guardados.',
        );
        if (confirmed) await provider.reset();
        break;
      case 'export':
        final json = provider.exportDebugJson();
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export JSON'),
            content: SingleChildScrollView(
              child: SelectableText(json),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
        break;
    }
  }

  Future<bool> _confirmDialog(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _promptName(BuildContext context, String title) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Entrenamiento', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(dateLabel, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              label: Text(_typeLabel()),
              avatar: const Icon(Icons.fitness_center, size: 18),
            ),
            Chip(
              label: Text(provider.selectedTemplate?.name ?? 'Sin plantilla'),
              avatar: const Icon(Icons.view_module_outlined, size: 18),
            ),
            Text('Duración: ${provider.liveDurationLabel}', style: Theme.of(context).textTheme.bodyMedium),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('Estado: Borrador'),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel() {
    switch (provider.selectedType) {
      case WorkoutType.strength:
        return 'Fuerza';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.functional:
        return 'Funcional';
      case WorkoutType.sport:
        return 'Deporte';
      case WorkoutType.custom:
        return provider.customTypeName?.isNotEmpty == true
            ? provider.customTypeName!
            : 'Personalizado';
    }
  }
}

class SimpleWorkoutSection extends StatefulWidget {
  const SimpleWorkoutSection({required this.provider, required this.title});

  final WorkoutProProvider provider;
  final String title;

  @override
  State<SimpleWorkoutSection> createState() => _SimpleWorkoutSectionState();
}

class _SimpleWorkoutSectionState extends State<SimpleWorkoutSection> {
  late final TextEditingController _activityController;
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _paceController;
  late final TextEditingController _notesController;

  WorkoutProProvider get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _activityController = TextEditingController(text: provider.activityName ?? '');
    _durationController =
        TextEditingController(text: provider.durationMinutes?.toString() ?? '');
    _distanceController =
        TextEditingController(text: provider.distanceKm?.toString() ?? '');
    _paceController = TextEditingController(text: provider.pace ?? '');
    _notesController = TextEditingController(text: provider.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant SimpleWorkoutSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_activityController.text != (provider.activityName ?? '')) {
      _activityController.text = provider.activityName ?? '';
    }
    final durationText = provider.durationMinutes?.toString() ?? '';
    if (_durationController.text != durationText) {
      _durationController.text = durationText;
    }
    final distanceText = provider.distanceKm?.toString() ?? '';
    if (_distanceController.text != distanceText) {
      _distanceController.text = distanceText;
    }
    if (_paceController.text != (provider.pace ?? '')) {
      _paceController.text = provider.pace ?? '';
    }
    if (_notesController.text != (provider.notes ?? '')) {
      _notesController.text = provider.notes ?? '';
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _paceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _activityController,
              decoration: const InputDecoration(
                labelText: 'Actividad',
                prefixIcon: Icon(Icons.directions_run),
              ),
              onChanged: provider.setActivityName,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duración (minutos)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => provider.setDuration(int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _distanceController,
                    decoration: const InputDecoration(
                      labelText: 'Distancia (km)',
                      prefixIcon: Icon(Icons.social_distance),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => provider.setDistance(double.tryParse(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _paceController,
              decoration: const InputDecoration(
                labelText: 'Ritmo / Velocidad',
                prefixIcon: Icon(Icons.speed),
              ),
              onChanged: provider.setPace,
            ),
            const SizedBox(height: 12),
            _IntensityRow(provider: provider),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
              maxLines: 2,
              onChanged: provider.setNotes,
            ),
          ],
        ),
      ),
    );
  }
}

class StrengthSection extends StatelessWidget {
  const StrengthSection({
    required this.provider,
    required this.exerciseIndex,
  });

  final WorkoutProProvider provider;
  final ExerciseLibraryIndex exerciseIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Ejercicios', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openAddExercise(context, provider),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar ejercicio'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregá ejercicios para registrar series, reps y peso',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => _openAddExercise(context, provider),
                      child: const Text('Agregar ejercicio'),
                    ),
                    const SizedBox(height: 12),
                    const Text('Sugeridos'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        'Press banca',
                        'Dominadas',
                        'Sentadilla',
                        'Peso muerto',
                      ]
                          .map(
                          (name) => ActionChip(
                            label: Text(name),
                            onPressed: () {
                              final match = exerciseIndex.findByQuery(name);
                              final exercise = match != null
                                  ? provider.fromDefinition(match)
                                  : WorkoutExercise(
                                      id: const Uuid().v4(),
                                      name: name,
                                    );
                              provider.addExerciseWithDefaults(exercise);
                            },
                          ),
                        )
                        .toList(),
                    ),
                  ],
                ),
              ),
            ...provider.exercises.map(
              (exercise) {
                final definition = exerciseIndex.findByQuery(exercise.name);
                return ExerciseCard(
                  key: ValueKey(exercise.id),
                  exercise: exercise,
                  definition: definition,
                  onDuplicate: () => provider.duplicateExercise(exercise.id),
                  onDelete: () async {
                    final confirm = await _confirmDelete(context);
                    if (confirm) provider.removeExercise(exercise.id);
                  },
                  onAddSet: () => provider.addSet(exercise.id),
                  onCopySet: () => provider.copyPreviousSet(exercise.id),
                  onBumpReps: () => provider.bumpReps(exercise.id, 1),
                  onBumpWeight: () => provider.bumpWeight(exercise.id, 2.5),
                  onUpdateSet: (set) => provider.updateSet(exercise.id, set.id, set),
                  onDeleteSet: (setId) => provider.removeSet(exercise.id, setId),
                  onUpdateNotes: (notes) => provider.updateExerciseNotes(exercise.id, notes),
                );
              },
            ),
            const SizedBox(height: 12),
            _MetricsRow(provider: provider),
          ],
        ),
      ),
    );
  }


  Future<void> _openAddExercise(
    BuildContext context,
    WorkoutProProvider provider,
  ) async {
    final chosen = await showModalBottomSheet<WorkoutExercise>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ExerciseSelector(provider: provider),
    );

    if (chosen == null) return;

    provider.addExerciseWithDefaults(chosen);
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Eliminar ejercicio'),
      content: const Text('¿Eliminar este ejercicio? Esta acción no se puede deshacer.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  return result ?? false;
}

class _MetricsRow extends StatefulWidget {
  const _MetricsRow({required this.provider});

  final WorkoutProProvider provider;

  @override
  State<_MetricsRow> createState() => _MetricsRowState();
}

class _MetricsRowState extends State<_MetricsRow> {
  late final TextEditingController _notesController;

  WorkoutProProvider get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: provider.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant _MetricsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_notesController.text != (provider.notes ?? '')) {
      _notesController.text = provider.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Métricas'),
        const SizedBox(height: 8),
        _IntensityRow(provider: provider),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notas generales',
            prefixIcon: Icon(Icons.note_alt_outlined),
          ),
          maxLines: 2,
          onChanged: provider.setNotes,
        ),
      ],
    );
  }
}

class _ExerciseSelector extends StatefulWidget {
  const _ExerciseSelector({required this.provider});

  final WorkoutProProvider provider;

  @override
  State<_ExerciseSelector> createState() => _ExerciseSelectorState();
}

class _ExerciseSelectorState extends State<_ExerciseSelector> {
  final TextEditingController _queryController = TextEditingController();
  String? muscleFilter;
  String? equipmentFilter;
  String? patternFilter;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = ExerciseLibraryIndex(exerciseLibrary);
    final topSuggestions = exerciseLibrary.take(8).toList();
    final recent = widget.provider.recentExercises
        .map(index.findByQuery)
        .whereType<ExerciseDefinition>()
        .toList();
    final mostUsed = widget.provider.mostUsedExercises
        .map(index.findByQuery)
        .whereType<ExerciseDefinition>()
        .toList();

    final filtered = _filtered(index);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agregar ejercicio', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              decoration: const InputDecoration(
                labelText: 'Buscar o crear',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Pecho', muscleFilter == 'pecho', () => _toggleMuscle('pecho')),
                _chip('Espalda', muscleFilter == 'espalda', () => _toggleMuscle('espalda')),
                _chip('Piernas', muscleFilter == 'piernas', () => _toggleMuscle('piernas')),
                _chip('Hombro', muscleFilter == 'hombros', () => _toggleMuscle('hombros')),
                _chip('Bíceps', muscleFilter == 'bíceps', () => _toggleMuscle('bíceps')),
                _chip('Tríceps', muscleFilter == 'tríceps', () => _toggleMuscle('tríceps')),
                _chip('Core', muscleFilter == 'core', () => _toggleMuscle('core')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Bodyweight', equipmentFilter == 'bodyweight', () => _toggleEquipment('bodyweight')),
                _chip('Barbell', equipmentFilter == 'barbell', () => _toggleEquipment('barbell')),
                _chip('Dumbbell', equipmentFilter == 'dumbbell', () => _toggleEquipment('dumbbell')),
                _chip('Machine', equipmentFilter == 'machine', () => _toggleEquipment('machine')),
                _chip('Cable', equipmentFilter == 'cable', () => _toggleEquipment('cable')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Push', patternFilter == 'push', () => _togglePattern('push')),
                _chip('Pull', patternFilter == 'pull', () => _togglePattern('pull')),
                _chip('Squat', patternFilter == 'squat', () => _togglePattern('squat')),
                _chip('Hinge', patternFilter == 'hinge', () => _togglePattern('hinge')),
                _chip('Core', patternFilter == 'core', () => _togglePattern('core')),
              ],
            ),
            const SizedBox(height: 12),
            if (recent.isNotEmpty) ...[
              const Text('Recientes'),
              _horizontalList(recent),
              const SizedBox(height: 12),
            ],
            if (mostUsed.isNotEmpty) ...[
              const Text('Más usados'),
              _horizontalList(mostUsed),
              const SizedBox(height: 12),
            ],
            const Text('Sugeridos'),
            _horizontalList(topSuggestions),
            const SizedBox(height: 12),
            Text('Resultados (${filtered.length})', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final exercise = filtered[index];
                  return ListTile(
                    title: Text(exercise.name),
                    subtitle: Text(exercise.primaryMuscles.join(', ')),
                    onTap: () => _selectDefinition(exercise),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final customName = _queryController.text.trim();
                if (customName.isEmpty) return;
                final exercise = WorkoutExercise(
                  id: const Uuid().v4(),
                  name: customName,
                  sets: [],
                );
                Navigator.of(context).pop(exercise);
              },
              child: const Text('Crear ejercicio nuevo'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMuscle(String value) {
    setState(() {
      muscleFilter = muscleFilter == value ? null : value;
    });
  }

  void _toggleEquipment(String value) {
    setState(() {
      equipmentFilter = equipmentFilter == value ? null : value;
    });
  }

  void _togglePattern(String value) {
    setState(() {
      patternFilter = patternFilter == value ? null : value;
    });
  }

  List<ExerciseDefinition> _filtered(ExerciseLibraryIndex index) {
    var results = index.search(_queryController.text);
    if (muscleFilter != null) {
      results = results
          .where((e) => e.primaryMuscles
              .map((m) => m.toLowerCase())
              .contains(muscleFilter))
          .toList();
    }
    if (equipmentFilter != null) {
      results = results.where((e) => e.equipment == equipmentFilter).toList();
    }
    if (patternFilter != null) {
      results = results.where((e) => e.movementPattern == patternFilter).toList();
    }
    return results;
  }

  Widget _chip(String label, bool selected, VoidCallback onSelected) {
    return FilterChip(label: Text(label), selected: selected, onSelected: (_) => onSelected());
  }

  Widget _horizontalList(List<ExerciseDefinition> exercises) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: exercises
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(right: 8, top: 6),
                child: ActionChip(
                  label: Text(e.name),
                  onPressed: () => _selectDefinition(e),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _selectDefinition(ExerciseDefinition exercise) {
    final prepared = widget.provider.fromDefinition(exercise);
    Navigator.of(context).pop(prepared);
  }
}

class _IntensityRow extends StatelessWidget {
  const _IntensityRow({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Intensidad percibida (RPE)'),
        Slider(
          min: 1,
          max: 10,
          divisions: 9,
          value: provider.rpe.toDouble(),
          label: provider.rpe.toString(),
          onChanged: (value) => provider.setRpe(value.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cansancio post'),
            DropdownButton<int>(
              value: provider.fatigue,
              items: List.generate(
                5,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                ),
              ),
              onChanged: (value) {
                if (value != null) provider.setFatigue(value);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class ClosingSection extends StatefulWidget {
  const ClosingSection({required this.provider});

  final WorkoutProProvider provider;

  @override
  State<ClosingSection> createState() => _ClosingSectionState();
}

class _ClosingSectionState extends State<ClosingSection> {
  late final TextEditingController _durationController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.provider.closingDuration?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.provider.finalNotes ?? '');
  }

  @override
  void didUpdateWidget(covariant ClosingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final durationText = widget.provider.closingDuration?.toString() ?? '';
    if (_durationController.text != durationText) {
      _durationController.text = durationText;
    }
    if (widget.provider.finalNotes != _notesController.text) {
      _notesController.text = widget.provider.finalNotes ?? '';
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cierre de entrenamiento', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Estos datos ayudan a interpretar tu carga y progreso.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duración total (min)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.provider.setClosingDuration(int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Fatiga general (1-5)'),
                    value: widget.provider.closingFatigue,
                    items: List.generate(
                      5,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) widget.provider.setClosingFatigue(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Rendimiento percibido (1-5)'),
              value: widget.provider.closingPerformance,
              items: List.generate(
                5,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1}'),
                ),
              ),
              onChanged: (v) {
                if (v != null) widget.provider.setClosingPerformance(v);
              },
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                title: const Text('Notas finales'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas finales',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                    maxLines: 3,
                    onChanged: widget.provider.setFinalNotes,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
