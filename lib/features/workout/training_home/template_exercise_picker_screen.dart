import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pro/data/exercise_definition.dart';
import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';

enum TemplateWorkoutType { gym, sport, other }

class ExercisePickerResult {
  const ExercisePickerResult({
    required this.workoutType,
    required this.selectedExercises,
  });

  final TemplateWorkoutType workoutType;
  final List<ExerciseDefinition> selectedExercises;
}

class ExercisePickerController extends ChangeNotifier {
  ExercisePickerController({
    required List<ExerciseDefinition> exercises,
    List<String> initialRecentExerciseIds = const [],
    List<String> initialSelectedExerciseIds = const [],
  })  : _allExercises = exercises,
        _recentExerciseIds = initialRecentExerciseIds,
        _selectedExerciseIds = initialSelectedExerciseIds.toSet() {
    _recompute();
  }

  static const _sessionsKey = 'pro_workout_sessions';
  static const int _minimumQueryLength = 2;
  static const int _resultsPageSize = 50;

  final List<ExerciseDefinition> _allExercises;
  Timer? _debounce;

  TemplateWorkoutType _workoutType = TemplateWorkoutType.gym;
  String _query = '';
  Set<String> _equipmentFilters = {};
  Set<String> _muscleFilters = {};
  Set<String> _selectedExerciseIds = {};
  List<String> _recentExerciseIds = [];
  String? _expandedExerciseId;
  List<ExerciseDefinition> _filteredExercises = [];
  int _visibleLimit = _resultsPageSize;

  TemplateWorkoutType get workoutType => _workoutType;
  String get query => _query;
  Set<String> get equipmentFilters => _equipmentFilters;
  Set<String> get muscleFilters => _muscleFilters;
  Set<String> get selectedExerciseIds => _selectedExerciseIds;
  String? get expandedExerciseId => _expandedExerciseId;
  bool get hasActiveFilters => _equipmentFilters.isNotEmpty || _muscleFilters.isNotEmpty;
  bool get shouldShowResults => hasActiveFilters || _normalizedQuery.length >= _minimumQueryLength;
  bool get hasShortQueryHint => !hasActiveFilters && _query.trim().isNotEmpty && _normalizedQuery.length < _minimumQueryLength;
  int get totalCount => _filteredExercises.length;
  int get visibleCount => math.min(_visibleLimit, totalCount);
  bool get canShowMore => visibleCount < totalCount;
  List<ExerciseDefinition> get itemsVisible => _filteredExercises.take(visibleCount).toList(growable: false);

  String get showingResultsLabel {
    if (totalCount <= _visibleLimit) {
      return 'Mostrando $totalCount resultados';
    }
    return 'Mostrando $visibleCount de $totalCount resultados';
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

  List<ExerciseDefinition> get recentExercises {
    if (!shouldShowResults) return const [];
    final byId = {for (final e in _allExercises) e.id: e};
    return _recentExerciseIds
        .map((id) => byId[id])
        .whereType<ExerciseDefinition>()
        .where(_matchesFilters)
        .take(3)
        .toList(growable: false);
  }

  List<ExerciseDefinition> get filteredExercises {
    final recentIds = recentExercises.map((e) => e.id).toSet();
    return _filteredExercises
        .where((exercise) => !recentIds.contains(exercise.id))
        .toList(growable: false);
  }

  List<ExerciseDefinition> get selectedExercisesInOrder {
    final byId = {for (final e in _allExercises) e.id: e};
    return _selectedExerciseIds
        .map((id) => byId[id])
        .whereType<ExerciseDefinition>()
        .toList(growable: false);
  }

  Future<void> loadRecentFromHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionsKey);
    if (raw == null) return;

    final decoded = (jsonDecode(raw) as List<dynamic>)
        .map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final unique = <String>{};
    final recent = <String>[];
    for (final session in decoded.take(20)) {
      for (final exercise in session.exercises) {
        if (unique.add(exercise.id)) {
          recent.add(exercise.id);
          if (recent.length == 3) {
            _recentExerciseIds = recent;
            notifyListeners();
            return;
          }
        }
      }
    }
    _recentExerciseIds = recent;
    notifyListeners();
  }

  void setWorkoutType(TemplateWorkoutType type) {
    _workoutType = type;
    notifyListeners();
  }

  void setQueryDebounced(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _query = value;
      _visibleLimit = _resultsPageSize;
      _recompute();
      notifyListeners();
    });
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

  bool isSelected(String exerciseId) => _selectedExerciseIds.contains(exerciseId);

  void toggleSelection(String exerciseId) {
    if (_selectedExerciseIds.contains(exerciseId)) {
      _selectedExerciseIds.remove(exerciseId);
    } else {
      _selectedExerciseIds.add(exerciseId);
    }
    notifyListeners();
  }

  void _recompute() {
    if (!shouldShowResults) {
      _filteredExercises = const [];
      return;
    }
    _filteredExercises = _allExercises.where(_matchesFilters).toList(growable: false);
  }

  bool _matchesFilters(ExerciseDefinition exercise) {
    if (_equipmentFilters.isNotEmpty && !_equipmentFilters.contains(exercise.equipment)) {
      return false;
    }

    if (_muscleFilters.isNotEmpty) {
      final muscles = {...exercise.primaryMuscles, ...exercise.secondaryMuscles};
      final hasMuscleMatch = _muscleFilters.any(muscles.contains);
      if (!hasMuscleMatch) return false;
    }

    final normalizedQuery = _normalizedQuery;
    if (normalizedQuery.length < _minimumQueryLength) return true;

    final searchable = [
      exercise.name,
      ...exercise.aliases,
      ...exercise.primaryMuscles,
      ...exercise.secondaryMuscles,
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
    _debounce?.cancel();
    super.dispose();
  }
}

class TemplateExercisePickerScreen extends StatefulWidget {
  const TemplateExercisePickerScreen({
    super.key,
    this.controller,
  });

  final ExercisePickerController? controller;

  @override
  State<TemplateExercisePickerScreen> createState() => _TemplateExercisePickerScreenState();
}

class _TemplateExercisePickerScreenState extends State<TemplateExercisePickerScreen> {
  late final ExercisePickerController _controller;
  late final bool _ownedController;

  @override
  void initState() {
    super.initState();
    _ownedController = widget.controller == null;
    _controller = widget.controller ?? ExercisePickerController(exercises: exerciseLibrary);
    if (_ownedController) {
      unawaited(_controller.loadRecentFromHistory());
    }
  }

  @override
  void dispose() {
    if (_ownedController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('Crear rutina'),
            actions: [
              TextButton(
                onPressed: _controller.selectedExerciseIds.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(
                          ExercisePickerResult(
                            workoutType: _controller.workoutType,
                            selectedExercises: _controller.selectedExercisesInOrder,
                          ),
                        ),
                child: const Text('Listo'),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      WorkoutTypeSegment(
                        selected: _controller.workoutType,
                        onChanged: _controller.setWorkoutType,
                      ),
                      const SizedBox(height: 12),
                      ExerciseSearchField(onChanged: _controller.setQueryDebounced),
                      const SizedBox(height: 12),
                      FilterPillsRow(
                        equipmentCount: _controller.equipmentFilters.length,
                        muscleCount: _controller.muscleFilters.length,
                        onTapEquipment: () => _showFilterSheet(
                          context,
                          title: 'Equipamiento',
                          options: _controller.allEquipment,
                          initialSelection: _controller.equipmentFilters,
                          onApply: _controller.setEquipmentFilters,
                        ),
                        onTapMuscle: () => _showFilterSheet(
                          context,
                          title: 'Músculo',
                          options: _controller.allMuscles,
                          initialSelection: _controller.muscleFilters,
                          onApply: _controller.setMuscleFilters,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_controller.shouldShowResults)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchEmptyState(showShortHint: _controller.hasShortQueryHint),
                )
              else ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SectionHeader(title: 'Resultados'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _controller.showingResultsLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                if (_controller.totalCount == 0)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _NoResultsState(),
                  )
                else ...[
                  SliverList.builder(
                    itemCount: _controller.itemsVisible.length,
                    itemBuilder: (context, index) {
                      final exercise = _controller.itemsVisible[index];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: ExerciseExpandableCard(
                          exercise: exercise,
                          expanded: _controller.expandedExerciseId == exercise.id,
                          selected: _controller.isSelected(exercise.id),
                          onTap: () => _controller.toggleExpanded(exercise.id),
                          onAdd: () => _toggleSelection(context, exercise),
                        ),
                      );
                    },
                  ),
                  if (_controller.canShowMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Center(
                          child: OutlinedButton(
                            onPressed: _controller.showMore,
                            child: const Text('Mostrar más'),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16)),
            ],
          ),
          backgroundColor: theme.scaffoldBackgroundColor,
        );
      },
    );
  }

  void _toggleSelection(BuildContext context, ExerciseDefinition exercise) {
    _controller.toggleSelection(exercise.id);
    final selected = _controller.isSelected(exercise.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(selected ? '${exercise.name} agregado' : '${exercise.name} removido')),
    );
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
                            title: Text(_pretty(option)),
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
                    )
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
    return _WorkoutTypeCarousel(
      selected: selected,
      onChanged: onChanged,
    );
  }
}

class ExerciseSearchField extends StatelessWidget {
  const ExerciseSearchField({
    super.key,
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Buscar ejercicio o músculo…',
        prefixIcon: Icon(Icons.search),
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
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onTapEquipment,
            child: Text(
              equipmentCount == 0 ? 'Filtro equipamiento' : 'Filtro equipamiento · $equipmentCount',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: onTapMuscle,
            child: Text(
              muscleCount == 0 ? 'Filtro muscular' : 'Filtro muscular · $muscleCount',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkoutTypeCarousel extends StatefulWidget {
  const _WorkoutTypeCarousel({required this.selected, required this.onChanged});

  final TemplateWorkoutType selected;
  final ValueChanged<TemplateWorkoutType> onChanged;

  @override
  State<_WorkoutTypeCarousel> createState() => _WorkoutTypeCarouselState();
}

class _WorkoutTypeCarouselState extends State<_WorkoutTypeCarousel> {
  static const _types = [TemplateWorkoutType.gym, TemplateWorkoutType.sport, TemplateWorkoutType.other];
  late final PageController _controller;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _page = _types.indexOf(widget.selected).toDouble();
    _controller = PageController(initialPage: _page.toInt(), viewportFraction: 0.35)
      ..addListener(() {
        setState(() {
          _page = _controller.page ?? _page;
        });
      });
  }

  @override
  void didUpdateWidget(covariant _WorkoutTypeCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      final target = _types.indexOf(widget.selected);
      if ((_page - target).abs() > 0.01) {
        _controller.animateToPage(target, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: PageView.builder(
        controller: _controller,
        itemCount: _types.length,
        onPageChanged: (index) => widget.onChanged(_types[index]),
        itemBuilder: (context, index) {
          final delta = (_page - index).abs().clamp(0.0, 1.0);
          final selected = delta < 0.2;
          final scale = 1 - (delta * 0.18);
          final opacity = 1 - (delta * 0.45);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    color: selected ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent,
                  ),
                  child: Text(_typeLabel(_types[index]), style: Theme.of(context).textTheme.titleSmall),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _typeLabel(TemplateWorkoutType type) {
    switch (type) {
      case TemplateWorkoutType.gym:
        return 'Gym';
      case TemplateWorkoutType.sport:
        return 'Deporte';
      case TemplateWorkoutType.other:
        return 'Otros';
    }
  }
}

class _SearchEmptyState extends StatelessWidget {
  const _SearchEmptyState({required this.showShortHint});

  final bool showShortHint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 38, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('Buscá un ejercicio o músculo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              showShortHint ? 'Escribí 2 o más letras' : 'Escribí arriba para ver resultados',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
            Text('Sin resultados', style: Theme.of(context).textTheme.titleMedium),
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

class ExerciseExpandableCard extends StatelessWidget {
  const ExerciseExpandableCard({
    super.key,
    required this.exercise,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onAdd,
    this.large = false,
  });

  final ExerciseDefinition exercise;
  final bool expanded;
  final bool selected;
  final bool large;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final titleStyle = large
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: large ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: large ? 22 : 18,
                    child: const Icon(Icons.fitness_center, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(exercise),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.help_outline),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Equipamiento: ${_pretty(exercise.equipment)}'),
                            Text('Músculo primario: ${exercise.primaryMuscles.join(', ')}'),
                            if (exercise.secondaryMuscles.isNotEmpty)
                              Text('Secundarios: ${exercise.secondaryMuscles.join(', ')}'),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: onAdd,
                              icon: Icon(selected ? Icons.check_circle : Icons.add_circle_outline),
                              label: Text(selected ? 'Agregado ✓' : 'Agregar'),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentExerciseCard extends StatelessWidget {
  const RecentExerciseCard({
    super.key,
    required this.exercise,
    required this.expanded,
    required this.selected,
    required this.onTap,
    required this.onAdd,
  });

  final ExerciseDefinition exercise;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ExerciseExpandableCard(
      exercise: exercise,
      expanded: expanded,
      selected: selected,
      onTap: onTap,
      onAdd: onAdd,
      large: true,
    );
  }
}

String _subtitle(ExerciseDefinition exercise) {
  final primary = exercise.primaryMuscles.isNotEmpty ? exercise.primaryMuscles.first : 'Sin músculo';
  return '$primary · ${_pretty(exercise.equipment)}';
}

String _pretty(String raw) {
  if (raw.isEmpty) return raw;
  final normalized = raw.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}
