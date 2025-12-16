import 'package:flutter/material.dart';

class WorkoutBottomBar extends StatelessWidget {
  const WorkoutBottomBar({
    super.key,
    required this.exerciseCount,
    required this.setCount,
    required this.durationLabel,
    required this.onSave,
    required this.onFinish,
  });

  final int exerciseCount;
  final int setCount;
  final String durationLabel;
  final VoidCallback onSave;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final hasExercises = exerciseCount > 0;

    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$exerciseCount ejercicios · $setCount series'),
                    const SizedBox(height: 4),
                    Text(
                      'Duración: $durationLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: onSave,
                    child: const Text('Guardar borrador'),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: hasExercises ? onFinish : null,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Finalizar sesión'),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
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
