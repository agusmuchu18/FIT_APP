import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pro/models/workout_models.dart';
import 'routine_preview_screen.dart';
import 'start_routine_flow.dart';
import 'training_home_controller.dart';
import 'training_home_widgets.dart';

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
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final routine = routines[index];
              final metadata = controller.metadataFor(routine.id);
              final previewExercises = routine.exercises.map((exercise) => exercise.name).where((name) => name.trim().isNotEmpty).toList(growable: false);
              return RoutineMiniCard(
                title: routine.name,
                typeTag: _typeLabel(routine.type),
                secondaryTag: routine.activityName,
                exercisePreview: previewExercises,
                exerciseCount: routine.exercises.length,
                estimatedMinutes: controller.estimatedDuration(routine),
                lastUsed: 'Última vez: ${_daysAgoLabel(metadata.lastUsedAt)}',
                isPinned: metadata.pinned,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RoutinePreviewScreen(
                      routine: routine,
                      controller: controller,
                      typeLabel: _typeLabel(routine.type),
                      lastUsedLabel: _daysAgoLabel(metadata.lastUsedAt),
                    ),
                  ),
                ),
                onStartTap: () => startRoutineFlow(context, controller, routine),
                onMenuSelected: (_) {},
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
