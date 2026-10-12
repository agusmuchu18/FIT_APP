import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/data/repositories.dart';
import '../../../app/theme/app_theme.dart';
import '../application/workout_session_controller.dart';
import '../pro/data/exercise_library.dart';
import '../pro/data/exercise_definition.dart';
import '../training_home/workout_settings_screen.dart';
import 'widgets/exercise_card.dart';
import 'widgets/workout_in_progress_header.dart';
import 'widgets/workout_session_action_bar.dart';
import 'workout_summary_screen.dart';

class WorkoutInProgressScreen extends StatefulWidget {
  const WorkoutInProgressScreen({super.key, this.fitnessRepository});

  final FitnessRepository? fitnessRepository;

  @override
  State<WorkoutInProgressScreen> createState() =>
      _WorkoutInProgressScreenState();
}

class _WorkoutInProgressScreenState extends State<WorkoutInProgressScreen>
    with WidgetsBindingObserver {
  late final WorkoutSessionController _controller;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WorkoutSessionController(
      fitnessRepository: widget.fitnessRepository,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map
        ? Map<String, dynamic>.from(args)
        : const <String, dynamic>{};
    _controller.initialize(templateId: map['templateId'] as String?);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller.saveDraft().catchError((Object _) {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.workout,
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: const _WorkoutInProgressView(),
      ),
    );
  }
}

class _WorkoutInProgressView extends StatefulWidget {
  const _WorkoutInProgressView();

  @override
  State<_WorkoutInProgressView> createState() => _WorkoutInProgressViewState();
}

class _WorkoutInProgressViewState extends State<_WorkoutInProgressView> {
  final _library = ExerciseLibraryIndex(exerciseLibrary);
  late final ScrollController _scrollController;
  final ValueNotifier<double> _collapseProgress = ValueNotifier<double>(0);
  bool _allowExit = false;
  bool _leaving = false;
  bool _confirmingFinish = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _collapseProgress.dispose();
    super.dispose();
  }

  void _handleScroll() {
    const collapseDistance = 150.0;
    final nextProgress = (_scrollController.offset / collapseDistance).clamp(
      0.0,
      1.0,
    );
    if ((nextProgress - _collapseProgress.value).abs() > 0.01) {
      _collapseProgress.value = nextProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutSessionController>();
    final totalSets = controller.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    final completedSets = controller.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.where((set) => set.done).length,
    );

    return PopScope(
      canPop: _allowExit || controller.isFinished,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _leaving || controller.isFinishing) return;
        _leaving = true;
        try {
          await controller.saveDraft();
          if (!mounted) return;
          setState(() => _allowExit = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(result);
          });
        } catch (_) {
          if (context.mounted) {
            _showError(
              context,
              'No se pudo guardar el borrador. Reintentá antes de salir.',
            );
          }
        } finally {
          _leaving = false;
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Tu sesión')),
        body: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.initializationError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'No se pudo abrir la sesión. El borrador se conserva.',
                      ),
                      FilledButton(
                        onPressed: () => controller.initialize(
                          templateId:
                              (ModalRoute.of(context)?.settings.arguments
                                      as Map?)?['templateId']
                                  as String?,
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (controller.completionNeedsRecovery)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'La sesión ya está en el historial. Tocá Finalizar entrenamiento para completar el guardado en Home.',
                          ),
                        ),
                      ),
                    if (controller.saveError != null)
                      SliverToBoxAdapter(
                        child: MaterialBanner(
                          content: const Text(
                            'Hay cambios sin guardar. Revisá el espacio disponible y reintentá.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () async {
                                try {
                                  await controller.saveDraft();
                                } catch (_) {
                                  if (context.mounted) {
                                    _showError(
                                      context,
                                      'El guardado sigue pendiente.',
                                    );
                                  }
                                }
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _collapseProgress,
                        builder: (context, progress, _) {
                          return WorkoutInProgressHeader(
                            startTime: controller.sessionStart,
                            isPaused: controller.isPaused,
                            pausedAt: controller.pausedAt,
                            accumulatedPaused: controller.accumulatedPaused,
                            totalVolume: controller.totalVolume,
                            currentDistribution:
                                controller.currentMuscleDistribution,
                            previousDistribution:
                                controller.previousMuscleDistribution,
                            completedSets: completedSets,
                            totalSets: totalSets,
                            collapseProgress: progress,
                          );
                        },
                      ),
                    ),
                    if (controller.exercises.isEmpty)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.fitness_center, size: 40),
                              SizedBox(height: 12),
                              Text('Empezá con tu primer ejercicio'),
                              SizedBox(height: 8),
                              Text(
                                'Agregá ejercicios y registrá tus series. Tu progreso se guarda automáticamente.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final exercise = controller.exercises[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ExerciseCard(
                              exercise: exercise,
                              isExpanded:
                                  controller.expandedExerciseId == exercise.id,
                              onTap: () => controller.toggleExerciseExpansion(
                                exercise.id,
                              ),
                              onNotesChanged: (value) => controller
                                  .updateExerciseNotes(exercise.id, value),
                              onRestToggle: (value) =>
                                  controller.updateExerciseRest(
                                    exercise.id,
                                    enabled: value,
                                    seconds: exercise.restSeconds ?? 90,
                                  ),
                              onRestSecondsChanged: (seconds) =>
                                  controller.updateExerciseRest(
                                    exercise.id,
                                    enabled: exercise.restEnabled,
                                    seconds: seconds,
                                  ),
                              onSetChanged:
                                  (
                                    setId, {
                                    kg,
                                    clearKg,
                                    reps,
                                    clearReps,
                                    done,
                                  }) => controller.updateSet(
                                    exercise.id,
                                    setId,
                                    kg: kg,
                                    clearKg: clearKg ?? false,
                                    reps: reps,
                                    clearReps: clearReps ?? false,
                                    done: done,
                                  ),
                              onAddSet: () => controller.addSet(exercise.id),
                              onDurationChanged: (setId, seconds) =>
                                  controller.updateSet(
                                    exercise.id,
                                    setId,
                                    durationSeconds: seconds,
                                    clearDuration: seconds == null,
                                  ),
                              onDeleteSet: (setId) =>
                                  controller.removeSet(exercise.id, setId),
                              onDelete: () =>
                                  controller.removeExercise(exercise.id),
                              onMoveUp: () =>
                                  controller.moveExerciseUp(exercise.id),
                              onMoveDown: () =>
                                  controller.moveExerciseDown(exercise.id),
                            ),
                          );
                        }, childCount: controller.exercises.length),
                      ),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: controller.isReady || controller.isFinishing
            ? WorkoutSessionActionBar(
                controller: controller,
                onAdd: () => _openAddExerciseSheet(context),
                onFinish: () => _requestFinish(context),
                onPause: () async {
                  try {
                    await controller.togglePause();
                  } catch (_) {
                    if (context.mounted) {
                      _showError(
                        context,
                        'No se pudo cambiar la pausa. Reintentá.',
                      );
                    }
                  }
                },
                onSettings: () => _openSettings(context),
                onDiscard: () => _confirmDiscard(context),
              )
            : null,
      ),
    );
  }

  Future<void> _openAddExerciseSheet(BuildContext context) async {
    final controller = context.read<WorkoutSessionController>();
    final query = ValueNotifier('');

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
            ),
            child: SizedBox(
              height:
                  (MediaQuery.sizeOf(sheetContext).height -
                      MediaQuery.viewInsetsOf(sheetContext).bottom) *
                  .65,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar ejercicio',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => query.value = value,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: query,
                      builder: (context, value, _) {
                        final filtered = _library.search(value);
                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'No encontramos ejercicios. Probá otro nombre o músculo.',
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final exercise = filtered[index];
                            return ListTile(
                              title: Text(exercise.name),
                              subtitle: Text(
                                exercise.primaryMuscles.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () async {
                                Navigator.of(sheetContext).pop();
                                unawaited(
                                  controller.addExercise(
                                    exerciseId: exercise.id,
                                    name: exercise.name,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      query.dispose();
    }
  }

  Future<void> _requestFinish(BuildContext context) async {
    final controller = context.read<WorkoutSessionController>();
    if (_confirmingFinish || !controller.isReady) return;
    if (controller.completedSets == 0) {
      _showError(context, 'Completá al menos una serie válida.');
      return;
    }
    _confirmingFinish = true;
    try {
      final completed = controller.completedSets;
      final total = controller.programmedSets;
      final duration = controller.elapsedAt(DateTime.now());
      final registered = controller.exercises
          .where(
            (e) => e.sets.any(
              (s) => s.done && s.hasValidResult(isTimed: e.isTimed),
            ),
          )
          .length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Finalizar entrenamiento'),
          content: Text(
            '$completed de $total series completadas\n$registered ejercicios registrados\n${duration.inMinutes} min ${duration.inSeconds.remainder(60)} s de sesión sin pausas\n\n${completed < total ? '${total - completed} series quedarán sin completar. Se conservarán como pendientes.' : 'Todas las series están completadas.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Continuar entrenando'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Guardar entrenamiento'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      final id = controller.sessionId;
      final finished = await controller.finishWorkout();
      if (!context.mounted || !finished) return;
      // The completed route is removed; Back cannot reopen a finished session.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: '/workout/summary', arguments: id),
          builder: (_) => WorkoutSummaryScreen(sessionId: id),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _showError(
          context,
          'No se pudo completar el guardado. Tus datos se conservan; reintentá.',
        );
      }
    } finally {
      _confirmingFinish = false;
    }
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar sesión'),
        content: const Text('Se perderá el borrador actual. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar entrenamiento'),
          ),
        ],
      ),
    );

    if (shouldDiscard == true && context.mounted) {
      try {
        await context.read<WorkoutSessionController>().discardWorkout();
      } catch (_) {
        if (context.mounted) {
          _showError(context, 'No se pudo descartar. El borrador se conserva.');
        }
        return;
      }
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final controller = context.read<WorkoutSessionController>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WorkoutSettingsScreen()),
    );
    await controller.reloadPreferences();
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
