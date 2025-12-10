import 'package:flutter/material.dart';
import '../../core/domain/entities.dart';
import '../../main.dart';
import '../../shared/template_selector.dart';
import 'data/food_repository.dart';

class NutritionLiteScreen extends StatefulWidget {
  const NutritionLiteScreen({super.key});

  @override
  State<NutritionLiteScreen> createState() => _NutritionLiteScreenState();
}

class _NutritionLiteScreenState extends State<NutritionLiteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController(text: '500');
  final TextEditingController _templateEditorController = TextEditingController();
  final List<String> _templates = ['Desayuno rápido', 'Snack proteico', 'Smoothie verde'];

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _templateEditorController.dispose();
    super.dispose();
  }

  void _applyTemplate(String template) {
    setState(() {
      _titleController.text = template;
    });
  }

  void _addTemplate() {
    final value = _templateEditorController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _templates.add(value);
      _templateEditorController.clear();
    });
  }

  void _editTemplate(int index) async {
    final current = _templates[index];
    final controller = TextEditingController(text: current);
    final newValue = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar plantilla'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (newValue != null && newValue.isNotEmpty) {
      setState(() {
        _templates[index] = newValue;
      });
    }
  }

  Widget _buildEditableTemplates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plantillas editables', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (int i = 0; i < _templates.length; i++)
              GestureDetector(
                onLongPress: () => _editTemplate(i),
                child: InputChip(
                  label: Text(_templates[i]),
                  onPressed: () => _applyTemplate(_templates[i]),
                  onDeleted: () => setState(() => _templates.removeAt(i)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _templateEditorController,
                decoration: const InputDecoration(labelText: 'Agregar nueva plantilla'),
                onSubmitted: (_) => _addTemplate(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addTemplate,
              child: const Text('Añadir'),
            ),
          ],
        ),
      ],
    );
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
            const SizedBox(height: 12),
            _buildEditableTemplates(),
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
  final FoodRepository _foodRepository = FoodRepository();
  final List<String> _templates = const ['Batch cooking', 'Post-entreno', 'Cena completa'];
  final List<MealEntry> _loggedMeals = [];
  final FocusNode _foodSearchFocus = FocusNode();

  List<FoodItem> _catalog = [];
  FoodItem? _selectedFood;
  int _portionSize = 100;
  Macros _dailyMacros = Macros(carbs: 0, protein: 0, fat: 0);
  int _dailyCalories = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    _foodSearchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final items = await _foodRepository.syncWithPublicCatalog();
    if (mounted) {
      setState(() {
        _catalog = items;
      });
    }
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

  void _onFoodSelected(FoodItem food) {
    _selectedFood = food;
    _updatePortion(grams: _portionSize, food: food);
  }

  void _updatePortion({required int grams, FoodItem? food}) {
    final base = food ?? _selectedFood;
    if (base == null) return;

    final macros = base.macrosForPortion(grams);
    final calories = base.caloriesForPortion(grams);

    setState(() {
      _selectedFood = base;
      _portionSize = grams;
      _titleController.text = base.name;
      _caloriesController.text = calories.toString();
      _carbsController.text = macros.carbs.toString();
      _proteinController.text = macros.protein.toString();
      _fatController.text = macros.fat.toString();
    });
  }

  void _recalculateDailyTotals() {
    var carbs = 0;
    var protein = 0;
    var fat = 0;
    var calories = 0;
    for (final meal in _loggedMeals) {
      carbs += meal.macros.carbs;
      protein += meal.macros.protein;
      fat += meal.macros.fat;
      calories += meal.calories;
    }

    setState(() {
      _dailyMacros = Macros(carbs: carbs, protein: protein, fat: fat);
      _dailyCalories = calories;
    });
  }

  Future<void> _exportDailyMetrics(BuildContext context) async {
    final repository = RepositoryScope.of(context);
    await repository.exportNutritionStats(
      date: DateUtils.dateOnly(DateTime.now()),
      totalCalories: _dailyCalories,
      macros: _dailyMacros,
    );
  }

  Widget _buildDailySummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macros diarios', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Calorías: $_dailyCalories kcal'),
            Text('Carbohidratos: ${_dailyMacros.carbs} g'),
            Text('Proteína: ${_dailyMacros.protein} g'),
            Text('Grasas: ${_dailyMacros.fat} g'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RawAutocomplete<FoodItem>(
              textEditingController: _titleController,
              focusNode: _foodSearchFocus,
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return _catalog;
                final query = textEditingValue.text.toLowerCase();
                return _catalog.where(
                  (item) => item.name.toLowerCase().contains(query),
                );
              },
              displayStringForOption: (option) => option.name,
              onSelected: _onFoodSelected,
              optionsViewBuilder: (
                context,
                onSelected,
                options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: SizedBox(
                      height: 200,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option.name),
                            subtitle: Text(
                              '${option.caloriesPer100g} kcal · '
                              '${option.macros.carbs}C/${option.macros.protein}P/${option.macros.fat}G',
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (
                context,
                controller,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Buscar alimento'),
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
            ),
            const SizedBox(height: 12),
            if (_selectedFood != null)
              Text('Por 100g: ${_selectedFood!.caloriesPer100g} kcal, '
                  '${_selectedFood!.macros.carbs}C/${_selectedFood!.macros.protein}P/${_selectedFood!.macros.fat}G'),
            DropdownButtonFormField<int>(
              value: _portionSize,
              decoration: const InputDecoration(labelText: 'Porción (gramos)'),
              items: const [
                DropdownMenuItem(value: 50, child: Text('50 g')),
                DropdownMenuItem(value: 100, child: Text('100 g')),
                DropdownMenuItem(value: 150, child: Text('150 g')),
                DropdownMenuItem(value: 200, child: Text('200 g')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _updatePortion(grams: value);
                }
              },
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
            const SizedBox(height: 12),
            _buildDailySummary(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
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
                setState(() => _loggedMeals.add(entry));
                _recalculateDailyTotals();

                final repository = RepositoryScope.of(context);
                await repository.saveMeal(entry, sync: true);
                await _exportDailyMetrics(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Plantilla avanzada creada: ${entry.title} (${_portionSize}g)',
                    ),
                  ),
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
