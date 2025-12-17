import 'package:flutter/material.dart';

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
  });

  final int exerciseCount;
  final int setCount;
  final String durationLabel;
  final VoidCallback? onAddExercise;
  final VoidCallback onSave;
  final VoidCallback onFinish;
  final bool showAddExercise;
  final bool canSaveDraft;
  final bool canFinish;
  final String? validationHint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.35),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$exerciseCount ejercicios · $setCount series',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Duración $durationLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (validationHint != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          validationHint!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (showAddExercise)
                    FilledButton.icon(
                      onPressed: onAddExercise,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar ejercicio'),
                    ),
                  OutlinedButton(
                    onPressed: canSaveDraft ? onSave : null,
                    child: const Text('Guardar borrador'),
                  ),
                  FilledButton.icon(
                    onPressed: canFinish ? onFinish : null,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Finalizar sesión'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
