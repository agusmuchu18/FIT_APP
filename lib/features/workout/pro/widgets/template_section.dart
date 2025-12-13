import 'package:flutter/material.dart';

import '../models/workout_models.dart';

class TemplateSection extends StatelessWidget {
  const TemplateSection({
    super.key,
    required this.standardTemplates,
    required this.userTemplates,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  final List<WorkoutTemplate> standardTemplates;
  final List<WorkoutTemplate> userTemplates;
  final WorkoutTemplate? selected;
  final ValueChanged<WorkoutTemplate> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.view_module_outlined),
                const SizedBox(width: 8),
                const Text('Plantilla', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                if (selected != null)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Cambiar'),
                  )
                else
                  TextButton(
                    onPressed: () => _openSelector(context),
                    child: const Text('Seleccionar'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (selected == null)
              OutlinedButton.icon(
                onPressed: () => _openSelector(context),
                icon: const Icon(Icons.search),
                label: const Text('Seleccionar plantilla'),
              )
            else
              _TemplateChip(template: selected!),
          ],
        ),
      ),
    );
  }

  Future<void> _openSelector(BuildContext context) async {
    final chosen = await showModalBottomSheet<WorkoutTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TemplatePicker(
        standardTemplates: standardTemplates,
        userTemplates: userTemplates,
      ),
    );
    if (chosen != null) {
      onSelect(chosen);
    }
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.standardTemplates,
    required this.userTemplates,
  });

  final List<WorkoutTemplate> standardTemplates;
  final List<WorkoutTemplate> userTemplates;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Plantillas estándar', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...standardTemplates.map((e) => _TemplateTile(template: e)),
            const SizedBox(height: 16),
            const Text('Mis plantillas', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (userTemplates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Aún no guardaste plantillas personalizadas.'),
              )
            else
              ...userTemplates.map((e) => _TemplateTile(template: e)),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(template.name),
      subtitle: Text(_typeLabel(template.type)),
      trailing: Text(template.origin == TemplateOrigin.user ? 'Mía' : 'Estándar'),
      onTap: () => Navigator.of(context).pop(template),
    );
  }

  String _typeLabel(WorkoutType type) {
    switch (type) {
      case WorkoutType.strength:
        return 'Fuerza';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.functional:
        return 'Funcional';
      case WorkoutType.sport:
        return 'Deporte';
      case WorkoutType.custom:
        return 'Custom';
    }
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({required this.template});

  final WorkoutTemplate template;

  @override
  Widget build(BuildContext context) {
    final originLabel = template.origin == TemplateOrigin.user ? 'Mía' : 'Estándar';
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
        title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(originLabel),
      ),
    );
  }
}
