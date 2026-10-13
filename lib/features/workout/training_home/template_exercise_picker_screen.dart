import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/widgets/fit_glyph.dart';
import '../../common/theme/app_layout.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';
import '../data/workout_repository.dart';
import '../workout_in_progress_controller.dart';
import 'routine_draft_controller.dart';
import 'routine_review_screen.dart';
import 'routines_repository.dart';
import 'template_workout_type.dart';
import '../../../app/theme/app_theme.dart';
import '../domain/routine_labels.dart';
import '../domain/sport_activity.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import 'exercise_configuration_sheet.dart';

class ExercisePickerController extends ChangeNotifier {
  ExercisePickerController({
    required List<ExerciseDefinition> exercises,
    List<String> initialRecentExerciseIds = const [],
  }) : _allExercises = exercises,
       _recentExerciseIds = initialRecentExerciseIds {
    _recompute();
  }

  static const int _resultsPageSize = 50;
  static const _starterExerciseIds = [
    'back_squat',
    'bench_press',
    'lat_pulldown',
    'deadlift',
    'military_press',
    'plank',
  ];

  final List<ExerciseDefinition> _allExercises;
  Timer? _debounce;
  bool _disposed = false;
  final _history = WorkoutRepository();

  String _query = '';
  Set<String> _equipmentFilters = {};
  Set<String> _muscleFilters = {};
  List<String> _recentExerciseIds = [];
  String? _expandedExerciseId;
  List<ExerciseDefinition> _filteredExercises = [];
  int _visibleLimit = _resultsPageSize;

  String get query => _query;
  Set<String> get equipmentFilters => _equipmentFilters;
  Set<String> get muscleFilters => _muscleFilters;
  String? get expandedExerciseId => _expandedExerciseId;
  bool get hasActiveFilters =>
      _equipmentFilters.isNotEmpty || _muscleFilters.isNotEmpty;
  bool get isBrowsing => !hasActiveFilters && _normalizedQuery.isEmpty;
  int get totalCount => _filteredExercises.length;
  int get visibleCount => math.min(_visibleLimit, totalCount);
  bool get canShowMore => visibleCount < totalCount;
  List<ExerciseDefinition> get itemsVisible =>
      _filteredExercises.take(visibleCount).toList(growable: false);
  List<ExerciseDefinition> get allExercises => List.unmodifiable(_allExercises);

  String get showingResultsLabel {
    final noun = isBrowsing ? 'ejercicios' : 'resultados';
    if (totalCount <= _visibleLimit) {
      return 'Mostrando $totalCount $noun';
    }
    return 'Mostrando $visibleCount de $totalCount $noun';
  }

  String get _normalizedQuery => _normalize(_query);

  List<String> get allEquipment =>
      _allExercises.map((e) => e.equipment).toSet().toList()..sort();

  List<String> get allMuscles {
    final muscles = <String>{};
    for (final exercise in _allExercises) {
      muscles.addAll(exercise.primaryMuscles);
      muscles.addAll(exercise.secondaryMuscles);
    }
    return muscles.toList()..sort();
  }

  Future<void> loadRecentFromHistory() async {
    List<WorkoutSession> decoded;
    try {
      decoded = await _history.listAllSessions();
      decoded.sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return;
    }
    if (_disposed) return;

    final unique = <String>{};
    final recent = <String>[];
    for (final session in decoded.take(20)) {
      for (final exercise in session.exercises) {
        if (unique.add(exercise.id)) {
          recent.add(exercise.id);
          if (recent.length == 3) {
            _recentExerciseIds = recent;
            _recompute();
            notifyListeners();
            return;
          }
        }
      }
    }
    _recentExerciseIds = recent;
    _recompute();
    notifyListeners();
  }

  void setQueryDebounced(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      setQuery(value);
    });
  }

  void setQuery(String value) {
    _debounce?.cancel();
    _query = value;
    _visibleLimit = _resultsPageSize;
    _recompute();
    notifyListeners();
  }

  void setEquipmentFilters(Set<String> values) {
    _equipmentFilters = values;
    _visibleLimit = _resultsPageSize;
    _recompute();
    notifyListeners();
  }

  void setMuscleFilters(Set<String> values) {
    _muscleFilters = values;
    _visibleLimit = _resultsPageSize;
    _recompute();
    notifyListeners();
  }

  void showMore() {
    _visibleLimit += _resultsPageSize;
    notifyListeners();
  }

  void toggleExpanded(String exerciseId) {
    _expandedExerciseId = _expandedExerciseId == exerciseId ? null : exerciseId;
    notifyListeners();
  }

  void _recompute() {
    _filteredExercises = _allExercises
        .where(_matchesFilters)
        .toList(growable: false);
    if (isBrowsing) {
      final priority = [..._recentExerciseIds, ..._starterExerciseIds];
      final rank = <String, int>{};
      for (final id in priority) {
        rank.putIfAbsent(id, () => rank.length);
      }
      final originalOrder = <String, int>{
        for (var index = 0; index < _allExercises.length; index++)
          _allExercises[index].id: index,
      };
      _filteredExercises.sort((a, b) {
        final byPriority = (rank[a.id] ?? rank.length).compareTo(
          rank[b.id] ?? rank.length,
        );
        return byPriority != 0
            ? byPriority
            : originalOrder[a.id]!.compareTo(originalOrder[b.id]!);
      });
    }
  }

  bool _matchesFilters(ExerciseDefinition exercise) {
    if (_equipmentFilters.isNotEmpty &&
        !_equipmentFilters.contains(exercise.equipment)) {
      return false;
    }

    if (_muscleFilters.isNotEmpty) {
      final muscles = {
        ...exercise.primaryMuscles,
        ...exercise.secondaryMuscles,
      };
      final hasMuscleMatch = _muscleFilters.any(muscles.contains);
      if (!hasMuscleMatch) return false;
    }

    final normalizedQuery = _normalizedQuery;
    if (normalizedQuery.isEmpty) return true;

    final searchable = [
      exercise.name,
      ...exercise.aliases,
      ...exercise.primaryMuscles,
      ...exercise.secondaryMuscles,
      exercise.equipment,
      RoutineLabels.equipmentName(exercise.equipment),
      RoutineLabels.exerciseName(exercise.name),
    ].map(_normalize);

    return searchable.any((field) => field.contains(normalizedQuery));
  }

  String _normalize(String value) {
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    var output = value.trim().toLowerCase();
    accents.forEach((k, v) => output = output.replaceAll(k, v));
    return output;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}

class TemplateExercisePickerScreen extends StatefulWidget {
  const TemplateExercisePickerScreen({
    super.key,
    this.controller,
    this.repository,
    this.draftController,
    this.selectionOnly = false,
  });

  final ExercisePickerController? controller;
  final RoutinesRepository? repository;
  final RoutineDraftController? draftController;
  final bool selectionOnly;

  @override
  State<TemplateExercisePickerScreen> createState() =>
      _TemplateExercisePickerScreenState();
}

class _TemplateExercisePickerScreenState
    extends State<TemplateExercisePickerScreen> {
  late final ExercisePickerController _controller;
  late final bool _ownedController;
  late final RoutineDraftController _draftController;
  late final RoutinesRepository _repository;
  late final Map<String, ExerciseDefinition> _exercisesById;
  bool _allowPop = false;
  String _sportQuery = "";
  int _modeRevision = 0;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _ownedController = widget.controller == null;
    _controller =
        widget.controller ??
        ExercisePickerController(exercises: exerciseLibrary);
    _draftController = widget.draftController ?? RoutineDraftController();
    _repository = widget.repository ?? RoutinesRepository();
    _exercisesById = {
      for (final exercise in _controller.allExercises) exercise.id: exercise,
    };
    if (_ownedController) {
      unawaited(_controller.loadRecentFromHistory());
    }
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    if (_ownedController) {
      _controller.dispose();
    }
    if (widget.draftController == null) {
      _draftController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final hasInProgressBar =
        WorkoutInProgressController.instance.currentDraft != null;
    return Theme(
      data: AppTheme.workout,
      child: ListenableBuilder(
        listenable: Listenable.merge([_controller, _draftController]),
        builder: (context, _) {
          final hasSelection = _draftController.selectedCount > 0;
          final miniBarHeight = hasSelection ? 72.0 : 0.0;
          final overlayPadding = hasInProgressBar ? 76.0 : 0.0;
          return PopScope(
            canPop: _allowPop || !hasSelection,
            onPopInvokedWithResult: (didPop, result) async {
              if (didPop || _allowPop || !hasSelection) return;
              final choice = await showDialog<String>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Salir de la rutina'),
                  content: const Text(
                    'Podés continuar más tarde con el mismo borrador.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Seguir editando'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, 'discard'),
                      child: const Text('Descartar borrador'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, 'keep'),
                      child: const Text('Guardar y salir'),
                    ),
                  ],
                ),
              );
              if (choice == null || !mounted) return;
              try {
                if (choice == 'discard') {
                  await _draftController.clearPersisted();
                } else {
                  await _draftController.flush();
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo guardar el borrador. Reintentá antes de salir.',
                      ),
                    ),
                  );
                }
                return;
              }
              if (!mounted) return;
              setState(() => _allowPop = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop(result);
              });
            },
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: AppBar(
                title: const Text('Crear rutina'),
                actions: [
                  TextButton(
                    onPressed: hasSelection && !_restoring ? _openReview : null,
                    child: const Text('Listo'),
                  ),
                ],
              ),
              body: _restoring
                  ? const Center(child: CircularProgressIndicator())
                  : _draftController.restoreFailed
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.restore_page_outlined, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'No se pudo recuperar el borrador. Se conserva sin sobrescribir.',
                            ),
                            FilledButton(
                              onPressed: _restoreDraft,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Column(
                                  children: [
                                    WorkoutTypeSegment(
                                      selected: _draftController.workoutType,
                                      onChanged: (type) => _changeMode(
                                        type,
                                        _draftController.footballMode,
                                      ),
                                    ),
                                    if (_draftController.workoutType ==
                                        TemplateWorkoutType.sport) ...[
                                      const SizedBox(height: 12),
                                      const Text('Fútbol'),
                                      DropdownButtonFormField<FootballMode>(
                                        key: ValueKey(_modeRevision),
                                        initialValue:
                                            _draftController.footballMode,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Modalidad',
                                        ),
                                        items: [
                                          for (final mode
                                              in FootballMode.values)
                                            DropdownMenuItem(
                                              value: mode,
                                              child: Text(mode.label),
                                            ),
                                        ],
                                        onChanged: (mode) {
                                          if (mode != null) {
                                            _changeMode(
                                              TemplateWorkoutType.sport,
                                              mode,
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    ExerciseSearchField(
                                      key: ValueKey(
                                        '${_draftController.workoutType}_${_draftController.footballMode}',
                                      ),
                                      onChanged: (value) {
                                        if (_isSportActivities) {
                                          setState(
                                            () => _sportQuery = value
                                                .trim()
                                                .toLowerCase(),
                                          );
                                        } else {
                                          _controller.setQueryDebounced(value);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    if (!_isSportActivities)
                                      FilterPillsRow(
                                        equipmentCount:
                                            _controller.equipmentFilters.length,
                                        muscleCount:
                                            _controller.muscleFilters.length,
                                        onTapEquipment: () => _showFilterSheet(
                                          context,
                                          title: 'Equipamiento',
                                          options: _controller.allEquipment,
                                          initialSelection:
                                              _controller.equipmentFilters,
                                          onApply:
                                              _controller.setEquipmentFilters,
                                        ),
                                        onTapMuscle: () => _showFilterSheet(
                                          context,
                                          title: 'Músculo',
                                          options: _controller.allMuscles,
                                          initialSelection:
                                              _controller.muscleFilters,
                                          onApply: _controller.setMuscleFilters,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SectionHeader(
                                      title: _isSportActivities
                                          ? 'Explorar actividades'
                                          : 'Explorar ejercicios',
                                    ),
                                    if (_controller.hasActiveFilters &&
                                        !_isSportActivities)
                                      TextButton(
                                        onPressed: () {
                                          _controller.setEquipmentFilters({});
                                          _controller.setMuscleFilters({});
                                        },
                                        child: const Text('Limpiar filtros'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (_isSportActivities && _sportItems.isEmpty)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: _NoResultsState(),
                              )
                            else if (_isSportActivities)
                              SliverList.builder(
                                itemCount: _sportItems.length,
                                itemBuilder: (context, i) {
                                  final activity = _sportItems[i];
                                  final e = WorkoutExercise(
                                    id: activity.id,
                                    name: activity.name,
                                    targetSets: 1,
                                    measurement: 'seconds',
                                    sportPlan: SportActivityPlan(
                                      activityId: activity.id,
                                      mode: activity.mode,
                                    ),
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      12,
                                    ),
                                    child: ExerciseBrowserCard(
                                      exercise: e,
                                      selected: _draftController.contains(e.id),
                                      subtitle:
                                          'Fútbol · ${activity.mode.label}',
                                      onOpen: () => _openConfiguration(e),
                                      onAdd: () => _draftController.add(e),
                                    ),
                                  );
                                },
                              )
                            else if (_controller.totalCount == 0)
                              const SliverFillRemaining(
                                hasScrollBody: false,
                                child: _NoResultsState(),
                              )
                            else ...[
                              SliverList.builder(
                                itemCount: _controller.itemsVisible.length,
                                itemBuilder: (context, index) {
                                  final exercise =
                                      _controller.itemsVisible[index];
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      10,
                                    ),
                                    child: ExerciseBrowserCard(
                                      exercise:
                                          _draftController.configFor(
                                            exercise.id,
                                          ) ??
                                          RoutineLabels.defaults(exercise),
                                      subtitle:
                                          '${exercise.primaryMuscles.join(', ')} · ${RoutineLabels.equipmentName(exercise.equipment)}',
                                      selected: _draftController.contains(
                                        exercise.id,
                                      ),
                                      onOpen: () => _openConfiguration(
                                        _draftController.configFor(
                                              exercise.id,
                                            ) ??
                                            RoutineLabels.defaults(exercise),
                                      ),
                                      onAdd: () => _draftController.add(
                                        RoutineLabels.defaults(exercise),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (_controller.canShowMore)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      12,
                                    ),
                                    child: Center(
                                      child: OutlinedButton(
                                        onPressed: _controller.showMore,
                                        child: const Text('Mostrar más'),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height:
                                    bottomInset +
                                    miniBarHeight +
                                    overlayPadding +
                                    20,
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _SelectionMiniBar(
                            visible: hasSelection,
                            count: _draftController.selectedCount,
                            selectedExerciseNames: _draftController
                                .selectedExerciseIds
                                .map((id) => _exercisesById[id]?.name)
                                .whereType<String>()
                                .toList(growable: false),
                            onTap: _openReview,
                            onClear: _confirmClear,
                            extraBottomPadding: bottomInset + overlayPadding,
                          ),
                        ),
                      ],
                    ),
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          );
        },
      ),
    );
  }

  bool get _isSportActivities =>
      _draftController.workoutType == TemplateWorkoutType.sport &&
      _draftController.footballMode != FootballMode.gym;
  List<FootballActivity> get _sportItems => footballActivities
      .where(
        (e) =>
            e.mode == _draftController.footballMode &&
            ("${e.name} ${e.description}".toLowerCase().contains(_sportQuery)),
      )
      .toList();
  Future<void> _restoreDraft() async {
    if (widget.draftController == null) await _draftController.restore();
    if (mounted) setState(() => _restoring = false);
  }

  Future<void> _confirmClear() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quitar todos los ejercicios'),
        content: const Text(
          'Se quitarán las configuraciones del borrador. El nombre y las notas se conservarán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (remove == true) {
      _draftController.clearExercises();
    }
  }

  Future<void> _changeMode(TemplateWorkoutType type, FootballMode mode) async {
    var discard = false;
    if (!_draftController.compatible(type, mode)) {
      discard =
          await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Cambiar modalidad'),
              content: const Text(
                'Se conservarán el nombre, las notas y las actividades compatibles. Las actividades incompatibles se quitarán del borrador.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Cambiar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
      if (!discard) {
        setState(() => _modeRevision++);
        return;
      }
    }
    _controller.setQuery("");
    _draftController.setMode(type, mode, discardIncompatible: discard);
    setState(() {
      _modeRevision++;
      _sportQuery = "";
    });
  }

  Future<void> _openConfiguration(WorkoutExercise e) async {
    final exists = _draftController.contains(e.id);
    final configured = _draftController.configFor(e.id) ?? e;
    final updated = await showExerciseConfiguration(
      context,
      configured,
      definition: _exercisesById[e.id],
      sportGym:
          _draftController.workoutType == TemplateWorkoutType.sport &&
          _draftController.footballMode == FootballMode.gym,
      action: exists ? 'Guardar configuración' : 'Agregar a rutina',
    );
    if (updated == null || !mounted) return;
    if (exists) {
      _draftController.update(configured.instanceId!, updated);
    } else {
      _draftController.add(updated);
    }
  }

  Future<void> _openReview() async {
    if (_draftController.selectedCount == 0) return;
    if (widget.selectionOnly) {
      try {
        await _draftController.flush();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo conservar el borrador. Reintentá antes de volver.',
              ),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() => _allowPop = true);
      Navigator.pop(context);
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineReviewScreen(
          draftController: _draftController,
          exercisesById: {
            for (final exercise in exerciseLibrary) exercise.id: exercise,
          },
          repository: _repository,
        ),
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Rutina guardada')));
      Navigator.of(context).pop('saved');
    }
  }

  Future<void> _showFilterSheet(
    BuildContext context, {
    required String title,
    required List<String> options,
    required Set<String> initialSelection,
    required ValueChanged<Set<String>> onApply,
  }) async {
    final selection = Set<String>.from(initialSelection);
    final applied = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          return CheckboxListTile(
                            value: selection.contains(option),
                            title: Text(RoutineLabels.equipmentName(option)),
                            onChanged: (value) {
                              setModalState(() {
                                if (value ?? false) {
                                  selection.add(option);
                                } else {
                                  selection.remove(option);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setModalState(selection.clear),
                          child: const Text('Limpiar'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(selection),
                          child: const Text('Aplicar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (applied != null) {
      onApply(applied);
    }
  }
}

class ExerciseBrowserCard extends StatelessWidget {
  const ExerciseBrowserCard({
    super.key,
    required this.exercise,
    required this.subtitle,
    required this.selected,
    required this.onOpen,
    required this.onAdd,
  });
  final WorkoutExercise exercise;
  final String subtitle;
  final bool selected;
  final VoidCallback onOpen, onAdd;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget text() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RoutineLabels.exerciseName(exercise.name),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    Widget add() => IconButton.filled(
      onPressed: selected ? null : onAdd,
      tooltip: selected
          ? '${exercise.name} seleccionado'
          : 'Agregar ${exercise.name}',
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: colors.onPrimary,
        disabledForegroundColor: colors.onSurface,
      ),
      icon: Icon(
        selected ? Icons.check : Icons.add,
        color: selected ? colors.onSurface : colors.onPrimary,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final large = MediaQuery.textScalerOf(context).scale(16) > 24;
            if (large) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: onOpen,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ExerciseThumbnail(exercise: exercise),
                          ),
                        ),
                      ),
                      add(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: onOpen,
                    child: SizedBox(width: double.infinity, child: text()),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        ExerciseThumbnail(exercise: exercise),
                        const SizedBox(width: 12),
                        Expanded(child: text()),
                      ],
                    ),
                  ),
                ),
                add(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectionMiniBar extends StatelessWidget {
  const _SelectionMiniBar({
    required this.visible,
    required this.count,
    required this.selectedExerciseNames,
    required this.onTap,
    required this.onClear,
    required this.extraBottomPadding,
  });

  final bool visible;
  final int count;
  final List<String> selectedExerciseNames;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final double extraBottomPadding;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppVisual.motionNormal,
        offset: visible ? Offset.zero : const Offset(0, 1),
        child: AnimatedOpacity(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppVisual.motionNormal,
          opacity: visible ? 1 : 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + extraBottomPadding),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final name in selectedExerciseNames.take(3))
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    label: SizedBox(
                                      width: 108,
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              if (count > 3)
                                Chip(
                                  label: Text('+${count - 3}'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Limpiar selección',
                      ),
                      const SizedBox(width: 6),
                      FilledButton.tonal(
                        onPressed: onTap,
                        child: Text('Ver ($count)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkoutTypeSegment extends StatelessWidget {
  const WorkoutTypeSegment({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TemplateWorkoutType selected;
  final ValueChanged<TemplateWorkoutType> onChanged;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(16) > 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in [
            TemplateWorkoutType.gym,
            TemplateWorkoutType.sport,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => onChanged(type),
                icon: Icon(
                  selected == type
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                label: Text(typeLabel(type)),
              ),
            ),
        ],
      );
    }
    return SegmentedButton<TemplateWorkoutType>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: TemplateWorkoutType.gym, label: Text('Gimnasio')),
        ButtonSegment(value: TemplateWorkoutType.sport, label: Text('Deporte')),
      ],
      selected: {
        selected == TemplateWorkoutType.other
            ? TemplateWorkoutType.gym
            : selected,
      },
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

class ExerciseSearchField extends StatelessWidget {
  const ExerciseSearchField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: 'Buscar',
        hintText: 'Nombre, músculo o equipamiento…',
        prefixIcon: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: FitGlyph(kind: FitGlyphKind.search, size: 20),
        ),
      ),
    );
  }
}

class FilterPillsRow extends StatelessWidget {
  const FilterPillsRow({
    super.key,
    required this.equipmentCount,
    required this.muscleCount,
    required this.onTapEquipment,
    required this.onTapMuscle,
  });

  final int equipmentCount;
  final int muscleCount;
  final VoidCallback onTapEquipment;
  final VoidCallback onTapMuscle;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      OutlinedButton(
        onPressed: onTapEquipment,
        child: Text(
          equipmentCount == 0
              ? 'Equipamiento'
              : 'Equipamiento · $equipmentCount',
        ),
      ),
      OutlinedButton(
        onPressed: onTapMuscle,
        child: Text(muscleCount == 0 ? 'Músculos' : 'Músculos · $muscleCount'),
      ),
    ];
    if (MediaQuery.textScalerOf(context).scale(16) > 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [buttons[0], const SizedBox(height: 8), buttons[1]],
      );
    }
    return Row(
      children: [
        Expanded(child: buttons[0]),
        const SizedBox(width: 12),
        Expanded(child: buttons[1]),
      ],
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sin resultados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Probá otro término o ajustá filtros.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}
