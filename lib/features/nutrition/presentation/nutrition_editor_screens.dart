import 'widgets/nutrition_theme.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/nutrition_day_repository.dart';
import '../data/templates_repository.dart';
import '../domain/models.dart';
import 'food_log_screen.dart';
import 'widgets/food_result_card.dart';

class NutritionRecipeEditor extends StatefulWidget {
  const NutritionRecipeEditor({super.key, this.template, this.onSaveMeal});
  final MealTemplate? template;
  final Future<void> Function(String, List<DraftEntry>)? onSaveMeal;
  @override
  State<NutritionRecipeEditor> createState() => _NutritionRecipeEditorState();
}

class _NutritionRecipeEditorState extends State<NutritionRecipeEditor> {
  final _name = TextEditingController(),
      _servings = TextEditingController(),
      _weight = TextEditingController(),
      _instructions = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<DraftEntry> _entries = [];
  String? _expanded;
  MealType? _mealType;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name.text = t?.name ?? '';
    _servings.text = '${t?.servings ?? 1}';
    _weight.text = t?.cookedWeightGrams?.toString() ?? '';
    _instructions.text = t?.instructions ?? '';
    _entries = List.of(t?.entries ?? []);
    _mealType = t?.mealType;
  }

  @override
  void dispose() {
    for (final c in [_name, _servings, _weight, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _number(String? v) => double.tryParse((v ?? '').replaceAll(',', '.'));
  String? _positive(String? v) {
    final n = _number(v);
    return n == null || !n.isFinite || n <= 0
        ? 'Ingresá un número positivo'
        : null;
  }

  Future<void> _pick() async {
    final selected = await Navigator.push<List<DraftEntry>>(
      context,
      MaterialPageRoute(builder: (_) => const FoodLogScreen(selectOnly: true)),
    );
    if (selected != null && mounted) {
      setState(() {
        for (final e in selected) {
          final i = _entries.indexWhere((x) => x.food.id == e.food.id);
          if (i < 0) {
            _entries.add(e);
          } else {
            _entries[i] = e;
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate() || _entries.isEmpty) return;
    setState(() => _saving = true);
    try {
      final totals = _entries.fold(
        MacroValues.zero,
        (s, e) => s + e.computedMacros,
      );
      final original = widget.template;
      final t = MealTemplate(
        id: original?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        entries: List.of(_entries),
        totals: totals,
        createdAt: original?.createdAt ?? DateTime.now(),
        isFavorite: original?.isFavorite ?? false,
        folderId: original?.folderId,
        mealType: _mealType,
        servings: _number(_servings.text)!,
        cookedWeightGrams: _weight.text.trim().isEmpty
            ? null
            : _number(_weight.text),
        instructions: _instructions.text.trim(),
      );
      if (widget.onSaveMeal != null) {
        await widget.onSaveMeal!(t.name, t.entries);
      } else {
        await TemplatesRepository().add(t);
      }
      if (mounted) Navigator.pop(context, t);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Tus ingredientes siguen aquí.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => NutritionTheme(
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.onSaveMeal != null
              ? 'Editar comida'
              : widget.template == null
              ? 'Crear receta'
              : 'Editar receta',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Ingresá un nombre'
                      : null,
                ),
                const SizedBox(height: 16),
                if (widget.onSaveMeal == null)
                  DropdownButtonFormField<MealType?>(
                    initialValue: _mealType,
                    decoration: const InputDecoration(
                      labelText: 'Comida habitual (opcional)',
                    ),
                    items: [
                      const DropdownMenuItem<MealType?>(
                        value: null,
                        child: Text('Elegir al registrar'),
                      ),
                      for (final type in MealType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(mealTypeLabel(type)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _mealType = v),
                  ),
                if (widget.onSaveMeal == null)
                  TextFormField(
                    controller: _servings,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Raciones de la receta completa',
                    ),
                    validator: _positive,
                  ),
                const SizedBox(height: 16),
                if (widget.onSaveMeal == null)
                  TextFormField(
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Peso final preparado (g, opcional)',
                      helperText:
                          'Medilo si querés conocer los nutrientes por 100 g.',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? null : _positive(v),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Los nutrientes se suman desde los ingredientes. No se aplica un factor de cocción inventado.',
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ingredientes (${_entries.length})'),
                  trailing: TextButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                ),
                for (final e in _entries)
                  Column(
                    children: [
                      FoodResultCard(
                        food: e.food,
                        expanded: _expanded == e.food.id,
                        draftEntry: e,
                        loading: false,
                        onTap: () => setState(
                          () => _expanded = _expanded == e.food.id
                              ? null
                              : e.food.id,
                        ),
                        onSave: (next) => setState(
                          () => _entries[_entries.indexOf(e)] = next,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _entries.remove(e)),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Quitar ingrediente'),
                        ),
                      ),
                    ],
                  ),
                TextFormField(
                  controller: _instructions,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Preparación y notas (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving || _entries.isEmpty ? null : _save,
                  child: Text(
                    _saving
                        ? 'Guardando…'
                        : widget.onSaveMeal != null
                        ? 'Guardar comida'
                        : 'Guardar receta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class NutritionGoalEditor extends StatefulWidget {
  const NutritionGoalEditor({
    super.key,
    required this.repository,
    required this.date,
    required this.goal,
  });
  final NutritionDayRepository repository;
  final DateTime date;
  final NutritionGoal goal;
  @override
  State<NutritionGoalEditor> createState() => _NutritionGoalEditorState();
}

class _NutritionGoalEditorState extends State<NutritionGoalEditor> {
  final _form = GlobalKey<FormState>();
  late DateTime _effective;
  late final List<TextEditingController> _fields;
  bool _saving = false;
  late final _history = widget.repository.goalHistory();
  @override
  void initState() {
    super.initState();
    _effective = widget.date;
    _fields = [
      widget.goal.kcal,
      widget.goal.protein,
      widget.goal.carbs,
      widget.goal.fat,
    ].map((v) => TextEditingController(text: v?.toString() ?? '')).toList();
  }

  @override
  void dispose() {
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  double? _parse(String v) =>
      v.trim().isEmpty ? null : double.tryParse(v.replaceAll(',', '.'));
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveGoal(
        _effective,
        MacroValues(
          kcal: _parse(_fields[0].text),
          protein: _parse(_fields[1].text),
          carbs: _parse(_fields[2].text),
          fat: _parse(_fields[3].text),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la meta.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => NutritionTheme(
    child: Scaffold(
      appBar: AppBar(title: const Text('Objetivos nutricionales')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Definí tus metas manualmente. Dejá vacío lo que no quieras configurar. Los cambios tienen fecha y no reescriben tus comidas.',
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Vigente desde'),
              subtitle: Text(DateFormat.yMd('es').format(_effective)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _effective,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 366)),
                );
                if (d != null && mounted) setState(() => _effective = d);
              },
            ),
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  controller: _fields[i],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: const [
                      'Energía (kcal)',
                      'Proteínas (g)',
                      'Carbohidratos (g)',
                      'Grasas (g)',
                    ][i],
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = _parse(v);
                    return n == null ||
                            !n.isFinite ||
                            n < 0 ||
                            (i == 0 && n == 0)
                        ? 'Ingresá un valor válido'
                        : null;
                  },
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Guardar objetivos'),
            ),
            const SizedBox(height: 24),
            Text(
              'Historial de objetivos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _history,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('No se pudo abrir el historial.');
                }
                if (!snapshot.hasData) return const LinearProgressIndicator();
                if (snapshot.data!.isEmpty) {
                  return const Text('Todavía no hay objetivos fechados.');
                }
                return Column(
                  children: [
                    for (final row in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${row.containsKey('revisionId') ? 'Revisión anterior' : 'Desde'} ${DateFormat.yMd('es').format(DateTime.parse(row['date'] as String))}',
                        ),
                        subtitle: Text(
                          '${MacroValues.display(MacroValues.fromJson(Map<String, dynamic>.from(row['values'] as Map)).kcal, decimals: 0)} kcal',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
