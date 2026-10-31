import 'package:flutter/material.dart';

import '../pro/models/workout_models.dart';
import 'routine_edit_screen.dart';
import 'training_home_controller.dart';

Future<void> runRoutineLibraryAction(
  BuildContext context,
  TrainingHomeController controller,
  WorkoutTemplate routine,
  String action,
) async {
  try {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RoutineEditScreen(routine: routine, controller: controller),
        ),
      );
    } else if (action == 'pin') {
      await controller.togglePinned(routine);
    } else if (action == 'duplicate') {
      await controller.duplicateRoutine(routine);
    } else if (action == 'move') {
      final folder = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (c) => ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Mover a carpeta')),
            ListTile(
              title: const Text('Sin carpeta'),
              onTap: () => Navigator.pop(c, ''),
            ),
            for (final f in controller.folders)
              ListTile(
                title: Text(f.name),
                onTap: () => Navigator.pop(c, f.id),
              ),
          ],
        ),
      );
      if (folder != null) {
        await controller.moveRoutineToFolder(
          routine,
          folder.isEmpty ? null : folder,
        );
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Eliminar rutina?'),
          content: const Text(
            'Se quitará la plantilla. Los entrenamientos realizados se conservan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (confirmed == true) await controller.deleteRoutine(routine);
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar la acción. Reintentá.'),
        ),
      );
    }
  }
}
