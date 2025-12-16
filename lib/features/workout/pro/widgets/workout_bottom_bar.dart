import 'package:flutter/material.dart';

class WorkoutBottomBar extends StatelessWidget {
  const WorkoutBottomBar({
    super.key,
    required this.exerciseCount,
    required this.setCount,
    required this.durationLabel,
    required this.onAddExercise,
    required this.onSave,
    required this.onFinish,
  });

  final int exerciseCount;
  final int setCount;
  final String durationLabel;
  final VoidCallback onAddExercise;
  final VoidCallback onSave;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final hasExercises = exerciseCount > 0;

    return Material(
      color: Colors.transparent,
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
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: hasExercises
                    ? Row(
                        key: const ValueKey('with_exercises'),
                        children: [
                          OutlinedButton(
                            onPressed: onSave,
                            child: const Text('Guardar borrador'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: onFinish,
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Finalizar sesión'),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('empty'),
                        children: [
                          OutlinedButton.icon(
                            onPressed: onSave,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Guardar borrador'),
                            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: onAddExercise,
                            child: const Text('Agregar ejercicio'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
