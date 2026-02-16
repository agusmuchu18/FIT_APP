import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';
import '../domain/models.dart';

class CreateFoodItemSheet extends StatefulWidget {
  const CreateFoodItemSheet({super.key, required this.controller});

  final FoodLogController controller;

  static Future<void> show(BuildContext context, FoodLogController controller) {
    return showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => CreateFoodItemSheet(controller: controller));
  }

  @override
  State<CreateFoodItemSheet> createState() => _CreateFoodItemSheetState();
}

class _CreateFoodItemSheetState extends State<CreateFoodItemSheet> {
  final _name = TextEditingController();
  final _category = TextEditingController(text: 'Custom');
  final _kcal = TextEditingController();
  final _p = TextEditingController();
  final _c = TextEditingController();
  final _f = TextEditingController();
  final _gramsServing = TextEditingController(text: '100');

  bool byServing = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
          TextField(controller: _category, decoration: const InputDecoration(labelText: 'Categoría')),
          SwitchListTile(title: const Text('Base por porción'), value: byServing, onChanged: (v) => setState(() => byServing = v)),
          if (byServing) TextField(controller: _gramsServing, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Gramos por porción')),
          TextField(controller: _kcal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kcal')),
          TextField(controller: _p, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Proteína')),
          TextField(controller: _c, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Carbos')),
          TextField(controller: _f, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Grasas')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Guardar'))),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final serving = int.tryParse(_gramsServing.text) ?? 100;
    final base = MacroValues(
      kcal: double.tryParse(_kcal.text) ?? 0,
      protein: double.tryParse(_p.text) ?? 0,
      carbs: double.tryParse(_c.text) ?? 0,
      fat: double.tryParse(_f.text) ?? 0,
    );
    final factor = byServing ? (100 / serving) : 1;
    await widget.controller.createFood(FoodItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      categoryLabel: _category.text,
      macrosPer100: base.scale(factor.toDouble()),
      defaultServingGrams: serving,
      unitSupport: FoodUnitSupport.gramsAndServing,
      isCustom: true,
      searchKeywords: name.toLowerCase().split(' '),
    ));
    if (mounted) Navigator.pop(context);
  }
}
