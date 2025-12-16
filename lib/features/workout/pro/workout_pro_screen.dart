import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/statistics_service.dart';
import '../../common/theme/app_colors.dart';
import '../../common/widgets/summary_card.dart';
import 'data/exercise_definition.dart';
import 'data/exercise_library.dart';
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
}

class _WorkoutProContent extends StatefulWidget {
  const _WorkoutProContent();

  @override
  State<_WorkoutProContent> createState() => _WorkoutProContentState();
}

class _WorkoutProContentState extends State<_WorkoutProContent> {
  late final ExerciseLibraryIndex _exerciseIndex;
  final _scrollController = ScrollController();
  final _configKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _exerciseIndex = ExerciseLibraryIndex(exerciseLibrary);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProProvider>();

    return Scaffold(
      body: provider.initialized
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F1826),
                    Color(0xFF0C1220),
                  ],
                ),
              ),
              child: SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      titleSpacing: 0,
                      backgroundColor: Colors.transparent,
                      title: _AppBarTitle(
                        dateLabel: StatisticsService.formatShortDate(DateTime.now()),
                      ),
                      actions: [
                        IconButton(
                          onPressed: _scrollToConfiguration,
                          icon: const Icon(Icons.tune, size: 20),
                          tooltip: 'Ajustes rápidos',
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) => _handleMenuAction(context, provider, value),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: 'save_template',
                              child: Text('Guardar como plantilla'),
                            ),
                            PopupMenuItem(
                              value: 'load_template',
                              child: Text('Cargar plantilla'),
                            ),
                            PopupMenuItem(
                              value: 'reset',
                              child: Text('Reiniciar entrenamiento'),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Text('Exportar JSON (debug)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SessionHeroCard(
                              provider: provider,
                              onAddExercise: () => _openAddExercise(context, provider),
                              onConfigure: _scrollToConfiguration,
                            ),
                            const SizedBox(height: 24),
                            _ConfigurationCard(
                              key: _configKey,
                              provider: provider,
                              onConfirmTypeChange: _confirmDialog,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    _buildDynamicSection(provider),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: WorkoutBottomBar(
        exerciseCount: provider.selectedType == WorkoutType.strength ? provider.totalExercises : 0,
        setCount: provider.selectedType == WorkoutType.strength ? provider.totalSets : 0,
        durationLabel: provider.getDurationLabel(),
        onAddExercise: () => _openAddExercise(context, provider),
        onSave: () => _saveSession(context, provider, finalize: false),
        onFinish: () => _showFinishSheet(context, provider),
      ),
    );
  }

  void _scrollToConfiguration() {
    final context = _configKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  SliverToBoxAdapter _buildDynamicSection(WorkoutProProvider provider) {
    switch (provider.selectedType) {
      case WorkoutType.strength:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StrengthSection(
              provider: provider,
              exerciseIndex: _exerciseIndex,
              onAddExercise: () => _openAddExercise(context, provider),
            ),
          ),
        );
      case WorkoutType.cardio:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleWorkoutSection(
              provider: provider,
              title: 'Cardio',
            ),
          ),
        );
      case WorkoutType.functional:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleWorkoutSection(
              provider: provider,
              title: 'Funcional',
            ),
          ),
        );
      case WorkoutType.sport:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleWorkoutSection(
              provider: provider,
              title: 'Deporte',
            ),
          ),
        );
      case WorkoutType.custom:
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SimpleWorkoutSection(
              provider: provider,
              title: 'Otro',
            ),
          ),
        );
    }
  }

  Future<void> _showFinishSheet(BuildContext context, WorkoutProProvider provider) async {
    final durationController = TextEditingController(
      text: provider.closingDuration?.toString() ?? provider.durationMinutes?.toString() ?? '',
    );
    final notesController = TextEditingController(text: provider.finalNotes ?? '');
    int? fatigue = provider.closingFatigue;
    int? performance = provider.closingPerformance;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Registrar cierre', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duración total (min)',
                      prefixIcon: Icon(Icons.timer_outlined),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        provider.setClosingDuration(int.tryParse(value)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: fatigue,
                          decoration: const InputDecoration(
                            labelText: 'Fatiga general (1-5)',
                            isDense: true,
                          ),
                          items: List.generate(
                            5,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          )
                            ..insert(
                              0,
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Sin dato'),
                              ),
                            ),
                          onChanged: (v) {
                            setState(() => fatigue = v);
                            provider.setClosingFatigue(v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: performance,
                          decoration: const InputDecoration(
                            labelText: 'Performance (1-5)',
                            isDense: true,
                          ),
                          items: List.generate(
                            5,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text('${index + 1}'),
                            ),
                          )
                            ..insert(
                              0,
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Sin dato'),
                              ),
                            ),
                          onChanged: (v) {
                            setState(() => performance = v);
                            provider.setClosingPerformance(v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas finales',
                      prefixIcon: Icon(Icons.note_alt_outlined),
                      isDense: true,
                    ),
                    maxLines: 3,
                    onChanged: (value) => provider.setFinalNotes(
                      value.isEmpty ? null : value,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () async {
                          provider.clearClosing();
                          Navigator.of(sheetContext).pop();
                          await _saveSession(context, provider, finalize: true);
                        },
                        child: const Text('Saltar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          provider.setClosingDuration(int.tryParse(durationController.text));
                          provider.setClosingFatigue(fatigue);
                          provider.setClosingPerformance(performance);
                          provider.setFinalNotes(notesController.text.isEmpty ? null : notesController.text);
                          Navigator.of(sheetContext).pop();
                          await _saveSession(context, provider, finalize: true);
                        },
                        child: const Text('Finalizar'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    durationController.dispose();
    notesController.dispose();
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
        Text(
          'Entrenamiento',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }
}

class _SessionHeroCard extends StatelessWidget {
  const _SessionHeroCard({
    required this.provider,
    required this.onAddExercise,
    required this.onConfigure,
  });

  final WorkoutProProvider provider;
  final VoidCallback onAddExercise;
  final VoidCallback onConfigure;

  String _typeLabel() {
    switch (provider.selectedType) {
      case WorkoutType.strength:
        return 'Sesión de Fuerza';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.functional:
        return 'Funcional';
      case WorkoutType.sport:
        return 'Deporte';
      case WorkoutType.custom:
        return provider.customTypeName?.isNotEmpty == true
            ? provider.customTypeName!
            : 'Sesión personal';
    }
  }

  String _primaryDurationLabel() {
    final diff = DateTime.now().difference(provider.sessionStart);
    final minutes = diff.inMinutes;
    if (minutes >= 60) {
      final hours = diff.inHours;
      final remainder = minutes - hours * 60;
      return remainder == 0 ? '${hours}h' : '${hours}h ${remainder.toString().padLeft(2, '0')}m';
    }
    final secs = diff.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final miniTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.textMuted,
        );
    final valueStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontSize: 13,
        );

    return SummaryCard(
      padding: const EdgeInsets.all(18),
      minHeight: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.fitness_center, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _typeLabel(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      provider.selectedTemplate?.name ?? 'Sin plantilla',
                      style: miniTextStyle,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 8, color: AppColors.accent),
                    SizedBox(width: 6),
                    Text('Borrador', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _primaryDurationLabel(),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 40,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(width: 10),
              Text('activo', style: miniTextStyle),
              const Spacer(),
              FilledButton(
                onPressed: onAddExercise,
                child: const Text('Agregar ejercicio'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onConfigure,
                child: const Text('Configurar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _miniMetric('Ejercicios', provider.totalExercises.toString(), valueStyle, miniTextStyle),
              _miniMetric('Series', provider.totalSets.toString(), valueStyle, miniTextStyle),
              _miniMetric('Volumen', '${provider.totalVolume.toStringAsFixed(0)} kg', valueStyle, miniTextStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, TextStyle? valueStyle, TextStyle? miniStyle) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: valueStyle?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: miniStyle),
        ],
      ),
    );
  }
}

class _ConfigurationCard extends StatefulWidget {
  const _ConfigurationCard({super.key, required this.provider, required this.onConfirmTypeChange});

  final WorkoutProProvider provider;
  final Future<bool> Function(BuildContext context, String message) onConfirmTypeChange;

  @override
  State<_ConfigurationCard> createState() => _ConfigurationCardState();
}

class _ConfigurationCardState extends State<_ConfigurationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _SettingRow(
        label: 'Tipo',
        value: _typeLabel(widget.provider),
        onTap: () => _openTypeSelector(),
      ),
      _SettingRow(
        label: 'Plantilla',
        value: widget.provider.selectedTemplate?.name ?? 'Sin plantilla',
        onTap: () => _openTemplateSelector(context),
      ),
      _SettingRow(
        label: 'Modo',
        value: 'Libre',
        onTap: () => _openTemplateSelector(context),
      ),
      _SettingRow(
        label: 'Descanso',
        value: 'Auto',
        onTap: () {},
      ),
    ];

    return SummaryCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Configuración',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Ver menos' : 'Ver más'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_expanded ? rows.length : 2, (index) => rows[index]),
            if (!_expanded) const Divider(height: 20, color: AppColors.borderSubtle),
            if (!_expanded)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = true),
                  icon: const Icon(Icons.unfold_more),
                  label: const Text('Más opciones'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openTypeSelector() async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: WorkoutTypeSelector(
          selected: widget.provider.selectedType,
          customName: widget.provider.customTypeName,
          onCustomNameChanged: widget.provider.setCustomTypeName,
          onSelected: (type) async {
            if (widget.provider.selectedType == WorkoutType.strength &&
                type != WorkoutType.strength &&
                widget.provider.exercises.isNotEmpty) {
              final confirmed = await widget.onConfirmTypeChange(
                context,
                'Cambiar tipo borrará ejercicios. ¿Continuar?',
              );
              if (!confirmed) return;
              widget.provider.setType(type, force: true);
            } else {
              widget.provider.setType(type);
            }
            Navigator.of(ctx).pop();
          },
        ),
      ),
    );
  }

  void _openTemplateSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => TemplateSection(
        standardTemplates: widget.provider.standardTemplates,
        userTemplates: widget.provider.userTemplates,
        selected: widget.provider.selectedTemplate,
        suggestions: widget.provider.suggestedTemplates(),
        onSelect: (template) {
          widget.provider.selectTemplate(template);
          Navigator.of(context).pop();
        },
        onClear: widget.provider.clearTemplate,
      ),
    );
  }

  String _typeLabel(WorkoutProProvider provider) {
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.borderSubtle),
      ],
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
    required this.onAddExercise,
  });

  final WorkoutProProvider provider;
  final ExerciseLibraryIndex exerciseIndex;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    final hasExercises = provider.exercises.isNotEmpty;

    final suggested = [
      ...provider.recentExercises,
      ...provider.mostUsedExercises,
      'Press banca',
      'Dominadas',
      'Sentadilla',
      'Peso muerto',
      'Remo con barra',
    ]
        .toSet()
        .take(14)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SummaryCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Ejercicios',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (hasExercises)
                    TextButton.icon(
                      onPressed: () => _openAddExercise(context, provider),
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar'),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: hasExercises
                    ? Column(
                        key: const ValueKey('list'),
                        children: [
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.exercises.length,
                            onReorder: provider.reorderExercise,
                            itemBuilder: (context, index) {
                              final exercise = provider.exercises[index];
                              final definition = exerciseIndex.findByQuery(exercise.name);
                              return Padding(
                                key: ValueKey(exercise.id),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ExerciseCard(
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
                                  onRestoreSet: (setIndex, set) =>
                                      provider.insertSet(exercise.id, setIndex, set),
                                  onUpdateNotes: (notes) => provider.updateExerciseNotes(exercise.id, notes),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(top: 8),
                            title: const Text('Métricas (opcional)'),
                            children: [
                              _MetricsRow(provider: provider),
                            ],
                          ),
                        ],
                      )
                    : _EmptyExercisesState(onAddExercise: onAddExercise, onOpenLibrary: () => _openAddExercise(context, provider)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SuggestedChips(
          suggestions: suggested,
          onPick: (name) => _addSuggested(name, context),
          onOpenLibrary: () => _openAddExercise(context, provider),
        ),
      ],
    );
  }


  void _addSuggested(String name, BuildContext context) {
    if (name == '__open_selector__') {
      _openAddExercise(context, provider);
      return;
    }

    final match = exerciseIndex.findByQuery(name);
    final exercise = match != null
        ? provider.fromDefinition(match)
        : WorkoutExercise(
            id: const Uuid().v4(),
            name: name,
          );
    provider.addExerciseWithDefaults(exercise);
  }
}

class _EmptyExercisesState extends StatelessWidget {
  const _EmptyExercisesState({required this.onAddExercise, required this.onOpenLibrary});

  final VoidCallback onAddExercise;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.fitness_center_outlined, size: 46, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          Text(
            'Agregá tu primer ejercicio',
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Registrá series, reps y peso.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAddExercise,
              child: const Text('Agregar primer ejercicio'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onOpenLibrary,
            child: const Text('Buscar en biblioteca'),
          ),
        ],
      ),
    );
  }
}

class _SuggestedChips extends StatelessWidget {
  const _SuggestedChips({
    required this.suggestions,
    required this.onPick,
    required this.onOpenLibrary,
  });

  final List<String> suggestions;
  final ValueChanged<String> onPick;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Sugeridos',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const Spacer(),
            TextButton(
              onPressed: onOpenLibrary,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Ver más'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final name = suggestions[i];
              return InkWell(
                onTap: () => onPick(name),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
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

