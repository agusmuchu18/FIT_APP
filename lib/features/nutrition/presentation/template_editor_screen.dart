import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/templates_repository.dart';
import '../domain/models.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _nameController = TextEditingController();
  final _itemController = TextEditingController();
  final _items = <TemplateItem>[];
  MealType? _mealType;
  final _repo = TemplatesRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear plantilla')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre')),
          const SizedBox(height: 12),
          DropdownButtonFormField<MealType?>(
            value: _mealType,
            decoration: const InputDecoration(labelText: 'Tipo de comida (opcional)'),
            items: [
              const DropdownMenuItem<MealType?>(value: null, child: Text('Sin tipo fijo')),
              ...MealType.values.map((type) => DropdownMenuItem<MealType?>(value: type, child: Text(mealTypeLabel(type)))),
            ],
            onChanged: (value) => setState(() => _mealType = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _itemController, decoration: const InputDecoration(labelText: 'Alimento'))),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  final text = _itemController.text.trim();
                  if (text.isEmpty) return;
                  setState(() => _items.add(TemplateItem(name: text)));
                  _itemController.clear();
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._items.map((item) => ListTile(title: Text(item.name))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              final name = _nameController.text.trim();
              if (name.isEmpty) return;
              final template = MealTemplate(
                id: const Uuid().v4(),
                name: name,
                mealType: _mealType,
                items: List.unmodifiable(_items),
                // TODO: si hay cálculo por item detallado, completar macros agregadas de forma exacta.
                totals: const MacroValues(kcal: 0, protein: 0, carbs: 0, fat: 0),
                createdAt: DateTime.now(),
              );
              await _repo.add(template);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Guardar plantilla'),
          ),
        ],
      ),
    );
  }
}
