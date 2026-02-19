import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/theme/app_colors.dart';
import '../pro/models/workout_models.dart';
import 'folder_routines_screen.dart';
import 'routine_preview_screen.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';
import 'training_home_widgets.dart';

class TrainingHomeScreen extends StatelessWidget {
  const TrainingHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TrainingHomeController()..initialize(),
      child: const _TrainingHomeView(),
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

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingHomeController>();
    if (!controller.initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final todayStatus = controller.hasSessionToday ? 'Hoy: sesión registrada' : 'Hoy: sin sesión registrada';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
        actions: [
          IconButton(onPressed: () => Navigator.of(context).pushNamed('/workout/history'), icon: const Icon(Icons.history)),
          IconButton(onPressed: () => Navigator.of(context).pushNamed('/workout/settings'), icon: const Icon(Icons.tune)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(todayStatus, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
            if (controller.latestSession != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Última sesión: ${_lastSessionLabel(controller.latestSession!)} · ${_daysAgoLabel(controller.latestSession!.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
            const SizedBox(height: 14),
            PrimaryStartWorkoutCard(
              onTap: () => Navigator.of(context).pushNamed('/workout/session', arguments: {'trainingContext': 'Gym'}),
            ),
            const SizedBox(height: 20),
            Text('Rutinas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: RoutineActionTile(
                      title: 'Nueva rutina',
                      subtitle: 'Crear desde cero o duplicar',
                      icon: Icons.description_outlined,
                      onTap: () => _goAndRefresh(context, controller, '/workout/routines/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RoutineActionTile(
                      title: 'Buscar rutinas',
                      subtitle: 'Explorar plantillas',
                      icon: Icons.search,
                      onTap: () => _goAndRefresh(context, controller, '/workout/routines/search'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!controller.hasRoutines)
              const EmptyRoutinesInfoCard()
            else ...[
              Row(
                children: [
                  Text('Mis rutinas', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showCreateFolderSheet(context, controller),
                    icon: const Icon(Icons.create_new_folder_outlined),
                    tooltip: 'Crear carpeta',
                  ),
                  TextButton.icon(onPressed: () => _showSortSheet(context, controller), icon: const Icon(Icons.sort), label: const Text('Ordenar')),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Todas')),
                  ButtonSegment(value: 1, label: Text('Carpetas')),
                ],
                selected: {_routinesViewIndex},
                onSelectionChanged: (value) => setState(() => _routinesViewIndex = value.first),
              ),
              const SizedBox(height: 10),
              if (_routinesViewIndex == 0)
                _routinesGrid(controller.routines, controller)
              else
                _foldersGrid(context, controller),
            ],
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 125,
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
          onMenuSelected: (value) => _handleFolderMenuAction(context, controller, folder, value),
        );
      },
    );
  }

  Widget _routinesGrid(List<WorkoutTemplate> routines, TrainingHomeController controller) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: routines.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final routine = routines[index];
        final metadata = controller.metadataFor(routine.id);
        final typeLabel = _typeLabel(routine.type);
        final previewExercises = routine.exercises.map((exercise) => exercise.name).where((name) => name.trim().isNotEmpty).toList(growable: false);
        return RoutineMiniCard(
          title: routine.name,
          typeTag: typeLabel,
          secondaryTag: routine.activityName,
          exercisePreview: previewExercises,
          exerciseCount: routine.exercises.length,
          estimatedMinutes: controller.estimatedDuration(routine),
          lastUsed: 'Última vez: ${_daysAgoLabel(metadata.lastUsedAt)}',
          isPinned: metadata.pinned,
          onTap: () => _openRoutinePreview(context, controller, routine),
          onStartTap: () => startRoutineFlow(context, controller, routine),
          onMenuSelected: (value) => _handleMenuAction(context, controller, routine, value),
        );
      },
    );
  }

  Future<void> _showCreateFolderSheet(BuildContext context, TrainingHomeController controller) async {
    final nameController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Crear carpeta'),
            const SizedBox(height: 10),
            TextField(controller: nameController, autofocus: true, decoration: const InputDecoration(hintText: 'Nombre de carpeta')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  await controller.createFolder(name);
                  if (mounted) Navigator.of(context).pop();
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMoveToFolderSheet(BuildContext context, TrainingHomeController controller, WorkoutTemplate routine) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Mover a carpeta'), subtitle: Text(routine.name)),
            ListTile(
              title: const Text('Sin carpeta'),
              onTap: () async {
                await controller.moveRoutineToFolder(routine, null);
                if (mounted) Navigator.pop(context);
              },
            ),
            ...controller.sortedFolders.map(
              (folder) => ListTile(
                title: Text(folder.name),
                onTap: () async {
                  await controller.moveRoutineToFolder(routine, folder.id);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFolderRoutines(BuildContext context, String? folderId, String folderName) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FolderRoutinesScreen(folderId: folderId, folderName: folderName)),
    );
  }

  Future<void> _handleFolderMenuAction(
    BuildContext context,
    TrainingHomeController controller,
    RoutineFolder folder,
    String action,
  ) async {
    if (action == 'rename') {
      final c = TextEditingController(text: folder.name);
      final updated = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Renombrar carpeta'),
          content: TextField(controller: c, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(c.text.trim()), child: const Text('Guardar')),
          ],
        ),
      );
      if (updated != null && updated.isNotEmpty) {
        await controller.renameFolder(folder.id, updated);
      }
      return;
    }
    if (action == 'delete') {
      await controller.deleteFolder(folder.id);
    }
  }

  Future<void> _showSortSheet(BuildContext context, TrainingHomeController controller) async {
    final selected = await showModalBottomSheet<RoutineSortOption>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: RoutineSortOption.values
              .map((option) => RadioListTile<RoutineSortOption>(
                    value: option,
                    groupValue: controller.sortOption,
                    onChanged: (value) => Navigator.of(context).pop(value),
                    title: Text(_sortLabel(option)),
                  ))
              .toList(),
        ),
      ),
    );
    if (selected != null) await controller.setSortOption(selected);
  }

  Future<void> _handleMenuAction(BuildContext context, TrainingHomeController controller, WorkoutTemplate routine, String action) async {
    if (action == 'menu') return;
    switch (action) {
      case 'edit':
        final controllerName = TextEditingController(text: routine.name);
        final updated = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Editar rutina'),
            content: TextField(controller: controllerName, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.of(context).pop(controllerName.text.trim()), child: const Text('Guardar')),
            ],
          ),
        );
        if (updated != null && updated.isNotEmpty) await controller.renameRoutine(routine, updated);
        break;
      case 'duplicate':
        await controller.duplicateRoutine(routine);
        break;
      case 'pin':
        await controller.togglePinned(routine);
        break;
      case 'move':
        await _openMoveToFolderSheet(context, controller, routine);
        break;
      case 'delete':
        await controller.deleteRoutine(routine);
        break;
    }
  }

  Future<void> _openRoutinePreview(BuildContext context, TrainingHomeController controller, WorkoutTemplate routine) async {
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

  Future<void> _goAndRefresh(BuildContext context, TrainingHomeController controller, String route) async {
    await Navigator.of(context).pushNamed(route);
    await controller.refresh();
  }

  String _daysAgoLabel(DateTime? date) {
    if (date == null) return 'Nunca';
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return 'hoy';
    if (days == 1) return 'hace 1 día';
    return 'hace $days días';
  }

  String _lastSessionLabel(WorkoutSession session) {
    return session.templateName ?? session.activityName ?? _typeLabel(session.type);
  }

  String _typeLabel(WorkoutType type) {
    switch (type) {
      case WorkoutType.strength:
        return 'Gym';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.functional:
        return 'Funcional';
      case WorkoutType.sport:
        return 'Outdoor';
      case WorkoutType.custom:
        return 'Custom';
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

class WorkoutHistoryPlaceholderScreen extends StatelessWidget {
  const WorkoutHistoryPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TrainingHomeController()..initialize(),
      child: Consumer<TrainingHomeController>(
        builder: (context, c, _) {
          if (!c.initialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final sessions = c.sessions;
          return Scaffold(
            appBar: AppBar(title: const Text('Historial de entrenamientos')),
            body: sessions.isEmpty
                ? const Center(child: Text('Aún no hay sesiones registradas.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final session in sessions.reversed)
                        Card(
                          child: ListTile(
                            title: Text(session.templateName ?? session.activityName ?? 'Entrenamiento'),
                            subtitle: Text('${session.date.day}/${session.date.month}/${session.date.year} · ${session.exercises.length} ejercicios'),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class WorkoutSettingsPlaceholderScreen extends StatelessWidget {
  const WorkoutSettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(title: 'Ajustes de entrenamiento', message: 'TODO: configurar preferencias del módulo.');
  }
}

class WorkoutRoutineSearchPlaceholderScreen extends StatelessWidget {
  const WorkoutRoutineSearchPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar rutinas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TextField(decoration: InputDecoration(hintText: 'Buscar por nombre', prefixIcon: Icon(Icons.search))),
          SizedBox(height: 16),
          Text('TODO: conectar biblioteca de plantillas real.'),
        ],
      ),
    );
  }
}

class WorkoutRoutineCreatePlaceholderScreen extends StatelessWidget {
  const WorkoutRoutineCreatePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(title: 'Nueva rutina', message: 'TODO: conectar editor completo de rutinas.');
  }
}

class _PlaceholderScaffold extends StatelessWidget {
  const _PlaceholderScaffold({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)), body: Center(child: Text(message)));
  }
}
