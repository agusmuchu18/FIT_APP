import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';
import '../domain/models.dart';

class MealDraftSheet extends StatelessWidget {
  const MealDraftSheet({super.key, required this.controller});
  final FoodLogController controller;

  static Future<void> show(
    BuildContext context,
    FoodLogController controller,
  ) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => MealDraftSheet(controller: controller),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => DraggableScrollableSheet(
      minChildSize: 0.35,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        final draft = controller.currentDraft;
        final totals = draft.totals;
        final busy = controller.isRegistering;
        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                '${mealTypeLabel(draft.mealType)} · ${draft.itemCount} alimentos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text('${MacroValues.display(totals.kcal, decimals: 0)} kcal'),
              Text(
                'P ${MacroValues.display(totals.protein)} · C ${MacroValues.display(totals.carbs)} · G ${MacroValues.display(totals.fat)}',
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: draft.entries.length,
                  itemBuilder: (_, i) {
                    final entry = draft.entries[i];
                    return Dismissible(
                      key: ValueKey(entry.food.id),
                      direction: busy
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      onDismissed: (_) => controller.removeEntry(entry.food.id),
                      child: ListTile(
                        title: Text(entry.food.name),
                        subtitle: Text(
                          '${MacroValues.display(entry.quantity.toDouble())} ${entry.unit == FoodUnit.ml
                              ? 'ml'
                              : entry.unit == FoodUnit.grams
                              ? 'g'
                              : 'porciones · ${MacroValues.display(entry.effectiveGrams.toDouble())} g'}',
                        ),
                        trailing: Text(
                          '${MacroValues.display(entry.computedMacros.kcal, decimals: 0)} kcal',
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: busy || draft.entries.isEmpty
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await controller.registerCurrentDraft();
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Comida registrada'),
                                  ),
                                );
                              } catch (_) {
                                if (context.mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No se pudo guardar. El borrador sigue intacto.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(busy ? 'Guardando…' : 'Registrar en el día'),
                    ),
                    OutlinedButton(
                      onPressed: busy || draft.entries.isEmpty
                          ? null
                          : () => _saveTemplate(context),
                      child: const Text('Guardar como receta'),
                    ),
                    TextButton(
                      onPressed: busy || draft.entries.isEmpty
                          ? null
                          : controller.clearDraft,
                      child: const Text('Vaciar borrador'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future<void> _saveTemplate(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _SaveRecipeDialog(controller: controller),
  );
}

class _SaveRecipeDialog extends StatefulWidget {
  const _SaveRecipeDialog({required this.controller});
  final FoodLogController controller;
  @override
  State<_SaveRecipeDialog> createState() => _SaveRecipeDialogState();
}

class _SaveRecipeDialogState extends State<_SaveRecipeDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá un nombre.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.saveTemplate(_name.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No se pudo guardar. Reintentá.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Nombre de receta'),
      content: TextField(
        controller: _name,
        enabled: !_busy,
        maxLength: 120,
        decoration: InputDecoration(labelText: 'Nombre', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando…' : 'Guardar'),
        ),
      ],
    ),
  );
}
