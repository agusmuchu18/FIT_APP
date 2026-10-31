import '../domain/models.dart';

import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';

class TemplatesSheet extends StatelessWidget {
  const TemplatesSheet({super.key, required this.controller});

  final FoodLogController controller;

  static Future<void> show(BuildContext context, FoodLogController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TemplatesSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: controller.templates
            .map(
              (template) => ListTile(
                title: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${template.entries.length} ingredientes · ${MacroValues.display(template.portion(1).effectiveTotals.kcal, decimals: 0)} kcal por ración',
                ),
                trailing: IconButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Eliminar plantilla'),
                        content: const Text(
                          'Los registros anteriores conservarán su composición.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        await controller.deleteTemplate(template.id);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo eliminar. La plantilla se conserva.',
                              ),
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: template.entries.isEmpty
                    ? null
                    : () async {
                        final replace = await _askReplace(context);
                        if (replace == null) return;
                        try {
                          await controller.loadTemplate(
                            template.portion(1),
                            replace: replace,
                          );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pueden mezclar unidades o composiciones. Elegí reemplazar el borrador.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
            )
            .toList(),
      ),
    );
  }

  Future<bool?> _askReplace(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('Reemplazar borrador'),
              onTap: () => Navigator.pop(context, true),
            ),
            ListTile(
              title: const Text('Sumar al borrador'),
              onTap: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
