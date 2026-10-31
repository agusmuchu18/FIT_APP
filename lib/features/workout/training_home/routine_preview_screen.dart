import '../presentation/widgets/workout_units_host.dart';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/routine_labels.dart';
import '../domain/sport_activity.dart';
import '../pro/models/workout_models.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';
import 'routine_library_card.dart';
import 'routine_library_actions.dart';

class RoutinePreviewScreen extends StatelessWidget {
  const RoutinePreviewScreen({
    super.key,
    required this.routine,
    required this.controller,
    required this.typeLabel,
    required this.lastUsedLabel,
  });
  final WorkoutTemplate routine;
  final TrainingHomeController controller;
  final String typeLabel, lastUsedLabel;
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final current = controller.routines
            .where((e) => e.id == routine.id)
            .firstOrNull;
        if (current == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Rutina eliminada')),
            body: const Center(
              child: Text(
                'La rutina ya no está disponible. Tus sesiones se conservan.',
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ver rutina'),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Opciones de rutina',
                onSelected: (v) =>
                    runRoutineLibraryAction(context, controller, current, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                  PopupMenuItem(value: 'move', child: Text('Mover a carpeta')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (current.exercises.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ExerciseThumbnail(
                    exercise: current.exercises.first,
                    size: 120,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                current.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(RoutineLibraryCard.type(current)),
              Text(RoutineLibraryCard.focus(current)),
              const SizedBox(height: 12),
              Text(
                '${current.exercises.length} ejercicios · ${current.exercises.fold(0, (n, e) => n + e.targetSets)} series planificadas',
              ),
              Text(
                controller.lastCompletedFor(current.id) == null
                    ? 'Sin estrenar'
                    : 'Último entrenamiento: ${controller.lastCompletedFor(current.id)!.toLocal().toString().split(' ').first}',
              ),
              if (current.notes?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(current.notes!),
              ],
              const SizedBox(height: 24),
              Text(
                'Configuración guardada',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final e in current.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExerciseThumbnail(exercise: e),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      RoutineLabels.exerciseName(e.name),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      RoutineLabels.summary(
                                        e,
                                        units: WorkoutUnits.of(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (e.sportPlan case final p?) ...[
                            if (p.objective.isNotEmpty)
                              Text('Objetivo: ${p.objective}'),
                            for (final v in p.targets.values.entries)
                              Text('${v.key.label}: ${v.value}'),
                            if (p.targets.position.isNotEmpty)
                              Text('Posición: ${p.targets.position}'),
                          ],
                          for (var i = 0; i < e.setTargets.length; i++)
                            Text(
                              'Serie ${i + 1}: ${e.setTargets[i].durationSeconds == null ? '${e.setTargets[i].reps ?? '${e.setTargets[i].repsMin}–${e.setTargets[i].repsMax}'} repeticiones' : '${e.setTargets[i].durationSeconds}s'} · ${RoutineLabels.setTargetSummary(e, e.setTargets[i], WorkoutUnits.of(context))}',
                            ),
                          if (e.notes?.isNotEmpty == true) Text(e.notes!),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        startRoutineFlow(context, controller, current),
                    child: const Text('Iniciar entrenamiento'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => runRoutineLibraryAction(
                      context,
                      controller,
                      current,
                      'edit',
                    ),
                    child: const Text('Editar rutina'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
