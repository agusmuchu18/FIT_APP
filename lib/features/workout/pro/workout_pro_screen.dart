import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/statistics_service.dart';
import 'models/workout_models.dart';
import 'providers/workout_pro_provider.dart';
import 'widgets/exercise_card.dart';
import 'widgets/template_section.dart';
import 'widgets/workout_bottom_bar.dart';
import 'widgets/workout_type_selector.dart';

class WorkoutProScreen extends StatelessWidget {
  const WorkoutProScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkoutProProvider()..initialize(),
      child: const _WorkoutProContent(),
    );
}

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
}

class _WorkoutProContent extends StatefulWidget {
  const _WorkoutProContent();

  @override
  State<_WorkoutProContent> createState() => _WorkoutProContentState();
}

class _WorkoutProContentState extends State<_WorkoutProContent> {
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
        return StrengthSection(provider: provider);
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

class StrengthSection extends StatelessWidget {
  const StrengthSection({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    final standardExercises = [
      'Press banca',
      'Sentadilla',
      'Peso muerto',
      'Remo con barra',
      'Dominadas',
      'Press militar',
      'Hip thrust',
      'Curl bíceps',
      'Extensión tríceps',
    ];

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
                  onPressed: () => _openAddExercise(context, standardExercises),
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
                      onPressed: () => _openAddExercise(context, standardExercises),
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
                                final exercise = WorkoutExercise(
                                  id: const Uuid().v4(),
                                  name: name,
                                );
                                provider.addExercise(exercise);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ...provider.exercises.map(
              (exercise) => ExerciseCard(
                key: ValueKey(exercise.id),
                exercise: exercise,
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
              ),
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
    List<String> standardExercises,
  ) async {
    final controller = TextEditingController();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Agregar ejercicio', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Buscar o crear',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Estándar'),
              ...standardExercises.map(
                (name) => ListTile(
                  title: Text(name),
                  onTap: () => Navigator.of(context).pop(name),
                ),
              ),
              if (provider.recentExercises.isNotEmpty) ...[
                const Divider(),
                const Text('Usados recientemente'),
                ...provider.recentExercises.map(
                  (name) => ListTile(
                    title: Text(name),
                    onTap: () => Navigator.of(context).pop(name),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Crear ejercicio nuevo'),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen != null && chosen.isNotEmpty) {
      final newExercise = WorkoutExercise(
        id: const Uuid().v4(),
        name: chosen,
      );
      provider.addExercise(newExercise);
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: const Text('¿Seguro que deseas eliminar este ejercicio?'),
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
}

class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _metric(context, 'Series', provider.totalSets.toString()),
            _metric(context, 'Reps', provider.totalReps.toString()),
            _metric(context, 'Volumen (kg)', provider.totalVolume.toStringAsFixed(1)),
            _metric(context, 'Top set', provider.topSetLabel ?? '--'),
            _metric(
              context,
              'RIR prom',
              provider.averageRir != null ? provider.averageRir!.toStringAsFixed(1) : '--',
            ),
          ],
        ),
      ),
    );
  }

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

  @override
  void initState() {
    super.initState();
    _activityController = TextEditingController(text: widget.provider.activityName ?? '');
    _durationController = TextEditingController(
      text: widget.provider.durationMinutes?.toString() ?? '',
    );
    _distanceController = TextEditingController(
      text: widget.provider.distanceKm?.toString() ?? '',
    );
    _paceController = TextEditingController(text: widget.provider.pace ?? '');
    _notesController = TextEditingController(text: widget.provider.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant SimpleWorkoutSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.provider.activityName != _activityController.text) {
      _activityController.text = widget.provider.activityName ?? '';
    }
    final durationText = widget.provider.durationMinutes?.toString() ?? '';
    if (_durationController.text != durationText) {
      _durationController.text = durationText;
    }
    final distanceText = widget.provider.distanceKm?.toString() ?? '';
    if (_distanceController.text != distanceText) {
      _distanceController.text = distanceText;
    }
    if (widget.provider.pace != _paceController.text) {
      _paceController.text = widget.provider.pace ?? '';
    }
    if (widget.provider.notes != _notesController.text) {
      _notesController.text = widget.provider.notes ?? '';
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
                labelText: 'Nombre de la actividad',
                prefixIcon: Icon(Icons.directions_run),
              ),
              onChanged: widget.provider.setActivityName,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duración (min)',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.provider.setDuration(int.tryParse(v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _distanceController,
                    decoration: const InputDecoration(
                      labelText: 'Distancia (km)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => widget.provider.setDistance(double.tryParse(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _paceController,
                    decoration: const InputDecoration(
                      labelText: 'Ritmo / velocidad',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    onChanged: widget.provider.setPace,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _IntensityRow(provider: widget.provider),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
              onChanged: widget.provider.setNotes,
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _metric(context, 'Duración', '${widget.provider.durationMinutes ?? 0}m'),
                    _metric(context, 'Distancia', widget.provider.distanceKm != null ? '${widget.provider.distanceKm} km' : '--'),
                    _metric(context, 'Ritmo', widget.provider.pace ?? '--'),
                    _metric(context, 'RPE', widget.provider.rpe.toString()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
