import 'package:flutter/material.dart';

import '../../../common/theme/app_layout.dart';

class WorkoutBottomBar extends StatelessWidget {
  const WorkoutBottomBar({
    super.key,
    required this.exerciseCount,
    required this.setCount,
    required this.durationLabel,
    required this.onSave,
    required this.onFinish,
    this.onAddExercise,
    this.showAddExercise = false,
    this.canSaveDraft = true,
    this.canFinish = true,
    this.validationHint,
    this.isSaving = false,
    this.completionPending = false,
    this.paused = false,
    this.onPause,
  });
  final int exerciseCount, setCount;
  final String durationLabel;
  final VoidCallback? onAddExercise, onPause;
  final VoidCallback onSave, onFinish;
  final bool showAddExercise,
      canSaveDraft,
      canFinish,
      isSaving,
      completionPending,
      paused;
  final String? validationHint;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$exerciseCount ejercicios · $setCount series · ${paused ? 'En pausa' : 'Duración'} $durationLabel',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (validationHint != null)
              Text(
                validationHint!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: canFinish ? onFinish : null,
              child: Text(
                isSaving
                    ? 'Guardando entrenamiento…'
                    : completionPending
                    ? 'Reintentar guardado'
                    : 'Finalizar entrenamiento',
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                if (showAddExercise)
                  TextButton(
                    onPressed: onAddExercise,
                    child: const Text('Agregar ejercicio'),
                  ),
                TextButton(
                  onPressed: canSaveDraft ? onSave : null,
                  child: const Text('Guardar borrador'),
                ),
                if (onPause != null)
                  TextButton(
                    onPressed: canSaveDraft ? onPause : null,
                    child: Text(paused ? 'Reanudar' : 'Pausar sesión'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
