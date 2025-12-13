import 'package:flutter/material.dart';

import '../models/workout_models.dart';

class WorkoutTypeSelector extends StatefulWidget {
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
  State<WorkoutTypeSelector> createState() => _WorkoutTypeSelectorState();
}

class _WorkoutTypeSelectorState extends State<WorkoutTypeSelector> {
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController(text: widget.customName ?? '');
  }

  @override
  void didUpdateWidget(covariant WorkoutTypeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customName != _customController.text) {
      _customController.text = widget.customName ?? '';
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

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
        if (widget.selected == WorkoutType.custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              controller: _customController,
              decoration: const InputDecoration(
                labelText: 'Nombre personalizado',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              onChanged: widget.onCustomNameChanged,
            ),
          ),
      ],
    );
  }

  Widget _typeChip(BuildContext context, WorkoutType type, String label) {
    final isSelected = widget.selected == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => widget.onSelected(type),
    );
  }
}
