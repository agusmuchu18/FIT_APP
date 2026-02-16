import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';
import '../domain/models.dart';

class MealDraftSheet extends StatelessWidget {
  const MealDraftSheet({super.key, required this.controller});

  final FoodLogController controller;

  static Future<void> show(BuildContext context, FoodLogController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MealDraftSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      minChildSize: 0.35,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final draft = controller.currentDraft;
        final totals = draft.totals;
        return Container(
          decoration: const BoxDecoration(color: Color(0xFF161F2C), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 8),
            Container(height: 4, width: 50, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 8),
            Text('${mealTypeLabel(draft.mealType)} · ${draft.itemCount} items'),
            Text('${totals.kcal.round()} kcal'),
            Text('P ${totals.protein.round()} · C ${totals.carbs.round()} · G ${totals.fat.round()}'),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: draft.entries.length,
                itemBuilder: (_, i) {
                  final entry = draft.entries[i];
                  return Dismissible(
                    key: ValueKey(entry.food.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => controller.removeEntry(entry.food.id),
                    child: ListTile(
                      title: Text(entry.food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('x${entry.quantity} / ${entry.effectiveGrams}g'),
                      trailing: Text('${entry.computedMacros.kcal.round()} kcal'),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await controller.registerCurrentDraft();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comida registrada')));
                      }
                    },
                    child: const Text('Registrar en el día'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _saveTemplate(context),
                    child: const Text('Guardar como plantilla'),
                  ),
                ),
                TextButton(onPressed: controller.clearDraft, child: const Text('Vaciar borrador')),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _saveTemplate(BuildContext context) async {
    final controllerName = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nombre de plantilla'),
        content: TextField(controller: controllerName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await controller.saveTemplate(controllerName.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
