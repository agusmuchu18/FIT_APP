import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/routine_labels.dart';
import '../domain/routine_plan_validation.dart';
import '../domain/sport_activity.dart';
import '../pro/data/exercise_definition.dart';
import '../pro/models/workout_models.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import 'exercise_configuration_sheet.dart';
import 'routine_draft_controller.dart';
import 'routines_repository.dart';
import 'template_workout_type.dart';
import 'template_exercise_picker_screen.dart';

class RoutineReviewScreen extends StatefulWidget {
  const RoutineReviewScreen({
    super.key,
    required this.draftController,
    required this.exercisesById,
    required this.repository,
    this.editingRoutine,
    this.onSaveEdit,
  });
  final RoutineDraftController draftController;
  final Map<String, ExerciseDefinition> exercisesById;
  final RoutinesRepository repository;
  final WorkoutTemplate? editingRoutine;
  final Future<void> Function(WorkoutTemplate)? onSaveEdit;
  @override
  State<RoutineReviewScreen> createState() => _RoutineReviewScreenState();
}

class _RoutineReviewScreenState extends State<RoutineReviewScreen> {
  late final _name = TextEditingController(text: widget.draftController.name);
  late final _notes = TextEditingController(text: widget.draftController.notes);
  bool _saving = false;
  final _form = GlobalKey<FormState>();
  late Future<List<RoutineFolder>> _folders = widget.repository.getFolders();
  RoutineDraftController get draft => widget.draftController;
  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workout,
    child: AnimatedBuilder(
      animation: draft,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.editingRoutine == null ? 'Nueva rutina' : 'Editar rutina',
          ),
        ),
        body: Form(
          key: _form,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la rutina',
                        ),
                        maxLength: 80,
                        onChanged: (v) => draft.updateHeader(name: v),
                        validator: (v) => v?.trim().isNotEmpty == true
                            ? null
                            : 'Ingresá un nombre',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notes,
                        decoration: const InputDecoration(
                          labelText: 'Notas (opcional)',
                        ),
                        maxLines: 2,
                        onChanged: (v) => draft.updateHeader(notes: v),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        draft.workoutType == TemplateWorkoutType.sport
                            ? 'Fútbol · ${draft.footballMode.label}'
                            : 'Gimnasio',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<RoutineFolder>>(
                        future: _folders,
                        builder: (context, snapshot) => snapshot.hasError
                            ? TextButton.icon(
                                onPressed: () => setState(
                                  () =>
                                      _folders = widget.repository.getFolders(),
                                ),
                                icon: const Icon(Icons.error_outline),
                                label: const Text(
                                  'No se pudieron cargar las carpetas. Reintentar',
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                key: ValueKey(
                                  '${draft.folderId}:${snapshot.connectionState}',
                                ),
                                initialValue:
                                    (snapshot.data ?? []).any(
                                      (f) => f.id == draft.folderId,
                                    )
                                    ? draft.folderId
                                    : '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Carpeta',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Sin carpeta'),
                                  ),
                                  for (final f in snapshot.data ?? [])
                                    DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.name),
                                    ),
                                ],
                                onChanged: (v) => draft.updateHeader(
                                  folderId: v,
                                  clearFolder: v == '',
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${draft.selectedCount} ${draft.workoutType == TemplateWorkoutType.sport && draft.footballMode != FootballMode.gym ? 'actividades' : 'ejercicios'} · ${draft.items.fold(0, (n, e) => n + e.targetSets)} series planificadas',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Ejercicios (${draft.selectedCount})',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton.icon(
                            onPressed: _add,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar'),
                          ),
                        ],
                      ),
                      if (draft.persistenceError != null)
                        const Text(
                          'No se pudo conservar el borrador. Tus cambios siguen abiertos; reintentá guardar.',
                        ),
                    ],
                  ),
                ),
              ),
              SliverReorderableList(
                itemCount: draft.items.length,
                onReorderItem: draft.reorder,
                itemBuilder: (context, index) {
                  final e = draft.items[index];
                  final large = MediaQuery.textScalerOf(context).scale(16) > 24;
                  return Padding(
                    key: ValueKey(e.instanceId),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExerciseThumbnail(exercise: e),
                                const SizedBox(width: 12),
                                if (!large) Expanded(child: _heading(e)),
                                if (large) const Spacer(),
                                PopupMenuButton<String>(
                                  tooltip: 'Opciones de ${e.name}',
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      await _edit(e);
                                    } else if (v == 'duplicate') {
                                      draft.duplicate(index);
                                    } else if (v == 'up' && index > 0) {
                                      draft.reorder(index, index - 1);
                                    } else if (v == 'down' &&
                                        index + 1 < draft.items.length) {
                                      draft.reorder(index, index + 1);
                                    } else if (v == 'delete') {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text(
                                            '¿Eliminar ejercicio?',
                                          ),
                                          content: const Text(
                                            'Se quitará del borrador con sus objetivos.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true && mounted) {
                                        draft.removeExerciseAt(index);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'duplicate',
                                      child: Text('Duplicar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'up',
                                      child: Text('Mover arriba'),
                                    ),
                                    PopupMenuItem(
                                      value: 'down',
                                      child: Text('Mover abajo'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (large) ...[
                              const SizedBox(height: 12),
                              _heading(e),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _edit(e),
                                  child: const Text('Editar'),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Semantics(
                                    label: 'Arrastrar para reordenar',
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed:
                  !_saving &&
                      draft.name.trim().isNotEmpty &&
                      draft.items.isNotEmpty
                  ? _save
                  : null,
              child: Text(
                _saving
                    ? 'Guardando…'
                    : widget.editingRoutine == null
                    ? 'Guardar rutina'
                    : 'Guardar cambios',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> _edit(WorkoutExercise e) async {
    final updated = await showExerciseConfiguration(
      context,
      e,
      definition: widget.exercisesById[e.id],
      sportGym:
          draft.workoutType == TemplateWorkoutType.sport &&
          draft.footballMode == FootballMode.gym,
    );
    if (updated != null && mounted) draft.update(e.instanceId!, updated);
  }

  Widget _heading(WorkoutExercise e) => InkWell(
    onTap: () => _edit(e),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RoutineLabels.exerciseName(e.name),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(RoutineLabels.summary(e)),
      ],
    ),
  );

  Future<void> _add() async {
    if (widget.editingRoutine == null) {
      Navigator.pop(context, false);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateExercisePickerScreen(
          draftController: draft,
          repository: widget.repository,
          selectionOnly: true,
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate() || draft.items.isEmpty) {
      return;
    }
    for (final e in draft.items) {
      final error = RoutinePlanValidation.error(e);
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await draft.flush();
      if (widget.editingRoutine case final original?) {
        await widget.onSaveEdit!(
          original.copyWith(
            type: draft.modeChanged
                ? toWorkoutType(draft.workoutType)
                : original.type,
            footballMode:
                (draft.modeChanged || original.footballMode != null) &&
                    draft.workoutType == TemplateWorkoutType.sport
                ? draft.footballMode
                : null,
            clearFootballMode:
                draft.modeChanged &&
                draft.workoutType != TemplateWorkoutType.sport,
            name: draft.name.trim(),
            notes: draft.notes,
            exercises: draft.items,
            folderId: draft.folderId,
            clearFolder: draft.folderId == null,
          ),
        );
      } else {
        await widget.repository.saveRoutine(
          name: draft.name.trim(),
          workoutType: toWorkoutType(draft.workoutType),
          exercises: draft.items,
          routineId: draft.draftId,
          notes: draft.notes,
          folderId: draft.folderId,
          footballMode: draft.workoutType == TemplateWorkoutType.sport
              ? draft.footballMode
              : null,
          activityName: draft.workoutType == TemplateWorkoutType.sport
              ? 'Fútbol'
              : 'Gimnasio',
        );
      }
      await draft.clearPersisted();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar la rutina. Tus cambios se conservan; reintentá.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
