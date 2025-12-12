import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/statistics_service.dart';
import '../../../main.dart';
import '../common/theme/app_colors.dart';
import '../common/widgets/summary_card.dart';
import 'models/workout_models.dart';
import 'providers/workout_pro_provider.dart';
import 'widgets/exercise_card.dart';
import 'widgets/template_section.dart';
import 'widgets/workout_bottom_bar.dart';
import 'widgets/workout_type_selector.dart';

class WorkoutProScreen extends StatefulWidget {
  const WorkoutProScreen({super.key});

  @override
  State<WorkoutProScreen> createState() => _WorkoutProScreenState();
}

class _WorkoutProScreenState extends State<WorkoutProScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkoutProProvider()..initialize(),
      child: const _WorkoutProView(),
    );
  }
}

class _WorkoutProView extends StatefulWidget {
  const _WorkoutProView();

  @override
  State<_WorkoutProView> createState() => _WorkoutProViewState();
}

class _WorkoutProViewState extends State<_WorkoutProView> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: AppColors.background,
        title: _HeaderSummary(),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SummaryCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tipo de entrenamiento',
                              style: TextStyle(fontWeight: FontWeight.w700)),
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
                    const SizedBox(height: 12),
                    TemplateSection(
                      standardTemplates: provider.standardTemplates,
                      userTemplates: provider.userTemplates,
                      selected: provider.selectedTemplate,
                      onSelect: provider.selectTemplate,
                      onClear: provider.clearTemplate,
                    ),
                    const SizedBox(height: 12),
                    _buildDynamicSection(provider),
                    const SizedBox(height: 12),
                    _ClosingSection(provider: provider),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: WorkoutBottomBar(
        exerciseCount: provider.selectedType == WorkoutType.strength
            ? provider.totalExercises
            : 0,
        setCount:
            provider.selectedType == WorkoutType.strength ? provider.totalSets : 0,
        durationLabel: provider.getDurationLabel(),
        onSave: () => _saveSession(context, provider),
        onFinish: () => _saveSession(context, provider),
      ),
    );
  }

  Widget _buildDynamicSection(WorkoutProProvider provider) {
    switch (provider.selectedType) {
      case WorkoutType.strength:
        return _StrengthSection(provider: provider);
      case WorkoutType.cardio:
        return _CardioSection(provider: provider);
      case WorkoutType.functional:
        return _FunctionalSection(provider: provider);
      case WorkoutType.sport:
        return _SportSection(provider: provider);
      case WorkoutType.custom:
        return _FunctionalSection(provider: provider);
    }
  }

  Future<void> _saveSession(
      BuildContext context, WorkoutProProvider provider) async {
    final ok = await provider.saveSession();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faltan datos mínimos para guardar.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entrenamiento guardado')),
    );
    await provider.reset();
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

class _HeaderSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final today = StatisticsService.formatShortDate(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Entrenamiento', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(today, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StrengthSection extends StatelessWidget {
  const _StrengthSection({required this.provider});

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

    return SummaryCard(
      padding: const EdgeInsets.all(14),
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aún no agregaste ejercicios'),
            ),
          ...provider.exercises.map(
            (exercise) => ExerciseCard(
              exercise: exercise,
              onDuplicate: () => provider.duplicateExercise(exercise.id),
              onDelete: () async {
                final confirm = await _confirmDelete(context);
                if (confirm) provider.removeExercise(exercise.id);
              },
              onAddSet: () => provider.addSet(exercise.id),
              onCopySet: () => provider.copyPreviousSet(exercise.id),
              onUpdateSet: (set) => provider.updateSet(exercise.id, set.id, set),
              onDeleteSet: (setId) => provider.removeSet(exercise.id, setId),
              onUpdateNotes: (notes) => provider.updateExerciseNotes(exercise.id, notes),
            ),
          ),
          const SizedBox(height: 12),
          _MetricsRow(provider: provider),
        ],
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _metric('Series', provider.totalSets.toString()),
          _metric('Reps', provider.totalReps.toString()),
          _metric('Volumen', provider.totalVolume.toStringAsFixed(1)),
          _metric('RIR prom',
              provider.averageRir != null ? provider.averageRir!.toStringAsFixed(1) : '--'),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CardioSection extends StatelessWidget {
  const _CardioSection({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cardio', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Tipo de cardio (running, bici, remo...)',
              prefixIcon: Icon(Icons.directions_run),
            ),
            onChanged: provider.setActivityName,
            controller: TextEditingController(text: provider.activityName)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.activityName?.length ?? 0),
              ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setDuration(int.tryParse(v)),
                  controller: TextEditingController(
                    text: provider.durationMinutes?.toString() ?? '',
                  )..selection = TextSelection.fromPosition(
                      TextPosition(offset: provider.durationMinutes?.toString().length ?? 0),
                    ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Distancia (km)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setDistance(double.tryParse(v)),
                  controller: TextEditingController(
                    text: provider.distanceKm?.toString() ?? '',
                  )..selection = TextSelection.fromPosition(
                      TextPosition(offset: provider.distanceKm?.toString().length ?? 0),
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Ritmo/velocidad',
              prefixIcon: Icon(Icons.speed),
            ),
            onChanged: provider.setPace,
            controller: TextEditingController(text: provider.pace)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.pace?.length ?? 0),
              ),
          ),
          const SizedBox(height: 8),
          _IntensityRow(provider: provider),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Notas',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 3,
            onChanged: provider.setNotes,
            controller: TextEditingController(text: provider.notes)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.notes?.length ?? 0),
              ),
          ),
        ],
      ),
    );
  }
}

class _SportSection extends StatelessWidget {
  const _SportSection({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Deporte', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Actividad / Deporte',
              prefixIcon: Icon(Icons.sports_soccer),
            ),
            onChanged: provider.setActivityName,
            controller: TextEditingController(text: provider.activityName)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.activityName?.length ?? 0),
              ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setDuration(int.tryParse(v)),
                  controller: TextEditingController(
                    text: provider.durationMinutes?.toString() ?? '',
                  )..selection = TextSelection.fromPosition(
                      TextPosition(offset: provider.durationMinutes?.toString().length ?? 0),
                    ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Distancia (km)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setDistance(double.tryParse(v)),
                  controller: TextEditingController(
                    text: provider.distanceKm?.toString() ?? '',
                  )..selection = TextSelection.fromPosition(
                      TextPosition(offset: provider.distanceKm?.toString().length ?? 0),
                    ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IntensityRow(provider: provider),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Notas',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 3,
            onChanged: provider.setNotes,
            controller: TextEditingController(text: provider.notes)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.notes?.length ?? 0),
              ),
          ),
        ],
      ),
    );
  }
}

class _FunctionalSection extends StatelessWidget {
  const _FunctionalSection({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(provider.selectedType == WorkoutType.custom ? 'Sesión personalizada' : 'Funcional',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Nombre de la sesión',
              prefixIcon: Icon(Icons.event_note),
            ),
            onChanged: provider.setActivityName,
            controller: TextEditingController(text: provider.activityName)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.activityName?.length ?? 0),
              ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Duración (min)',
                    prefixIcon: Icon(Icons.timer),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setDuration(int.tryParse(v)),
                  controller: TextEditingController(
                    text: provider.durationMinutes?.toString() ?? '',
                  )..selection = TextSelection.fromPosition(
                      TextPosition(offset: provider.durationMinutes?.toString().length ?? 0),
                    ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntensityRow(provider: provider),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Notas',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 3,
            onChanged: provider.setNotes,
            controller: TextEditingController(text: provider.notes)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.notes?.length ?? 0),
              ),
          ),
        ],
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

class _ClosingSection extends StatelessWidget {
  const _ClosingSection({required this.provider});

  final WorkoutProProvider provider;

  @override
  Widget build(BuildContext context) {
    return SummaryCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cierre', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Duración total (min)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => provider.setClosingDuration(int.tryParse(v)),
                  controller: TextEditingController(
                    text: provider.closingDuration?.toString() ?? '',
                  )..selection = TextSelection.fromPosition(
                      TextPosition(offset: provider.closingDuration?.toString().length ?? 0),
                    ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Fatiga general (1-5)'),
                  value: provider.closingFatigue,
                  items: List.generate(
                    5,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('${index + 1}'),
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) provider.setClosingFatigue(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Rendimiento percibido (1-5)'),
            value: provider.closingPerformance,
            items: List.generate(
              5,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text('${index + 1}'),
              ),
            ),
            onChanged: (v) {
              if (v != null) provider.setClosingPerformance(v);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Notas finales',
              prefixIcon: Icon(Icons.note_alt_outlined),
            ),
            maxLines: 3,
            onChanged: provider.setFinalNotes,
            controller: TextEditingController(text: provider.finalNotes)
              ..selection = TextSelection.fromPosition(
                TextPosition(offset: provider.finalNotes?.length ?? 0),
              ),
          ),
        ],
      ),
    );
  }
}
