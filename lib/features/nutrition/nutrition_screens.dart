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
  final TextEditingController _caloriesController =
      TextEditingController(text: '500');
  final TextEditingController _templateEditorController =
      TextEditingController();
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
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plantillas editables', style: textTheme.titleMedium),
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
                decoration: const InputDecoration(
                  labelText: 'Agregar nueva plantilla',
                  prefixIcon: Icon(Icons.add_rounded),
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Lite')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NutritionHeader(
                icon: Icons.local_dining_rounded,
                title: 'Registro express',
                description: 'Comidas rápidas en menos de 1 minuto, con estilo limpio.',
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Datos esenciales', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Título de la comida',
                          prefixIcon: Icon(Icons.restaurant_menu_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Calorías estimadas',
                          prefixIcon: Icon(Icons.local_fire_department_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plantillas rápidas', style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Usa chips para seleccionar o mantén presionado para editar.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      TemplateSelector(
                        templates: _templates,
                        onSelected: _applyTemplate,
                      ),
                      const SizedBox(height: 12),
                      _buildEditableTemplates(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _saveQuickMeal(context),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Guardar en menos de 1 minuto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQuickMeal(BuildContext context) async {
    final entry = MealEntry(
      id: DateTime.now().toIso8601String(),
      title: _titleController.text,
      calories: int.tryParse(_caloriesController.text) ?? 0,
      macros: Macros(carbs: 0, protein: 0, fat: 0),
    );

    final repository = RepositoryScope.of(context);
    await repository.saveMeal(entry, sync: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Guardado: ${entry.title}')),
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
  final TextEditingController _templateNameController = TextEditingController();
  final FoodRepository _foodRepository = FoodRepository();
  final List<MealEntry> _loggedMeals = [];
  final FocusNode _foodSearchFocus = FocusNode();

  List<FoodItem> _catalog = [];
  FoodItem? _selectedFood;
  int _portionSize = 100;
  String? _activeTemplateName;
  final Map<String, List<_MealFoodSelection>> _mealTemplates = {
    'Batch cooking': [],
    'Post-entreno': [],
    'Cena completa': [],
  };
  final List<_MealFoodSelection> _currentFoods = [];
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
    _templateNameController.dispose();
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
    if (_mealTemplates.containsKey(template)) {
      _loadTemplate(template);
      return;
    }

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

  void _addFoodToMeal() {
    if (_selectedFood == null) return;
    final food = _selectedFood!;
    final macros = food.macrosForPortion(_portionSize);
    final calories = food.caloriesForPortion(_portionSize);

    setState(() {
      _currentFoods.add(
        _MealFoodSelection(
          item: food,
          grams: _portionSize,
          macros: macros,
          calories: calories,
        ),
      );
      _templateNameController.text = _templateNameController.text.isEmpty
          ? _titleController.text
          : _templateNameController.text;
    });

    _syncTotalsWithFoods();
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

  void _updateFoodPortion(int index, int grams) {
    if (index < 0 || index >= _currentFoods.length) return;
    final selection = _currentFoods[index];
    final macros = selection.item.macrosForPortion(grams);
    final calories = selection.item.caloriesForPortion(grams);

    setState(() {
      _currentFoods[index] = selection.copyWith(
        grams: grams,
        macros: macros,
        calories: calories,
      );
    });

    _syncTotalsWithFoods();
  }

  void _removeFood(int index) {
    if (index < 0 || index >= _currentFoods.length) return;
    setState(() {
      _currentFoods.removeAt(index);
    });
    _syncTotalsWithFoods();
  }

  void _syncTotalsWithFoods() {
    if (_currentFoods.isEmpty) {
      setState(() {
        _caloriesController.clear();
        _carbsController.clear();
        _proteinController.clear();
        _fatController.clear();
      });
      return;
    }
    final totals = _calculateCurrentTotals();
    setState(() {
      _caloriesController.text = totals.$2.toString();
      _carbsController.text = totals.$1.carbs.toString();
      _proteinController.text = totals.$1.protein.toString();
      _fatController.text = totals.$1.fat.toString();
    });
  }

  (Macros, int) _calculateCurrentTotals() {
    var calories = 0;
    var carbs = 0;
    var protein = 0;
    var fat = 0;

    for (final food in _currentFoods) {
      calories += food.calories;
      carbs += food.macros.carbs;
      protein += food.macros.protein;
      fat += food.macros.fat;
    }

    return (Macros(carbs: carbs, protein: protein, fat: fat), calories);
  }

  void _saveTemplate({String? name}) {
    final templateName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : _templateNameController.text.trim().isNotEmpty
            ? _templateNameController.text.trim()
            : _titleController.text.trim();

    if (templateName.isEmpty || _currentFoods.isEmpty) return;

    setState(() {
      _mealTemplates[templateName] = _currentFoods
          .map(
            (e) => _MealFoodSelection(
              item: e.item,
              grams: e.grams,
              macros: e.macros,
              calories: e.calories,
            ),
          )
          .toList();
      _activeTemplateName = templateName;
    });
  }

  void _loadTemplate(String name) {
    final items = _mealTemplates[name];
    if (items == null) return;

    setState(() {
      _currentFoods
        ..clear()
        ..addAll(
          items
              .map(
                (e) => _MealFoodSelection(
                  item: e.item,
                  grams: e.grams,
                  macros: e.macros,
                  calories: e.calories,
                ),
              )
              .toList(),
        );
      _titleController.text = name;
      _templateNameController.text = name;
      _activeTemplateName = name;
    });

    _syncTotalsWithFoods();
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
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macros diarios', style: textTheme.titleMedium),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NutritionHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Modo profesional',
              description:
                  'Control completo para atletas: porciones, macros y notas.',
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buscar alimento', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
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
                              height: 220,
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
                          decoration: const InputDecoration(
                            labelText: 'Buscar alimento o receta',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                    ),
                    if (_selectedFood != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Por 100g: ${_selectedFood!.caloriesPer100g} kcal · '
                        '${_selectedFood!.macros.carbs}C/${_selectedFood!.macros.protein}P/${_selectedFood!.macros.fat}G',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Macros y calorías', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calorías totales',
                        prefixIcon: Icon(Icons.local_fire_department_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _carbsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Carbs (g)',
                              prefixIcon: Icon(Icons.grain_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _proteinController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Proteína (g)',
                              prefixIcon: Icon(Icons.egg_alt_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _fatController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grasa (g)',
                              prefixIcon: Icon(Icons.opacity_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _selectedFood == null ? null : _addFoodToMeal,
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('Agregar a la comida'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_currentFoods.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alimentos en la comida', style: textTheme.titleMedium),
                      const SizedBox(height: 12),
                      ...[for (int i = 0; i < _currentFoods.length; i++) i]
                          .map(
                        (index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_currentFoods[index].item.name),
                            subtitle: Text(
                              '${_currentFoods[index].grams} g · '
                              '${_currentFoods[index].calories} kcal · '
                              '${_currentFoods[index].macros.carbs}C/'
                              '${_currentFoods[index].macros.protein}P/'
                              '${_currentFoods[index].macros.fat}G',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _updateFoodPortion(
                                    index,
                                    (_currentFoods[index].grams - 25).clamp(25, 500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => _updateFoodPortion(
                                    index,
                                    (_currentFoods[index].grams + 25).clamp(25, 1000),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded),
                                  onPressed: () => _removeFood(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notas y plantillas', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Añade contexto de preparación, timing o sensaciones.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas de preparación',
                        prefixIcon: Icon(Icons.note_alt_rounded),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _templateNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de plantilla (opcional)',
                        prefixIcon: Icon(Icons.bookmark_add_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _currentFoods.isEmpty ? null : () => _saveTemplate(),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar como plantilla'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _activeTemplateName == null || _currentFoods.isEmpty
                              ? null
                              : () => _saveTemplate(name: _activeTemplateName),
                          icon: const Icon(Icons.update_rounded),
                          label: const Text('Actualizar plantilla'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TemplateSelector(
                      title: 'Plantillas detalladas',
                      templates: _mealTemplates.keys.toList(),
                      onSelected: _applyTemplate,
                      onDeleted: (template) {
                        setState(() {
                          _mealTemplates.remove(template);
                          if (_activeTemplateName == template) {
                            _activeTemplateName = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDailySummary(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final totals = _currentFoods.isEmpty ? null : _calculateCurrentTotals();
                final entry = MealEntry(
                  id: DateTime.now().toIso8601String(),
                  title: _titleController.text.isNotEmpty
                      ? _titleController.text
                      : 'Comida profesional',
                  calories:
                      totals?.$2 ?? int.tryParse(_caloriesController.text) ?? 0,
                  macros: totals?.$1 ??
                      Macros(
                        carbs: int.tryParse(_carbsController.text) ?? 0,
                        protein: int.tryParse(_proteinController.text) ?? 0,
                        fat: int.tryParse(_fatController.text) ?? 0,
                      ),
                  notes: _notesController.text,
                  template: _activeTemplateName ?? _titleController.text,
                );
                setState(() => _loggedMeals.add(entry));
                _recalculateDailyTotals();

                final repository = RepositoryScope.of(context);
                await repository.saveMeal(entry, sync: true);
                await _exportDailyMetrics(context);

                if (!mounted) return;
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

class _MealFoodSelection {
  _MealFoodSelection({
    required this.item,
    required this.grams,
    required this.macros,
    required this.calories,
  });

  final FoodItem item;
  final int grams;
  final Macros macros;
  final int calories;

  _MealFoodSelection copyWith({
    FoodItem? item,
    int? grams,
    Macros? macros,
    int? calories,
  }) {
    return _MealFoodSelection(
      item: item ?? this.item,
      grams: grams ?? this.grams,
      macros: macros ?? this.macros,
      calories: calories ?? this.calories,
    );
  }
}

class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(description, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
