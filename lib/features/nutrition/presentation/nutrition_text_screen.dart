import 'widgets/nutrition_theme.dart';

import 'package:flutter/material.dart';

import '../data/food_repository.dart';
import '../domain/models.dart';

class NutritionTextEntryScreen extends StatefulWidget {
  const NutritionTextEntryScreen({
    super.key,
    required this.repository,
    required this.onApply,
  });
  final FoodRepository repository;
  final ValueChanged<List<DraftEntry>> onApply;
  @override
  State<NutritionTextEntryScreen> createState() =>
      _NutritionTextEntryScreenState();
}

class _TextLine {
  _TextLine(this.query, this.quantity, this.unit, this.matches)
    : food = matches.length == 1 ? matches.first : null;
  final String query;
  final FoodUnit unit;
  final List<FoodItem> matches;
  num? quantity;
  FoodItem? food;
  bool get valid =>
      food != null &&
      food!.detailsLoaded &&
      quantity != null &&
      quantity!.isFinite &&
      quantity! > 0 &&
      food!.supportsUnit(unit);
}

class _NutritionTextEntryScreenState extends State<NutritionTextEntryScreen> {
  final _text = TextEditingController();
  List<_TextLine> _lines = [];
  bool _busy = false;
  String? _error;
  int _generation = 0;
  @override
  void dispose() {
    _generation++;
    _text.dispose();
    super.dispose();
  }

  Future<void> _parse() async {
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final parsed = await widget.repository.parseStructuredText(_text.text);
      if (!mounted || generation != _generation) return;
      setState(
        () => _lines = parsed
            .map((r) => _TextLine(r.query, r.quantity, r.unit, r.matches))
            .toList(),
      );
    } on FormatException catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'No se pudo consultar el catálogo local. El texto se conserva.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  void _apply() {
    final entries = <String, DraftEntry>{};
    for (final line in _lines) {
      if (!line.valid) return;
      final food = line.food!;
      final old = entries[food.id];
      if (old != null && old.unit != line.unit) {
        setState(
          () => _error = 'Para el mismo alimento, usá una sola unidad o agregalo manualmente.',
        );
        return;
      }
      entries[food.id] = DraftEntry(
        food: food,
        quantity: (old?.quantity ?? 0) + line.quantity!,
        unit: line.unit,
      );
    }
    widget.onApply(entries.values.toList());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => NutritionTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Texto con cantidades')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Una línea por alimento, con una cantidad explícita. Ejemplo:\n125,5 g yogur\n0,5 porciones arroz\n\nSe consulta tu catálogo local. Esto no utiliza IA ni estima ingredientes.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(
              labelText: 'Comidas y cantidades',
            ),
            onChanged: (_) {
              _generation++;
              setState(() {
                _lines = [];
                _busy = false;
              });
            },
          ),
          FilledButton(
            onPressed: _busy ? null : _parse,
            child: Text(_busy ? 'Buscando…' : 'Buscar coincidencias'),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (var i = 0; i < _lines.length; i++) _line(_lines[i], i),
          if (_lines.isNotEmpty)
            FilledButton.icon(
              onPressed: _busy || _lines.any((r) => !r.valid) ? null : _apply,
              icon: const Icon(Icons.check),
              label: Text('Pasar ${_lines.length} al borrador'),
            ),
        ],
      ),
    ),
  );
  Widget _line(_TextLine line, int index) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.query, style: Theme.of(context).textTheme.titleMedium),
          if (line.matches.isEmpty)
            const Text(
              'Sin coincidencias. Revisá el nombre o creá el alimento desde el registro manual.',
            )
          else
            DropdownButtonFormField<String>(
              key: ValueKey('choice-$_generation-$index'),
              initialValue: line.food?.id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar alimento',
              ),
              items: [
                for (final f in line.matches)
                  DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      f.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(
                () => line.food = line.matches
                    .where((f) => f.id == id)
                    .firstOrNull,
              ),
            ),
          TextFormField(
            key: ValueKey('amount-$_generation-$index'),
            initialValue: line.quantity.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: line.unit == FoodUnit.grams
                  ? 'g'
                  : line.unit == FoodUnit.ml
                  ? 'ml'
                  : 'porciones',
            ),
            onChanged: (v) => setState(
              () => line.quantity = double.tryParse(v.replaceAll(',', '.')),
            ),
          ),
          if (line.food != null && !line.food!.supportsUnit(line.unit))
            const Text(
              'Este alimento no tiene una equivalencia confirmada para esa unidad.',
            ),
        ],
      ),
    ),
  );
}
