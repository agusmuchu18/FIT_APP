import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/workout_session_controller.dart';
import '../pro/data/exercise_library.dart';
import 'widgets/exercise_card.dart';

class WorkoutInProgressScreen extends StatefulWidget {
  const WorkoutInProgressScreen({super.key});

  @override
  State<WorkoutInProgressScreen> createState() => _WorkoutInProgressScreenState();
}

class _WorkoutInProgressScreenState extends State<WorkoutInProgressScreen> {
  late final WorkoutSessionController _controller;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _controller = WorkoutSessionController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : const <String, dynamic>{};
    _controller.initialize(templateId: map['templateId'] as String?);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(value: _controller, child: const _WorkoutInProgressView());
  }
}

class _WorkoutInProgressView extends StatelessWidget {
  const _WorkoutInProgressView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<WorkoutSessionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento en progreso'),
        actions: [
          TextButton(
            onPressed: controller.exercises.isEmpty
                ? null
                : () async {
                    await controller.finishWorkout();
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: const Text('Terminar'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 180),
                itemCount: controller.exercises.length,
                itemBuilder: (context, index) {
                  final exercise = controller.exercises[index];
                  return ExerciseCard(
                    exercise: exercise,
                    isExpanded: controller.expandedExerciseId == exercise.id,
                    onTap: () => controller.toggleExerciseExpansion(exercise.id),
                    onNotesChanged: (value) => controller.updateExerciseNotes(exercise.id, value),
                    onRestToggle: (value) => controller.updateExerciseRest(
                      exercise.id,
                      enabled: value,
                      seconds: exercise.restSeconds ?? 90,
                    ),
                    onRestSecondsChanged: (seconds) => controller.updateExerciseRest(
                      exercise.id,
                      enabled: exercise.restEnabled,
                      seconds: seconds,
                    ),
                    onSetChanged: (setId, {kg, reps, done}) => controller.updateSet(
                      exercise.id,
                      setId,
                      kg: kg,
                      reps: reps,
                      done: done,
                    ),
                    onAddSet: () => controller.addSet(exercise.id),
                    onDelete: () => controller.removeExercise(exercise.id),
                    onMoveUp: () => controller.moveExerciseUp(exercise.id),
                    onMoveDown: () => controller.moveExerciseDown(exercise.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openAddExerciseSheet(context),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Agregar ejercicio'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openSettings(context),
                      child: const Text('Configuración'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmDiscard(context),
                      child: const Text('Descartar entreno'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddExerciseSheet(BuildContext context) async {
    final controller = context.read<WorkoutSessionController>();
    final query = ValueNotifier('');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12),
          child: SizedBox(
            height: 460,
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Buscar ejercicio', prefixIcon: Icon(Icons.search)),
                  onChanged: (value) => query.value = value,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: query,
                    builder: (context, value, _) {
                      final filtered = exerciseLibrary.where((exercise) => exercise.name.toLowerCase().contains(value.toLowerCase())).toList();
                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final exercise = filtered[index];
                          return ListTile(
                            title: Text(exercise.name),
                            subtitle: Text(exercise.primaryMuscles.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () async {
                              await controller.addExercise(exerciseId: exercise.id, name: exercise.name);
                              if (context.mounted) Navigator.of(context).pop();
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
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar entreno'),
        content: const Text('Se perderá el borrador actual. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Descartar')),
        ],
      ),
    );

    if (shouldDiscard == true && context.mounted) {
      await context.read<WorkoutSessionController>().discardWorkout();
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuración', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Próximamente: descanso global, unidades y más opciones.'),
          ],
        ),
      ),
    );
  }
}
