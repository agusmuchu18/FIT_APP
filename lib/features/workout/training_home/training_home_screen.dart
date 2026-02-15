import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/theme/app_colors.dart';
import '../pro/models/workout_models.dart';
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
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TrainingHomeController>();
    if (!controller.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final todayStatus = controller.hasSessionToday ? 'Hoy: sesión registrada' : 'Hoy: sin sesión registrada';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/workout/history'),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/workout/settings'),
            icon: const Icon(Icons.tune),
          ),
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
              onTap: () => Navigator.of(context).pushNamed(
                '/workout/session',
                arguments: {'trainingContext': 'Gym'},
              ),
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
            if (!controller.hasRoutines) const EmptyRoutinesInfoCard()
            else ...[
              Row(
                children: [
                  Text('Mis rutinas', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _showSortSheet(context, controller),
                    icon: const Icon(Icons.sort),
                    label: const Text('Ordenar'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.routines.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 185,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final routine = controller.routines[index];
                    final metadata = controller.metadataFor(routine.id);
                    final typeLabel = _typeLabel(routine.type);
                    final previewExercises = routine.exercises
                        .map((exercise) => exercise.name)
                        .where((name) => name.trim().isNotEmpty)
                        .toList(growable: false);
                    return RoutineMiniCard(
                      title: routine.name,
                      typeTag: typeLabel,
                      secondaryTag: routine.activityName,
                      exercisePreview: previewExercises,
                      exerciseCount: routine.exercises.length,
                      estimatedMinutes: controller.estimatedDuration(routine),
                      lastUsed: 'Última vez: ${_daysAgoLabel(metadata.lastUsedAt)}',
                      isPinned: metadata.pinned,
                      onTap: () => _startRoutine(context, controller, routine),
                      onMenuSelected: (value) => _handleMenuAction(context, controller, routine, value),
                    );
                  },
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _showSortSheet(BuildContext context, TrainingHomeController controller) async {
    final selected = await showModalBottomSheet<RoutineSortOption>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: RoutineSortOption.values
              .map(
                (option) => RadioListTile<RoutineSortOption>(
                  value: option,
                  groupValue: controller.sortOption,
                  onChanged: (value) => Navigator.of(context).pop(value),
                  title: Text(_sortLabel(option)),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      await controller.setSortOption(selected);
    }
  }


  Future<void> _handleMenuAction(
    BuildContext context,
    TrainingHomeController controller,
    WorkoutTemplate routine,
    String action,
  ) async {
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
        if (updated != null && updated.isNotEmpty) {
          await controller.renameRoutine(routine, updated);
        }
        break;
      case 'duplicate':
        await controller.duplicateRoutine(routine);
        break;
      case 'pin':
        await controller.togglePinned(routine);
        break;
      case 'delete':
        await controller.deleteRoutine(routine);
        break;
    }
  }

  Future<void> _startRoutine(BuildContext context, TrainingHomeController controller, WorkoutTemplate routine) async {
    await controller.markRoutineStarted(routine);
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed('/workout/session', arguments: {'templateId': routine.id});
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
    return const _PlaceholderScaffold(
      title: 'Historial de entrenamientos',
      message: 'TODO: conectar historial real de sesiones.',
    );
  }
}

class WorkoutSettingsPlaceholderScreen extends StatelessWidget {
  const WorkoutSettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(
      title: 'Ajustes de entrenamiento',
      message: 'TODO: configurar preferencias del módulo.',
    );
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
        children: [
          const TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por nombre',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Plantilla Full Body Básica'),
              subtitle: const Text('3 ejercicios · Importable'),
              trailing: FilledButton.tonal(
                onPressed: null,
                child: Text('Próximamente'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('TODO: conectar biblioteca de plantillas real.'),
        ],
      ),
    );
  }
}

class WorkoutRoutineCreatePlaceholderScreen extends StatelessWidget {
  const WorkoutRoutineCreatePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScaffold(
      title: 'Nueva rutina',
      message: 'TODO: conectar editor completo de rutinas.',
    );
  }
}

class _PlaceholderScaffold extends StatelessWidget {
  const _PlaceholderScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(message)),
    );
  }
}
