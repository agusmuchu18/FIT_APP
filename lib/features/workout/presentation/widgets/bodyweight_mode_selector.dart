import 'package:flutter/material.dart';

import '../../domain/exercise_load_policy.dart';
import '../../pro/models/workout_models.dart';

/// Shared inline choices for plans, exercise defaults and individual sets.
class BodyweightModeSelector extends StatelessWidget {
  const BodyweightModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.disclosure = false,
    this.title,
  });
  final RoutineExerciseLoadType value;
  final ValueChanged<RoutineExerciseLoadType>? onChanged;
  final bool disclosure;
  final String? title;
  static String label(RoutineExerciseLoadType type) => switch (type) {
    RoutineExerciseLoadType.addedWeightKg => 'Con lastre',
    RoutineExerciseLoadType.assistedKg => 'Con asistencia',
    _ => 'Solo peso corporal',
  };
  @override
  Widget build(BuildContext context) {
    final options = LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final mode in ExerciseLoadPolicy.bodyweightModes)
            ChoiceChip(
              label: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (constraints.maxWidth - 64).clamp(
                    1,
                    double.infinity,
                  ),
                ),
                child: Text(
                  label(mode),
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                ),
              ),
              selected: value == mode,
              onSelected: onChanged == null ? null : (_) => onChanged!(mode),
            ),
        ],
      ),
    );
    return disclosure
        ? ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              title ??
                  (value == RoutineExerciseLoadType.bodyweight
                      ? 'Añadir lastre o asistencia'
                      : label(value)),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            children: [options],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(title!, style: Theme.of(context).textTheme.labelLarge),
              options,
            ],
          );
  }
}
