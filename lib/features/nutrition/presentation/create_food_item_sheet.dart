import 'package:flutter/material.dart';

import '../application/food_log_controller.dart';
import '../domain/models.dart';

class CreateFoodItemSheet extends StatefulWidget {
  const CreateFoodItemSheet({
    super.key,
    required this.controller,
    this.food,
    this.barcode,
  });

  final FoodLogController controller;
  final FoodItem? food;
  final String? barcode;

  static Future<void> show(
    BuildContext context,
    FoodLogController controller, {
    FoodItem? food,
    String? barcode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateFoodItemSheet(
        controller: controller,
        food: food,
        barcode: barcode,
      ),
    );
  }

  @override
  State<CreateFoodItemSheet> createState() => _CreateFoodItemSheetState();
}

class _CreateFoodItemSheetState extends State<CreateFoodItemSheet> {
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _category = TextEditingController(text: 'Propio');
  final _kcal = TextEditingController();
  final _p = TextEditingController();
  final _c = TextEditingController();
  final _f = TextEditingController();
  final _gramsServing = TextEditingController(text: '100');

  bool byServing = false;
  bool _perMl = false;
  @override
  void initState() {
    super.initState();
    final f = widget.food;
    _barcode.text = widget.barcode ?? f?.barcode ?? '';
    if (f != null) {
      _name.text = f.name;
      _category.text = f.categoryLabel;
      _perMl =
          f.macrosPer100ml != null && f.unitSupport == FoodUnitSupport.mlOnly;
      final m = _perMl ? f.macrosPer100ml! : f.macrosPer100;
      _kcal.text = m.kcal?.toString() ?? '';
      _p.text = m.protein?.toString() ?? '';
      _c.text = m.carbs?.toString() ?? '';
      _f.text = m.fat?.toString() ?? '';
      _gramsServing.text =
          (f.defaultServingGrams > 0 ? f.defaultServingGrams : 100).toString();
    }
  }

  bool _saving = false;
  @override
  void dispose() {
    for (final c in [
      _name,
      _barcode,
      _category,
      _kcal,
      _p,
      _c,
      _f,
      _gramsServing,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Código de barras (opcional)',
              ),
            ),
            TextField(
              controller: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
            ),
            SwitchListTile(
              title: const Text('Base por 100 ml'),
              subtitle: const Text('Sin convertir mililitros a gramos.'),
              value: _perMl,
              onChanged: (v) => setState(() {
                _perMl = v;
                if (v) byServing = false;
              }),
            ),
            if (!_perMl)
              SwitchListTile(
                title: const Text('Base por porción'),
                value: byServing,
                onChanged: (v) => setState(() => byServing = v),
              ),
            if (byServing)
              TextField(
                controller: _gramsServing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Gramos por porción',
                ),
              ),
            TextField(
              controller: _kcal,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Kcal'),
            ),
            TextField(
              controller: _p,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Proteína'),
            ),
            TextField(
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Carbos'),
            ),
            TextField(
              controller: _f,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Grasas'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un nombre para el alimento')),
      );
      return;
    }
    if (_saving) return;
    final serving =
        double.tryParse(_gramsServing.text.replaceAll(',', '.')) ?? double.nan;
    if (!serving.isFinite || serving <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La porción debe ser mayor que cero')),
      );
      return;
    }
    double? parse(TextEditingController c) {
      if (c.text.trim().isEmpty) return null;
      final v = double.tryParse(c.text.replaceAll(',', '.'));
      if (v == null || !v.isFinite || v < 0) {
        throw const FormatException(
          'Usá números positivos, o dejá vacío si no lo conocés.',
        );
      }
      return v;
    }

    late MacroValues base;
    try {
      base = MacroValues(
        kcal: parse(_kcal),
        protein: parse(_p),
        carbs: parse(_c),
        fat: parse(_f),
      );
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    String? barcode;
    try {
      barcode = _barcode.text.trim().isEmpty
          ? null
          : normalizeNutritionBarcode(_barcode.text);
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    setState(() => _saving = true);
    final factor = byServing ? (100 / serving) : 1;
    try {
      await widget.controller.createFood(
        FoodItem(
          id:
              widget.food?.id ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          barcode: barcode,
          categoryLabel: _category.text,
          macrosPer100: _perMl
              ? MacroValues.unknown
              : base.scale(factor.toDouble()),
          macrosPer100ml: _perMl ? base : null,
          defaultServingGrams: _perMl ? 0 : serving,
          unitSupport: _perMl
              ? FoodUnitSupport.mlOnly
              : FoodUnitSupport.gramsAndServing,
          isCustom: true,
          source: 'user',
          micronutrients: widget.food?.micronutrients ?? {},
          originalName: widget.food?.originalName,
          externalId: widget.food?.externalId,
          brand: widget.food?.brand,
          preparation: widget.food?.preparation,
          servingVerified: true,
          searchKeywords: name.toLowerCase().split(' '),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el alimento')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
