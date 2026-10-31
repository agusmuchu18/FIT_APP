import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../domain/models.dart';

/// Keeps the existing API; every option now supports touch and keyboard.
class MealTypeWheel extends StatelessWidget {
  const MealTypeWheel({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final MealType selected;
  final ValueChanged<MealType> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final type in MealType.values)
        ChoiceChip(
          label: Text(mealTypeLabel(type)),
          selected: selected == type,
          onSelected: (_) => onChanged(type),
        ),
    ],
  );
}

@Preview(name: 'Selector de comida', size: Size(320, 180))
Widget mealTypeSelectorPreview() => MaterialApp(
  home: Scaffold(
    body: MealTypeWheel(selected: MealType.dinner, onChanged: (_) {}),
  ),
);
