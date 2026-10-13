import 'package:flutter/material.dart';

import '../pro/data/exercise_library.dart';
import '../pro/models/workout_models.dart';
import 'routine_draft_controller.dart';
import 'routine_review_screen.dart';
import 'routines_repository.dart';
import 'training_home_controller.dart';

class RoutineEditScreen extends StatefulWidget {
  const RoutineEditScreen({
    super.key,
    required this.routine,
    required this.controller,
  });
  final WorkoutTemplate routine;
  final TrainingHomeController controller;
  @override
  State<RoutineEditScreen> createState() => _RoutineEditScreenState();
}

class _RoutineEditScreenState extends State<RoutineEditScreen> {
  late final draft = RoutineDraftController(editingRoutineId: widget.routine.id)
    ..hydrate(widget.routine);
  late Future<void> _restore = draft.restore(force: true);
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _restore,
    builder: (context, snapshot) =>
        snapshot.connectionState != ConnectionState.done
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : draft.restoreFailed
        ? Scaffold(
            appBar: AppBar(title: const Text('Editar rutina')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No se pudo recuperar el borrador de edición. Se conserva sin sobrescribir.',
                    ),
                    FilledButton(
                      onPressed: () =>
                          setState(() => _restore = draft.restore(force: true)),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          )
        : RoutineReviewScreen(
            draftController: draft,
            exercisesById: {for (final e in exerciseLibrary) e.id: e},
            repository: RoutinesRepository(),
            editingRoutine: widget.routine,
            onSaveEdit: widget.controller.updateRoutine,
          ),
  );
}
