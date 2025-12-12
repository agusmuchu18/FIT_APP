import 'package:flutter/material.dart';

import '../models/workout_models.dart';

class WorkoutTypeSelector extends StatelessWidget {
  const WorkoutTypeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCustomNameChanged,
    this.customName,
  });

  final WorkoutType selected;
  final String? customName;
  final ValueChanged<WorkoutType> onSelected;
  final ValueChanged<String> onCustomNameChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _typeChip(context, WorkoutType.strength, 'Fuerza'),
      _typeChip(context, WorkoutType.cardio, 'Cardio'),
      _typeChip(context, WorkoutType.functional, 'Funcional'),
      _typeChip(context, WorkoutType.sport, 'Deporte'),
      _typeChip(context, WorkoutType.custom, 'Otro'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
        if (selected == WorkoutType.custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Nombre personalizado',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              onChanged: onCustomNameChanged,
              controller: TextEditingController(text: customName)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: customName?.length ?? 0),
                ),
            ),
          ),
      ],
    );
  }

  Widget _typeChip(BuildContext context, WorkoutType type, String label) {
    final isSelected = selected == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(type),
    );
  }
}
