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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$exerciseCount ejercicios · $setCount series'),
                  const SizedBox(height: 4),
                  Text('Duración: $durationLabel',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton(
              onPressed: onSave,
              child: const Text('Guardar entrenamiento'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onFinish,
              child: const Text('Finalizar'),
            ),
          ],
        ),
      ),
    );
  }
}
