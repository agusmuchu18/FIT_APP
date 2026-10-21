import '../domain/training_program.dart';

import 'package:flutter/material.dart';

import '../data/workout_repository.dart';
import '../pro/models/workout_models.dart';
import '../workout_in_progress_controller.dart';
import 'training_home_controller.dart';

enum _ActiveSessionChoice { continueSession, replace, cancel }

final _openingSessions = Expando<bool>();

Future<void> startRoutineFlow(
  BuildContext context,
  TrainingHomeController controller,
  WorkoutTemplate routine, {
  ProgramExecutionRef? programExecution,
}) async {
  if (_openingSessions[controller] == true) return;
  _openingSessions[controller] = true;
  try {
    await _startRoutineFlow(
      context,
      controller,
      routine,
      programExecution: programExecution,
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir la sesión. Tus datos se conservan; reintentá.',
          ),
        ),
      );
    }
  } finally {
    _openingSessions[controller] = false;
  }
}

Future<void> _startRoutineFlow(
  BuildContext context,
  TrainingHomeController controller,
  WorkoutTemplate routine, {
  ProgramExecutionRef? programExecution,
}) async {
  final repository = WorkoutRepository();
  final draft = await repository.loadDraftExercises();
  final inProgress = WorkoutInProgressController.instance;
  await inProgress.refresh();
  final legacyDraft = draft == null && inProgress.isLegacyDraftActive;
  if (!context.mounted) return;
  if (draft != null || legacyDraft) {
    final identity = draft == null
        ? null
        : await repository.loadDraftIdentity();
    if (!context.mounted) return;
    if (legacyDraft ||
        identity?.routineId != routine.id ||
        identity?.programExecution?.occurrenceKey !=
            programExecution?.occurrenceKey) {
      final choice = await showDialog<_ActiveSessionChoice>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ya hay un entrenamiento en curso'),
          content: Text(
            'Podés continuar ${identity?.routineName ?? inProgress.routineName ?? 'la sesión actual'} o reemplazarla por ${routine.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ActiveSessionChoice.cancel),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _ActiveSessionChoice.continueSession,
              ),
              child: const Text('Continuar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ActiveSessionChoice.replace),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (!context.mounted ||
          choice == null ||
          choice == _ActiveSessionChoice.cancel) {
        return;
      }
      if (choice == _ActiveSessionChoice.continueSession) {
        await Navigator.of(context).pushNamed('/workout/session');
        await inProgress.refresh();
        await controller.refresh();
        return;
      }
      if (legacyDraft) {
        await inProgress.discard();
      } else {
        await repository.clearDraft();
      }
      await inProgress.refresh();
      if (!context.mounted) return;
    } else {
      await Navigator.of(context).pushNamed('/workout/session');
      await inProgress.refresh();
      await controller.refresh();
      return;
    }
  }
  await controller.markRoutineStarted(routine);
  if (!context.mounted) return;
  await Navigator.of(context).pushNamed(
    '/workout/session',
    arguments: {
      'templateId': routine.id,
      'programExecution': ?programExecution,
    },
  );
  await inProgress.refresh();
  await controller.refresh();
}
