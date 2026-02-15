import 'package:flutter/material.dart';

import '../pro/models/workout_models.dart';
import 'training_home_controller.dart';

Future<void> startRoutineFlow(
  BuildContext context,
  TrainingHomeController controller,
  WorkoutTemplate routine,
) async {
  await controller.markRoutineStarted(routine);
  if (!context.mounted) return;
  await Navigator.of(context).pushNamed(
    '/workout/session',
    arguments: {'templateId': routine.id},
  );
}
