import 'package:flutter/material.dart';

import '../domain/models.dart';
import 'food_log_screen.dart';
import 'widgets/nutrition_theme.dart';

class NutritionFoodCompareScreen extends StatefulWidget {
  const NutritionFoodCompareScreen({super.key});
  @override
  State<NutritionFoodCompareScreen> createState() =>
      _NutritionFoodCompareScreenState();
}

class _NutritionFoodCompareScreenState
    extends State<NutritionFoodCompareScreen> {
  DraftEntry? _a, _b;
  Future<void> _pick(bool first) async {
    final selected = await Navigator.push<List<DraftEntry>>(
      context,
      MaterialPageRoute(builder: (_) => const FoodLogScreen(selectOnly: true)),
    );
    if (!mounted || selected == null) return;
    if (selected.length != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elegí un solo alimento para cada columna.'),
        ),
      );
      return;
    }
    setState(() {
      if (first) {
        _a = selected.single;
      } else {
        _b = selected.single;
      }
    });
  }

  bool _ml(DraftEntry? e) => e?.unit == FoodUnit.ml;
  MacroValues _base(DraftEntry? e) => e == null
      ? MacroValues.unknown
      : _ml(e)
      ? e.food.macrosPer100ml ?? MacroValues.unknown
      : e.food.macrosPer100;
  String _basis(DraftEntry? e) => _ml(e) ? '100 ml' : '100 g';
  @override
  Widget build(BuildContext context) {
    final a = _base(_a), b = _base(_b);
    final values = <String, (double?, double?)>{
      'Energía (kcal)': (a.kcal, b.kcal),
      'Proteínas (g)': (a.protein, b.protein),
      'Carbohidratos (g)': (a.carbs, b.carbs),
      'Grasas (g)': (a.fat, b.fat),
    };
    for (final key in {
      ...?_a?.food.micronutrients.keys,
      ...?_b?.food.micronutrients.keys,
    }) {
      values[key] = (
        _ml(_a) ? null : _a?.food.micronutrients[key],
        _ml(_b) ? null : _b?.food.micronutrients[key],
      );
    }
    return NutritionTheme(
      child: Scaffold(
        appBar: AppBar(title: const Text('Comparar alimentos')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Compará bases explícitas y revisá la fuente. Los datos ausentes se muestran como —; no se completan con cero.',
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('A · ${_a?.food.name ?? 'Primer alimento'}'),
              subtitle: Text(
                '${_basis(_a)}${_a == null ? '' : ' · ${_a!.food.source}'}',
              ),
              trailing: IconButton(
                tooltip: 'Elegir primer alimento',
                onPressed: () => _pick(true),
                icon: const Icon(Icons.search),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('B · ${_b?.food.name ?? 'Segundo alimento'}'),
              subtitle: Text(
                '${_basis(_b)}${_b == null ? '' : ' · ${_b!.food.source}'}',
              ),
              trailing: IconButton(
                tooltip: 'Elegir segundo alimento',
                onPressed: () => _pick(false),
                icon: const Icon(Icons.search),
              ),
            ),
            if (_a != null && _b != null && _ml(_a) != _ml(_b))
              const Text(
                'Las bases son distintas: 100 g y 100 ml. No se convierten entre sí sin una densidad declarada.',
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: [
                  const DataColumn(label: Text('Nutriente')),
                  DataColumn(label: Text('A · ${_basis(_a)}')),
                  DataColumn(label: Text('B · ${_basis(_b)}')),
                ],
                rows: [
                  for (final e in values.entries)
                    DataRow(
                      cells: [
                        DataCell(Text(e.key.replaceAll('_', ' '))),
                        DataCell(Text(MacroValues.display(e.value.$1))),
                        DataCell(Text(MacroValues.display(e.value.$2))),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
