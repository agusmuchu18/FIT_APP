import 'package:flutter/material.dart';

import '../data/food_repository.dart';
import '../domain/models.dart';
import 'widgets/food_result_card.dart';
import 'widgets/nutrition_theme.dart';

/// Manual barcode entry is available without camera permissions. Remote
/// results are accepted only when their GTIN matches exactly.
class NutritionBarcodeScreen extends StatefulWidget {
  const NutritionBarcodeScreen({
    super.key,
    required this.repository,
    required this.onApply,
    required this.onCreate,
  });
  final FoodRepository repository;
  final ValueChanged<DraftEntry> onApply;
  final ValueChanged<String> onCreate;
  @override
  State<NutritionBarcodeScreen> createState() => _NutritionBarcodeScreenState();
}

class _NutritionBarcodeScreenState extends State<NutritionBarcodeScreen> {
  final _code = TextEditingController();
  FoodItem? _food;
  String? _message;
  bool _loading = false, _notFound = false;
  int _generation = 0;
  @override
  void dispose() {
    _generation++;
    _code.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _food = null;
      _message = null;
      _notFound = false;
    });
    try {
      normalizeNutritionBarcode(_code.text);
      final found = await widget.repository.findByBarcode(_code.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _food = found;
        _notFound = found == null;
        _message = found == null
            ? (widget.repository.hasRemoteSource
                  ? 'No se encontró una coincidencia exacta. Podés buscar por nombre o crear el producto.'
                  : 'No está en tu catálogo local. La consulta remota no está configurada; podés crear el producto con su etiqueta.')
            : null;
      });
    } on FormatException catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _message = e.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _message = 'No se pudo consultar el catálogo. El código se conserva para reintentar.',
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => NutritionTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Buscar por código')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ingresá el código de la etiqueta. Revisá el producto y la cantidad antes de agregarlo al borrador.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 14,
            decoration: const InputDecoration(
              labelText: 'Código GTIN / EAN / UPC',
            ),
            onChanged: (_) {
              _generation++;
              setState(() {
                _food = null;
                _message = null;
                _loading = false;
                _notFound = false;
              });
            },
            onSubmitted: (_) => _search(),
          ),
          FilledButton(
            onPressed: _loading ? null : _search,
            child: Text(_loading ? 'Buscando…' : 'Buscar producto'),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_message!),
            ),
          if (_notFound)
            OutlinedButton.icon(
              onPressed: () {
                final code = _code.text;
                Navigator.pop(context);
                widget.onCreate(code);
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear desde la etiqueta'),
            ),
          if (_food != null)
            FoodResultCard(
              food: _food!,
              expanded: true,
              draftEntry: null,
              loading: false,
              onTap: () {},
              onSave: (e) {
                widget.onApply(e);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'La entrada de código es manual. El escaneo con cámara se habilitará cuando esté integrado y validado en dispositivos compatibles.',
          ),
        ],
      ),
    ),
  );
}
