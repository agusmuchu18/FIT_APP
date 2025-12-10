import 'package:flutter/material.dart';

class TemplateSelector extends StatelessWidget {
  const TemplateSelector({
    super.key,
    required this.templates,
    required this.onSelected,
    this.title = 'Plantillas',
  });

  final List<String> templates;
  final ValueChanged<String> onSelected;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: templates
              .map((template) => ChoiceChip(
                    label: Text(template),
                    selected: false,
                    onSelected: (_) => onSelected(template),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
