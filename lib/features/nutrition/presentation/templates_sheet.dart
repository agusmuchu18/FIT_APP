import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';

class TemplatesSheet extends StatelessWidget {
  const TemplatesSheet({super.key, required this.controller});

  final FoodLogController controller;

  static Future<void> show(BuildContext context, FoodLogController controller) {
    return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => TemplatesSheet(controller: controller));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: controller.templates
          .map(
            (template) => ListTile(
              title: Text(template.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${template.entries.length} items · ${template.entries.fold(0.0, (a, b) => a + b.computedMacros.kcal).round()} kcal'),
              trailing: IconButton(onPressed: () => controller.deleteTemplate(template.id), icon: const Icon(Icons.delete_outline)),
              onTap: () async {
                final replace = await _askReplace(context);
                if (replace == null) return;
                await controller.loadTemplate(template, replace: replace);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          )
          .toList(),
    );
  }

  Future<bool?> _askReplace(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(title: const Text('Reemplazar borrador'), onTap: () => Navigator.pop(context, true)),
          ListTile(title: const Text('Sumar al borrador'), onTap: () => Navigator.pop(context, false)),
        ]),
      ),
    );
  }
}
