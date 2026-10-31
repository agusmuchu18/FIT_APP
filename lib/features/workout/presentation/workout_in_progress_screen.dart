import '../domain/training_program.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/data/repositories.dart';
import '../../../app/theme/app_theme.dart';
import '../application/routine_update_from_session.dart';
import '../application/workout_session_controller.dart';
import '../pro/data/exercise_library.dart';
import '../pro/data/exercise_definition.dart';
import '../training_home/workout_settings_screen.dart';
import '../training_home/exercise_technical_screen.dart';
import '../domain/session_models.dart';
import '../domain/workout_analytics.dart';
import 'widgets/add_exercise_sheet.dart';
import 'widgets/exercise_card.dart';
import 'widgets/sport_session_card.dart';
import 'widgets/workout_in_progress_header.dart';
import 'widgets/workout_session_action_bar.dart';
import 'widgets/workout_units_host.dart';
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
  String? _templateId;
  ProgramExecutionRef? _programExecution;

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
    _templateId = map['templateId'] as String?;
    _programExecution = map['programExecution'] as ProgramExecutionRef?;
    _initialize();
  }

  /// Also used by "Reintentar": the routine and program occurrence survive.
  Future<void> _initialize() => _controller.initialize(
    templateId: _templateId,
    programExecution: _programExecution,
  );

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
      data: AppTheme.workoutFor(Theme.of(context)),
      child: ChangeNotifierProvider.value(
        value: _controller,
        child: _WorkoutInProgressView(onRetry: _initialize),
      ),
    );
  }
}

class _WorkoutInProgressView extends StatefulWidget {
  const _WorkoutInProgressView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  State<_WorkoutInProgressView> createState() => _WorkoutInProgressViewState();
}

class _WorkoutInProgressViewState extends State<_WorkoutInProgressView> {
  final _library = ExerciseLibraryIndex(exerciseLibrary);
  late final ScrollController _scrollController;
  final ValueNotifier<double> _collapseProgress = ValueNotifier<double>(0);
  final Map<String, GlobalKey> _cardKeys = {};
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

  /// Brings the exercise opened by auto-advance into view, once.
  void _scrollToAutoAdvanced(WorkoutSessionController controller) {
    final id = controller.consumeAutoAdvance();
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _cardKeys[id]?.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutSessionController>();
    _scrollToAutoAdvanced(controller);
    final totalSets = controller.programmedSets;
    final completedSets = controller.completedSets;
    final canFinish = controller.isReady && completedSets > 0;

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
        appBar: AppBar(
          title: Text(
            controller.routineName ?? 'Entrenamiento libre',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (controller.isReady || controller.isFinishing)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: canFinish ? () => _requestFinish(context) : null,
                  child: const Text('Finalizar'),
                ),
              ),
          ],
        ),
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
                        onPressed: widget.onRetry,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SafeArea(
                      bottom: false,
                      child: CustomScrollView(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
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
                                  accumulatedPaused:
                                      controller.accumulatedPaused,
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
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _exerciseItem(
                                  context,
                                  controller,
                                  controller.exercises[index],
                                ),
                                childCount: controller.exercises.length,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const _KeyboardAccessoryBar(),
                ],
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

  Widget _exerciseItem(
    BuildContext context,
    WorkoutSessionController controller,
    ExerciseInSession exercise,
  ) {
    final key = _cardKeys.putIfAbsent(
      exercise.id,
      () => GlobalKey(debugLabel: exercise.id),
    );
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: exercise.sportPlan != null
          ? SportSessionCard(
              key: ValueKey(exercise.id),
              exercise: exercise,
              onChanged: (result) =>
                  controller.updateSportResult(exercise.id, result),
              onDone: (done) {
                for (final set in exercise.sets) {
                  controller.updateSet(exercise.id, set.id, done: done);
                }
              },
              onRest: (enabled, seconds) => controller.updateExerciseRest(
                exercise.id,
                enabled: enabled,
                seconds: seconds,
              ),
              onRemove: () => _removeExercise(context, exercise),
            )
          : ExerciseCard(
              exercise: exercise,
              onDuplicate: () => controller.duplicateExercise(exercise.id),
              onReplace: () => _replaceExercise(context, exercise),
              onDetails: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExerciseTechnicalScreen(
                    exercise: WorkoutAnalytics.fromLive([exercise]).single,
                  ),
                ),
              ),
              onSetLoadTypeChanged: (setId, type) =>
                  controller.updateSetLoadType(exercise.id, setId, type),
              onApplyPrevious: (setId) =>
                  controller.applyPreviousSet(exercise.id, setId),
              onLoadTypeChanged: (type) =>
                  controller.updateLoadType(exercise.id, type),
              expandedSetId: controller.expandedSetId,
              onSetExpansion: controller.toggleSetExpansion,
              onSetDetailsChanged: (details) =>
                  controller.updateSetDetails(exercise.id, details),
              onDistanceChanged: (id, distance) => controller.updateSet(
                exercise.id,
                id,
                distanceMeters: distance,
                clearDistance: distance == null,
              ),
              isExpanded: controller.expandedExerciseId == exercise.id,
              onTap: () => controller.toggleExerciseExpansion(exercise.id),
              onNotesChanged: (value) =>
                  controller.updateExerciseNotes(exercise.id, value),
              onRestChanged: (enabled, seconds) =>
                  controller.updateExerciseRest(
                    exercise.id,
                    enabled: enabled,
                    seconds: seconds,
                  ),
              onSetChanged: (setId, {kg, clearKg, reps, clearReps, done}) {
                controller.updateSet(
                  exercise.id,
                  setId,
                  kg: kg,
                  clearKg: clearKg ?? false,
                  reps: reps,
                  clearReps: clearReps ?? false,
                  done: done,
                );
                if (done == true) {
                  _afterSetCompleted(context, controller, exercise.id, setId);
                }
              },
              onCompleteSet: (setId) {
                if (controller.completeSet(exercise.id, setId)) {
                  _afterSetCompleted(context, controller, exercise.id, setId);
                } else {
                  _showError(
                    context,
                    exercise.isTimed
                        ? 'Ingresá el tiempo de la serie para completarla.'
                        : exercise.isDistance
                        ? 'Ingresá la distancia de la serie para completarla.'
                        : 'Ingresá las repeticiones para completar la serie.',
                  );
                }
              },
              isRecord: (setId) => controller.isLiveRecord(exercise.id, setId),
              supersetLabel: controller.supersetLabel(exercise.id),
              onLinkNext: controller.canLinkWithNext(exercise.id)
                  ? () => controller.linkWithNext(exercise.id)
                  : null,
              onUnlinkSuperset: controller.supersetLabel(exercise.id) != null
                  ? () => controller.unlinkSuperset(exercise.id)
                  : null,
              onSetKindChanged: (setId, kind) =>
                  controller.updateSetKind(exercise.id, setId, kind),
              onAddSet: () => controller.addSet(exercise.id),
              onDurationChanged: (setId, seconds) => controller.updateSet(
                exercise.id,
                setId,
                durationSeconds: seconds,
                clearDuration: seconds == null,
              ),
              onDeleteSet: (setId) => _removeSet(context, exercise, setId),
              onDelete: () => _removeExercise(context, exercise),
              onMoveUp: () => controller.moveExerciseUp(exercise.id),
              onMoveDown: () => controller.moveExerciseDown(exercise.id),
            ),
    );
  }

  void _afterSetCompleted(
    BuildContext context,
    WorkoutSessionController controller,
    String exerciseId,
    String setId,
  ) {
    final exercise = controller.exercises
        .where((e) => e.id == exerciseId)
        .firstOrNull;
    final set = exercise?.sets.where((s) => s.id == setId).firstOrNull;
    if (exercise == null || set == null || !set.done) return;
    if (controller.isLiveRecord(exerciseId, setId) && set.kg != null) {
      unawaited(HapticFeedback.heavyImpact().catchError((Object _) {}));
      final load = WorkoutUnits.of(context).valueWithUnit('kg', set.kg!);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('🏆 Nuevo récord de peso en ${exercise.name}: $load'),
          ),
        );
    } else {
      unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
    }
  }

  Future<void> _removeExercise(
    BuildContext context,
    ExerciseInSession exercise,
  ) async {
    final controller = context.read<WorkoutSessionController>();
    final done = exercise.doneSets;
    if (done > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text('¿Eliminar ${exercise.name}?'),
          content: Text(
            done == 1
                ? 'Tiene 1 serie completada en esta sesión.'
                : 'Tiene $done series completadas en esta sesión.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialog).colorScheme.error,
                foregroundColor: Theme.of(dialog).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    final removed = controller.removeExercise(exercise.id);
    if (removed == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${exercise.name} eliminado'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => controller.restoreExercise(removed),
          ),
        ),
      );
  }

  void _removeSet(
    BuildContext context,
    ExerciseInSession exercise,
    String setId,
  ) {
    final controller = context.read<WorkoutSessionController>();
    final removed = controller.removeSet(exercise.id, setId);
    if (removed == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Serie ${removed.set.index} eliminada'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => controller.restoreSet(removed),
          ),
        ),
      );
  }

  Future<void> _replaceExercise(
    BuildContext context,
    ExerciseInSession exercise,
  ) async {
    if (exercise.sets.any((s) => s.done)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Reemplazar ejercicio'),
          content: const Text(
            'El reemplazo elimina las series registradas de este ejercicio en la sesión actual. El historial guardado se conserva.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    await _openAddExerciseSheet(context, replaceExerciseId: exercise.id);
  }

  Future<void> _openAddExerciseSheet(
    BuildContext context, {
    String? replaceExerciseId,
  }) async {
    final controller = context.read<WorkoutSessionController>();
    final picked = await showAddExerciseSheet(
      context,
      library: _library,
      recentIds: controller.recentExerciseIds,
      inSessionIds: {for (final e in controller.exercises) e.exerciseId},
      allowMultiple: replaceExerciseId == null,
      title: replaceExerciseId == null
          ? 'Agregar ejercicio'
          : 'Reemplazar ejercicio',
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    if (replaceExerciseId != null) {
      final exercise = picked.first;
      controller.replaceExercise(
        replaceExerciseId,
        exerciseId: exercise.id,
        name: exercise.name,
      );
      return;
    }
    for (final ExerciseDefinition exercise in picked) {
      await controller.addExercise(
        exerciseId: exercise.id,
        name: exercise.name,
      );
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
      final pending = controller.pendingSets;
      final fillable = controller.fillablePendingSets;
      final duration = controller.elapsedAt(DateTime.now());
      final registered = controller.exercises
          .where(
            (e) => e.sets.any(
              (s) =>
                  s.done &&
                  s.hasValidResult(
                    isTimed: e.isTimed,
                    isDistance: e.isDistance,
                  ),
            ),
          )
          .length;
      var resolution = PendingSetsResolution.keepPending;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('Finalizar entrenamiento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completed de $total series completadas\n$registered ejercicios registrados\n${duration.inMinutes} min ${duration.inSeconds.remainder(60)} s de sesión sin pausas',
                  ),
                  const SizedBox(height: 12),
                  if (pending == 0)
                    const Text('Todas las series están completadas.')
                  else ...[
                    Text(
                      pending == 1
                          ? 'Queda 1 serie sin marcar. ¿Qué hacemos con ella?'
                          : 'Quedan $pending series sin marcar. ¿Qué hacemos con ellas?',
                    ),
                    RadioGroup<PendingSetsResolution>(
                      groupValue: resolution,
                      onChanged: (value) {
                        if (value != null) update(() => resolution = value);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const RadioListTile<PendingSetsResolution>(
                            contentPadding: EdgeInsets.zero,
                            value: PendingSetsResolution.keepPending,
                            title: Text('Guardarlas como pendientes'),
                            subtitle: Text(
                              'Se ven en el historial sin contar.',
                            ),
                          ),
                          const RadioListTile<PendingSetsResolution>(
                            contentPadding: EdgeInsets.zero,
                            value: PendingSetsResolution.discardPending,
                            title: Text('Descartarlas'),
                          ),
                          if (fillable > 0)
                            RadioListTile<PendingSetsResolution>(
                              contentPadding: EdgeInsets.zero,
                              value: PendingSetsResolution.completeFilled,
                              title: Text(
                                fillable == 1
                                    ? 'Marcar como hecha la que tiene valores'
                                    : 'Marcar como hechas las $fillable que tienen valores',
                              ),
                              subtitle: const Text(
                                'Usá esta opción solo si las hiciste así.',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
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
        ),
      );
      if (confirmed != true || !context.mounted) return;
      controller.resolvePendingSets(resolution);
      final RoutineUpdateProposal? proposal = await controller
          .routineUpdateCandidate();
      final id = controller.sessionId;
      final finished = await controller.finishWorkout();
      if (!context.mounted || !finished) return;
      // The completed route is removed; Back cannot reopen a finished session.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: RouteSettings(name: '/workout/summary', arguments: id),
          builder: (_) =>
              WorkoutSummaryScreen(sessionId: id, routineUpdate: proposal),
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
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Above the keyboard while typing: previous/next field and "Listo".
/// iOS numeric keypads have no return key, so this is the only way to move
/// between kg and reps without touching the list.
class _KeyboardAccessoryBar extends StatelessWidget {
  const _KeyboardAccessoryBar();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom <= 0) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return ExcludeFocusTraversal(
      child: Material(
        color: scheme.surfaceContainerHigh,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Campo anterior',
                icon: const Icon(Icons.keyboard_arrow_up),
                onPressed: () =>
                    FocusManager.instance.primaryFocus?.previousFocus(),
              ),
              IconButton(
                tooltip: 'Campo siguiente',
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () =>
                    FocusManager.instance.primaryFocus?.nextFocus(),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: const Text('Listo'),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
