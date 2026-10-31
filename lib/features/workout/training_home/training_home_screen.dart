import '../../../app/theme/app_theme.dart';
import 'routine_library_card.dart';
import 'routine_library_actions.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/theme/app_colors.dart';
import '../../common/widgets/fit_glyph.dart';
import '../pro/models/workout_models.dart';
import 'folder_routines_screen.dart';
import 'routine_preview_screen.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';
import 'training_home_widgets.dart';
import 'training_programs_screen.dart';
import '../presentation/workout_insights_screen.dart';
import '../domain/relative_day_label.dart';
import '../workout_in_progress_controller.dart';

class TrainingHomeScreen extends StatelessWidget {
  const TrainingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.workoutFor(Theme.of(context)),
      child: ChangeNotifierProvider(
        create: (_) => TrainingHomeController()..initialize(),
        child: const _TrainingHomeView(),
      ),
    );
  }
}

class _TrainingHomeView extends StatefulWidget {
  const _TrainingHomeView();

  @override
  State<_TrainingHomeView> createState() => _TrainingHomeViewState();
}

class _TrainingHomeViewState extends State<_TrainingHomeView> {
  int _routinesViewIndex = 0;
  bool _navigating = false;
  WorkoutType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingHomeController>();
    if (!controller.initialized) {
      if (controller.loadError != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Entrenamiento')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No se pudieron cargar tus entrenamientos. Tus datos se conservan.',
                  ),
                  FilledButton(
                    onPressed: controller.initialize,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final todayStatus = controller.hasSessionToday
        ? 'Hoy: sesión registrada'
        : 'Hoy: sin sesión registrada';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/workout/history'),
            icon: const FitGlyph(kind: FitGlyphKind.history),
            tooltip: 'Historial',
          ),
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/workout/settings'),
            icon: const FitGlyph(kind: FitGlyphKind.settings),
            tooltip: 'Ajustes de entrenamiento',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.loadError != null)
                      TextButton(
                        onPressed: controller.refresh,
                        child: const Text('No se pudo actualizar. Reintentar'),
                      ),
                    Text(
                      todayStatus,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    if (controller.latestSession != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Última sesión: ${_lastSessionLabel(controller.latestSession!)} · ${_daysAgoLabel(controller.latestSession!.date)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder(
                      valueListenable: WorkoutInProgressController.instance
                          .watchDraft(),
                      builder: (context, draft, _) => PrimaryStartWorkoutCard(
                        activeWorkoutName: draft?.routineName,
                        onTap: () => _goAndRefresh(
                          context,
                          controller,
                          '/workout/session',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Rutinas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height:
                          152 *
                          (MediaQuery.textScalerOf(context).scale(16) / 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: RoutineActionTile(
                              title: 'Nueva rutina',
                              subtitle: 'Crear desde cero o duplicar',
                              glyph: FitGlyphKind.routine,
                              imageAsset:
                                  'assets/images/workout/routine_builder.webp',
                              onTap: () => _goAndRefresh(
                                context,
                                controller,
                                '/workout/routines/new',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RoutineActionTile(
                              title: 'Buscar rutinas',
                              subtitle: 'Explorar plantillas',
                              glyph: FitGlyphKind.discover,
                              imageAsset:
                                  'assets/images/workout/equipment_detail.webp',
                              onTap: () => _goAndRefresh(
                                context,
                                controller,
                                '/workout/routines/search',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: '/workout/programs',
                                ),
                                builder: (_) => const TrainingProgramsScreen(),
                              ),
                            );
                            if (context.mounted) await controller.refresh();
                          },
                          icon: const Icon(Icons.calendar_view_week_outlined),
                          label: const Text('Programas'),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: '/workout/insights',
                                ),
                                builder: (_) => const WorkoutInsightsScreen(),
                              ),
                            );
                            if (context.mounted) await controller.refresh();
                          },
                          icon: const Icon(Icons.insights_outlined),
                          label: const Text('Mi progreso'),
                        ),
                      ],
                    ),
                    if (!controller.hasRoutines)
                      const EmptyRoutinesInfoCard()
                    else ...[
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'Mis rutinas',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            onPressed: () =>
                                _showCreateFolderSheet(context, controller),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            tooltip: 'Crear carpeta',
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _showSortSheet(context, controller),
                            icon: const Icon(Icons.sort),
                            label: const Text('Ordenar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Todas')),
                          ButtonSegment(value: 1, label: Text('Carpetas')),
                        ],
                        selected: {_routinesViewIndex},
                        onSelectionChanged: (value) =>
                            setState(() => _routinesViewIndex = value.first),
                      ),
                      const SizedBox(height: 10),
                      if (_routinesViewIndex == 0)
                        DropdownButtonFormField<WorkoutType>(
                          isExpanded: true,
                          initialValue: _typeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de rutina',
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Todos')),
                            DropdownMenuItem(
                              value: WorkoutType.strength,
                              child: Text('Gimnasio'),
                            ),
                            DropdownMenuItem(
                              value: WorkoutType.sport,
                              child: Text('Deporte'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _typeFilter = v),
                        )
                      else
                        _foldersGrid(context, controller),
                    ],
                  ],
                ),
              ),
            ),
            if (_routinesViewIndex == 0 && controller.hasRoutines)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: _routinesList(controller),
              ),
            SliverToBoxAdapter(
              child: ValueListenableBuilder(
                valueListenable: WorkoutInProgressController.instance
                    .watchDraft(),
                builder: (context, draft, _) => SizedBox(
                  height: draft == null
                      ? MediaQuery.paddingOf(context).bottom
                      : MediaQuery.textScalerOf(context).scale(96) +
                            MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foldersGrid(BuildContext context, TrainingHomeController controller) {
    final totalWithoutFolder = controller.routinesForFolder(null).length;
    final sortedFolders = controller.sortedFolders;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedFolders.length + 1,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: MediaQuery.textScalerOf(context).scale(16) > 24
            ? MediaQuery.sizeOf(context).width
            : 320,
        mainAxisExtent: 125 * (MediaQuery.textScalerOf(context).scale(16) / 16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        if (index == 0) {
          return RoutineFolderCard(
            name: 'Sin carpeta',
            count: totalWithoutFolder,
            isVirtual: true,
            onTap: () => _openFolderRoutines(context, null, 'Sin carpeta'),
          );
        }
        final folder = sortedFolders[index - 1];
        return RoutineFolderCard(
          name: folder.name,
          count: controller.routinesForFolder(folder.id).length,
          onTap: () => _openFolderRoutines(context, folder.id, folder.name),
          onMenuSelected: (value) =>
              _handleFolderMenuAction(context, controller, folder, value),
        );
      },
    );
  }

  Widget _routinesList(TrainingHomeController controller) {
    final routines = controller.routines
        .where((r) => _typeFilter == null || r.type == _typeFilter)
        .toList();
    if (routines.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay rutinas de este tipo.'),
        ),
      );
    }
    return SliverList.builder(
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RoutineLibraryCard(
            routine: routine,
            pinned: controller.metadataFor(routine.id).pinned,
            lastUsed: controller.lastCompletedFor(routine.id) == null
                ? 'Sin estrenar'
                : 'Último entrenamiento: ${_daysAgoLabel(controller.lastCompletedFor(routine.id))}',
            onOpen: () => _openRoutinePreview(context, controller, routine),
            onStart: () => startRoutineFlow(context, controller, routine),
            onMenu: (value) =>
                _handleMenuAction(context, controller, routine, value),
          ),
        );
      },
    );
  }

  Future<void> _showCreateFolderSheet(
    BuildContext context,
    TrainingHomeController controller,
  ) async {
    var name = '';
    var creating = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Crear carpeta'),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => name = value,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Nombre de carpeta',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (name.trim().isEmpty || creating) return;
                          setSheetState(() => creating = true);
                          try {
                            await controller.createFolder(name.trim());
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          } catch (_) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo guardar la carpeta. El nombre se conserva; reintentá.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (sheetContext.mounted) {
                              setSheetState(() => creating = false);
                            }
                          }
                        },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFolderRoutines(
    BuildContext context,
    String? folderId,
    String folderName,
  ) {
    final controller = context.read<TrainingHomeController>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<TrainingHomeController>.value(
          value: controller,
          child: FolderRoutinesScreen(
            folderId: folderId,
            folderName: folderName,
          ),
        ),
      ),
    );
  }

  Future<void> _handleFolderMenuAction(
    BuildContext context,
    TrainingHomeController controller,
    RoutineFolder folder,
    String action,
  ) async {
    if (action == 'rename') {
      var editedName = folder.name;
      final updated = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Renombrar carpeta'),
          content: TextFormField(
            initialValue: editedName,
            onChanged: (v) => editedName = v,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(editedName.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (updated != null && updated.isNotEmpty) {
        try {
          await controller.renameFolder(folder.id, updated);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo renombrar la carpeta. Reintentá.'),
              ),
            );
          }
        }
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Eliminar carpeta?'),
          content: const Text(
            'Sus rutinas pasarán a Sin carpeta. Los entrenamientos realizados se conservan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await controller.deleteFolder(folder.id);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo eliminar la carpeta. Tus rutinas se conservan.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _showSortSheet(
    BuildContext context,
    TrainingHomeController controller,
  ) async {
    final selected = await showModalBottomSheet<RoutineSortOption>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: RadioGroup<RoutineSortOption>(
          groupValue: controller.sortOption,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: RoutineSortOption.values
                .map(
                  (option) => RadioListTile<RoutineSortOption>(
                    value: option,
                    title: Text(_sortLabel(option)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (selected != null) await controller.setSortOption(selected);
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    TrainingHomeController controller,
    WorkoutTemplate routine,
    String action,
  ) async {
    if (action == 'menu') return;
    await runRoutineLibraryAction(context, controller, routine, action);
  }

  Future<void> _openRoutinePreview(
    BuildContext context,
    TrainingHomeController controller,
    WorkoutTemplate routine,
  ) async {
    final metadata = controller.metadataFor(routine.id);
    final typeLabel = _typeLabel(routine.type);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutinePreviewScreen(
          routine: routine,
          controller: controller,
          typeLabel: typeLabel,
          lastUsedLabel: _daysAgoLabel(metadata.lastUsedAt),
        ),
      ),
    );
  }

  Future<void> _goAndRefresh(
    BuildContext context,
    TrainingHomeController controller,
    String route, {
    Object? arguments,
  }) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.of(context).pushNamed(route, arguments: arguments);
      if (!context.mounted) return;
      await controller.refresh();
    } finally {
      _navigating = false;
    }
  }

  String _daysAgoLabel(DateTime? date) => relativeDayLabel(date);

  String _lastSessionLabel(WorkoutSession session) {
    return session.templateName ??
        session.activityName ??
        _typeLabel(session.type);
  }

  String _typeLabel(WorkoutType type) {
    switch (type) {
      case WorkoutType.strength:
        return 'Gimnasio';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.functional:
        return 'Funcional';
      case WorkoutType.sport:
        return 'Deporte';
      case WorkoutType.custom:
        return 'Personalizado';
    }
  }

  String _sortLabel(RoutineSortOption option) {
    switch (option) {
      case RoutineSortOption.smart:
        return 'Inteligente (recomendado)';
      case RoutineSortOption.recent:
        return 'Más recientes';
      case RoutineSortOption.mostUsed:
        return 'Más usadas';
      case RoutineSortOption.alphabetical:
        return 'Alfabético';
    }
  }
}
