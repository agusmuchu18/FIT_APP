import 'package:flutter/material.dart';

enum IntegrationsFilter {
  all,
  fitness,
  health,
  sleep,
  nutrition,
  sports,
  connected,
}

class IntegrationsFilterChips extends StatelessWidget {
  const IntegrationsFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final IntegrationsFilter selected;
  final ValueChanged<IntegrationsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: IntegrationsFilter.values.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(filter)),
              selected: selected == filter,
              onSelected: (_) => onChanged(filter),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(IntegrationsFilter filter) {
    switch (filter) {
      case IntegrationsFilter.all:
        return 'Todas';
      case IntegrationsFilter.fitness:
        return 'Fitness';
      case IntegrationsFilter.health:
        return 'Salud';
      case IntegrationsFilter.sleep:
        return 'Sueño';
      case IntegrationsFilter.nutrition:
        return 'Nutrición';
      case IntegrationsFilter.sports:
        return 'Deportes';
      case IntegrationsFilter.connected:
        return 'Conectadas';
    }
  }
}
