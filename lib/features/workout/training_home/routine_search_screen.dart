import 'package:flutter/material.dart';

import '../pro/models/workout_models.dart';
import 'routine_preview_screen.dart';
import 'routines_repository.dart';
import 'training_home_controller.dart';
import '../../../app/theme/app_theme.dart';
import '../../common/theme/app_layout.dart';
import '../domain/routine_catalog.dart';
import 'catalog_routine_detail_screen.dart';

List<WorkoutTemplate> searchWorkoutRoutines(
  List<WorkoutTemplate> routines,
  String query,
) {
  final terms = foldRoutineSearch(query).trim().split(RegExp(r'\s+'));
  if (terms.length == 1 && terms.single.isEmpty) return routines;
  return routines
      .where((routine) {
        final haystack = foldRoutineSearch(
          [
            routine.name,
            routine.activityName ?? '',
            ...routine.exercises.map((exercise) => exercise.name),
          ].join(' '),
        );
        return terms.every(haystack.contains);
      })
      .toList(growable: false);
}

class WorkoutRoutineSearchScreen extends StatefulWidget {
  const WorkoutRoutineSearchScreen({super.key, this.repository});
  final RoutinesRepository? repository;

  @override
  State<WorkoutRoutineSearchScreen> createState() =>
      _WorkoutRoutineSearchScreenState();
}

class _WorkoutRoutineSearchScreenState
    extends State<WorkoutRoutineSearchScreen> {
  final _queryController = TextEditingController();
  late final _repository = widget.repository ?? RoutinesRepository();
  RoutineLevel? _level;
  bool _savedOnly = false;
  bool _navigating = false;
  late Future<List<WorkoutTemplate>> _routinesFuture = _repository
      .getAllRoutines();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openRoutine(WorkoutTemplate routine) async {
    if (_navigating) return;
    _navigating = true;
    final controller = TrainingHomeController();
    try {
      await controller.initialize();
      if (!mounted) return;
      final lastUsed = controller.metadataFor(routine.id).lastUsedAt;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RoutinePreviewScreen(
            routine: routine,
            controller: controller,
            typeLabel: switch (routine.type) {
              WorkoutType.strength => 'Fuerza',
              WorkoutType.cardio => 'Cardio',
              WorkoutType.functional => 'Funcional',
              WorkoutType.sport => 'Deporte',
              WorkoutType.custom => 'Personalizado',
            },
            lastUsedLabel: lastUsed == null ? 'Nunca' : 'Usada recientemente',
          ),
        ),
      );
      if (mounted) {
        _refreshSaved();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la rutina. Reintentá.'),
          ),
        );
      }
    } finally {
      _navigating = false;
      controller.dispose();
    }
  }

  Future<void> _openCatalog(CatalogRoutine routine) async {
    if (_navigating) return;
    _navigating = true;
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CatalogRoutineDetailScreen(
            routine: routine,
            repository: _repository,
          ),
        ),
      );
      if (saved == true && mounted) {
        setState(() {
          _savedOnly = true;
          _queryController.clear();
          _routinesFuture = _repository.getAllRoutines();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Rutina guardada en Mis rutinas. Ya podés iniciarla desde Entrenamiento.',
            ),
          ),
        );
      }
    } finally {
      _navigating = false;
    }
  }

  void _refreshSaved() {
    setState(() {
      _routinesFuture = _repository.getAllRoutines();
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Buscar rutinas')),
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu próxima sesión empieza acá',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${RoutineCatalog.routines.length} rutinas para explorar, adaptar y hacer tuyas. Disponibles sin conexión.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        labelText: _savedOnly
                            ? 'Buscar en mis rutinas'
                            : 'Nombre, objetivo o ejercicio',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _queryController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpiar búsqueda',
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(_queryController.clear),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ChoiceChip(
                          label: Text(
                            'Explorar (${RoutineCatalog.routines.length})',
                          ),
                          selected: !_savedOnly,
                          onSelected: (_) => setState(() => _savedOnly = false),
                        ),
                        ChoiceChip(
                          label: const Text('Mis rutinas'),
                          selected: _savedOnly,
                          onSelected: (_) => setState(() => _savedOnly = true),
                        ),
                      ],
                    ),
                    if (!_savedOnly) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos los niveles'),
                            selected: _level == null,
                            onSelected: (_) => setState(() => _level = null),
                          ),
                          for (final level in RoutineLevel.values)
                            ChoiceChip(
                              label: Text(level.label),
                              selected: _level == level,
                              onSelected: (_) => setState(() => _level = level),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_savedOnly) _savedSliver() else _catalogSliver(context),
          ],
        ),
      ),
    ),
  );

  Widget _catalogSliver(BuildContext context) {
    final matches = RoutineCatalog.search(_queryController.text, level: _level);
    if (matches.isEmpty) return SliverToBoxAdapter(child: _emptyResults());
    final wide =
        MediaQuery.sizeOf(context).width >= 720 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final children = <Widget>[];
    for (final level in RoutineLevel.values) {
      final group = matches.where((r) => r.level == level).toList();
      if (group.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${level.label} · ${group.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(level.description),
            ],
          ),
        ),
      );
      for (var i = 0; i < group.length; i += wide ? 2 : 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CatalogRoutineCover(
                          routine: group[i],
                          onTap: () => _openCatalog(group[i]),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: i + 1 < group.length
                            ? CatalogRoutineCover(
                                routine: group[i + 1],
                                onTap: () => _openCatalog(group[i + 1]),
                              )
                            : const SizedBox(),
                      ),
                    ],
                  )
                : CatalogRoutineCover(
                    routine: group[i],
                    onTap: () => _openCatalog(group[i]),
                  ),
          ),
        );
      }
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList.list(children: children),
    );
  }

  Widget _emptyResults() => Padding(
    padding: const EdgeInsets.all(AppSpacing.xl),
    child: Column(
      children: [
        const Icon(Icons.search_off_rounded, size: 32),
        const SizedBox(height: AppSpacing.md),
        const Text('No encontramos rutinas con esa búsqueda.'),
        TextButton(
          onPressed: () => setState(() {
            _queryController.clear();
            _level = null;
          }),
          child: const Text('Restablecer búsqueda'),
        ),
      ],
    ),
  );

  Widget _savedSliver() => SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    sliver: FutureBuilder<List<WorkoutTemplate>>(
      future: _routinesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Cargando mis rutinas',
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Column(
              children: [
                const Text(
                  'No se pudieron cargar tus rutinas. Las propuestas siguen disponibles en Explorar.',
                ),
                TextButton(
                  onPressed: _refreshSaved,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final routines = snapshot.data ?? const <WorkoutTemplate>[];
        if (routines.isEmpty) {
          return SliverToBoxAdapter(
            child: Column(
              children: [
                const Text(
                  'Todavía no guardaste rutinas. Explorá una propuesta y personalizala para empezar.',
                ),
                TextButton(
                  onPressed: () => setState(() => _savedOnly = false),
                  child: const Text('Explorar rutinas'),
                ),
              ],
            ),
          );
        }
        final matches = searchWorkoutRoutines(routines, _queryController.text);
        if (matches.isEmpty) return SliverToBoxAdapter(child: _emptyResults());
        return SliverList.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final routine = matches[index];
            return Card(
              child: ListTile(
                title: Text(routine.name),
                subtitle: Text('${routine.exercises.length} ejercicios'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openRoutine(routine),
              ),
            );
          },
        );
      },
    ),
  );
}
