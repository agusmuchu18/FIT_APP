import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
import '../../shared/template_selector.dart';

class NutritionLiteScreen extends StatefulWidget {
  const NutritionLiteScreen({super.key});

  @override
  State<NutritionLiteScreen> createState() => _NutritionLiteScreenState();
}

class _NutritionLiteScreenState extends State<NutritionLiteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController(text: '500');
  final List<String> _templates = const ['Desayuno rápido', 'Snack proteico', 'Smoothie verde'];

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _titleController.text = template;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Lite')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título de la comida'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calorías'),
            ),
            const SizedBox(height: 12),
            TemplateSelector(
              templates: _templates,
              onSelected: _applyTemplate,
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                final entry = MealEntry(
                  id: DateTime.now().toIso8601String(),
                  title: _titleController.text,
                  calories: int.tryParse(_caloriesController.text) ?? 0,
                  macros: Macros(carbs: 0, protein: 0, fat: 0),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Guardado: ${entry.title}')),
                );
              },
              child: const Text('Guardar rápido'),
            ),
          ],
        ),
      ),
    );
  }
}

class NutritionProScreen extends StatefulWidget {
  const NutritionProScreen({super.key});

  @override
  State<NutritionProScreen> createState() => _NutritionProScreenState();
}

class _NutritionProScreenState extends State<NutritionProScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final List<String> _templates = const ['Batch cooking', 'Post-entreno', 'Cena completa'];

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _titleController.text = template;
      _caloriesController.text = '750';
      _carbsController.text = '60';
      _proteinController.text = '45';
      _fatController.text = '25';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título de la comida'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calorías totales'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Carbs (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Proteína (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Grasa (g)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notas de preparación'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TemplateSelector(
              title: 'Plantillas detalladas',
              templates: _templates,
              onSelected: _applyTemplate,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                final entry = MealEntry(
                  id: DateTime.now().toIso8601String(),
                  title: _titleController.text,
                  calories: int.tryParse(_caloriesController.text) ?? 0,
                  macros: Macros(
                    carbs: int.tryParse(_carbsController.text) ?? 0,
                    protein: int.tryParse(_proteinController.text) ?? 0,
                    fat: int.tryParse(_fatController.text) ?? 0,
                  ),
                  notes: _notesController.text,
                  template: _titleController.text,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Plantilla avanzada creada: ${entry.title}')),
                );
              },
              icon: const Icon(Icons.save_alt),
              label: const Text('Guardar plantilla'),
            ),
          ],
        ),
      ),
    );
  }
}
