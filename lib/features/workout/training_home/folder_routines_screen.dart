import 'routine_library_card.dart';
import 'routine_library_actions.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pro/models/workout_models.dart';
import 'routine_preview_screen.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';

class FolderRoutinesScreen extends StatelessWidget {
  const FolderRoutinesScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String? folderId;
  final String folderName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: Consumer<TrainingHomeController>(
        builder: (context, controller, _) {
          final routines = controller.routinesForFolder(folderId);
          if (routines.isEmpty) {
            return const Center(child: Text('No hay rutinas en esta carpeta.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RoutineLibraryCard(
                  routine: routine,
                  pinned: controller.metadataFor(routine.id).pinned,
                  lastUsed: controller.lastCompletedFor(routine.id) == null
                      ? 'Sin estrenar'
                      : 'Último entrenamiento: ${_daysAgoLabel(controller.lastCompletedFor(routine.id))}',
                  onOpen: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoutinePreviewScreen(
                        routine: routine,
                        controller: controller,
                        typeLabel: _typeLabel(routine.type),
                        lastUsedLabel: _daysAgoLabel(
                          controller.lastCompletedFor(routine.id),
                        ),
                      ),
                    ),
                  ),
                  onStart: () => startRoutineFlow(context, controller, routine),
                  onMenu: (action) => runRoutineLibraryAction(
                    context,
                    controller,
                    routine,
                    action,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _daysAgoLabel(DateTime? date) {
    if (date == null) return 'Nunca';
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return 'hoy';
    if (days == 1) return 'hace 1 día';
    return 'hace $days días';
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
}
