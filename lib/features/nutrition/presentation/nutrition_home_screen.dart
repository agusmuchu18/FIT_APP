import '../data/nutrition_backup_service.dart';
import '../data/food_repository.dart';
import '../data/fdc_client.dart';
import 'widgets/nutrition_theme.dart';
import '../../analytics/analytics_overview_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../main.dart';
import '../../common/theme/app_colors.dart';
import '../../common/theme/app_layout.dart';
import '../data/nutrition_day_repository.dart';
import '../data/templates_repository.dart';
import '../domain/models.dart';
import 'food_log_screen.dart';
import 'nutrition_editor_screens.dart';
import 'nutrition_fasting_screen.dart';
import 'nutrition_compare_screen.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({super.key});
  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  late final _days = NutritionDayRepository(
    fitness: context
        .getInheritedWidgetOfExactType<RepositoryScope>()
        ?.repository,
  );
  final _recipes = TemplatesRepository();
  late final _backupFoods = FoodRepository(
    fdc: FdcClient(apiKey: ''),
    scope: _days.scope,
  );
  late final _backup = NutritionBackupService(
    days: _days,
    foods: _backupFoods,
    templates: _recipes,
  );
  DateTime _date = DateTime.now();
  NutritionDaySummary? _summary;
  List<LoggedMeal> _meals = [];
  List<MealTemplate> _templates = [];
  List<TemplateFolder> _folders = [];
  List<PlannedNutritionMeal> _plans = [];
  List<RecentNutritionItem> _recents = [];
  Map<String, dynamic> _note = {};
  String? _error;
  String _folder = 'all';
  bool _loading = true, _busy = false, _pro = false;
  int _generation = 0;
  @override
  void dispose() {
    _generation++;
    _backupFoods.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final values = await Future.wait<Object>([
        _days.getSummary(_date),
        _days.listMeals(),
        _recipes.getTemplates(),
        _days.plans(),
        _days.getRecents(),
        _days.professionalMode(),
        _days.dailyNote(_date),
        _recipes.getFolders(),
      ]);
      if (!mounted || generation != _generation) return;
      setState(() {
        _summary = values[0] as NutritionDaySummary;
        _meals = values[1] as List<LoggedMeal>;
        _templates = values[2] as List<MealTemplate>;
        _plans = values[3] as List<PlannedNutritionMeal>;
        _recents = values[4] as List<RecentNutritionItem>;
        _pro = values[5] as bool;
        _note = values[6] as Map<String, dynamic>;
        _folders = values[7] as List<TemplateFolder>;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _error = 'No se pudieron abrir tus comidas. Los datos originales se conservan.';
          _loading = false;
        });
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  String _number(double? v, {int decimals = 1}) =>
      MacroValues.display(v, decimals: decimals);
  Future<void> _act(Future<void> Function() action) async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (_) {
      if (mounted) {
        _message(
          'No se pudo completar. Tus datos se conservan; podés reintentar.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _register([MealType? type]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodLogScreen(initialMealType: type, date: _date),
      ),
    );
    await _load();
  }

  DateTime _firstDate([DateTime? initial]) {
    final candidate = initial ?? _date;
    return candidate.isBefore(DateTime(2000)) ? candidate : DateTime(2000);
  }

  DateTime _lastDate() {
    final latest = DateTime.now().add(const Duration(days: 366));
    return _date.isAfter(latest) ? _date : latest;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _firstDate(),
      lastDate: _lastDate(),
    );
    if (d != null && mounted) {
      setState(() => _date = d);
      await _load();
    }
  }

  Future<String?> _text(
    String title, {
    String value = '',
    String label = 'Nombre',
    bool multiline = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _NutritionTextDialog(
        title: title,
        value: value,
        label: label,
        multiline: multiline,
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) {
    return NutritionTheme(
      child: DefaultTabController(
        length: 4,
        animationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppVisual.motionNormal,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Alimentación'),
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Diario'),
                Tab(text: 'Recetas'),
                Tab(text: 'Plan'),
                Tab(text: 'Más'),
              ],
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _loading || _summary == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Cargando alimentación',
                        ),
                      )
                    : Column(
                        children: [
                          if (_busy)
                            const LinearProgressIndicator(
                              semanticsLabel: 'Guardando',
                            ),
                          _dateNavigation(),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _diary(),
                                _library(),
                                Builder(builder: (ctx) => _planner(ctx)),
                                _more(),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateNavigation() => Row(
    children: [
      IconButton(
        tooltip: 'Día anterior',
        onPressed: () {
          setState(
            () => _date = DateTime(_date.year, _date.month, _date.day - 1),
          );
          _load();
        },
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: TextButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(
            _sameDay(_date, DateTime.now())
                ? 'Hoy · ${DateFormat('d MMM', 'es').format(_date)}'
                : DateFormat.yMMMd('es').format(_date),
          ),
        ),
      ),
      IconButton(
        tooltip: 'Día siguiente',
        onPressed: () {
          setState(
            () => _date = DateTime(_date.year, _date.month, _date.day + 1),
          );
          _load();
        },
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _diary() {
    final s = _summary!;
    final dayMeals = _meals.where((m) => _sameDay(m.date, _date)).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          NutritionHeroCard(
            summary: s,
            dateText: DateFormat.yMMMd('es').format(_date),
          ),
          if (s.projectionPending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Guardado en este dispositivo. Inicio tiene una actualización pendiente; deslizá para reintentar.',
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _busy ? null : () => _register(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar comida'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NutritionGoalEditor(
                      repository: _days,
                      date: _date,
                      goal: s.goal,
                    ),
                  ),
                );
                await _load();
              },
              child: const Text('Configurar objetivos'),
            ),
          ),
          for (final type in MealType.values)
            _mealGroup(
              type,
              dayMeals.where((m) => m.mealType == type).toList(),
            ),
          if (dayMeals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tu día está listo para empezar. Buscá un alimento o reutilizá una comida reciente.',
              ),
            ),
          if (_recents.isNotEmpty) ...[
            Text(
              'Repetir una comida',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final recent in _recents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(recent.title),
                subtitle: Text(
                  '${mealTypeLabel(recent.mealType)} · ${_number(recent.macros?.kcal, decimals: 0)} kcal',
                ),
                trailing: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _act(
                          () => _days.duplicateRecent(recent, date: _date),
                        ),
                  child: const Text('Repetir'),
                ),
              ),
          ],
          if (_pro) ...[
            const Divider(),
            Text(
              'Detalle profesional',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Las cantidades y nutrientes se conservan con decimales. — indica un dato no disponible.',
            ),
            for (final m in dayMeals)
              for (final e in m.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.food.name),
                  subtitle: Text(
                    '${e.quantity} ${e.unit == FoodUnit.serving ? 'porción(es)' : e.unit.name} · ${e.food.source}',
                  ),
                  trailing: Text('${_number(e.computedMacros.kcal)} kcal'),
                ),
          ],
        ],
      ),
    );
  }

  Widget _mealGroup(MealType type, List<LoggedMeal> meals) {
    final totals = meals.fold(MacroValues.zero, (sum, m) => sum + m.totals);
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text(mealTypeLabel(type)),
            subtitle: Text(
              meals.isEmpty
                  ? 'Sin registros'
                  : '${_number(totals.kcal, decimals: 0)} kcal · ${meals.length} comida(s)',
            ),
            trailing: IconButton(
              tooltip: 'Agregar a ${mealTypeLabel(type)}',
              onPressed: _busy ? null : () => _register(type),
              icon: const Icon(Icons.add),
            ),
          ),
          for (final meal in meals)
            ListTile(
              title: Text(
                meal.title ??
                    (meal.entries.length == 1
                        ? meal.entries.single.food.name
                        : mealTypeLabel(type)),
              ),
              subtitle: Text(
                '${_number(meal.totals.kcal, decimals: 0)} kcal · P ${_number(meal.totals.protein)} · C ${_number(meal.totals.carbs)} · G ${_number(meal.totals.fat)}${meal.entries.isEmpty ? '' : '\n'}${meal.entries.take(2).map((e) => '${e.food.name} · ${e.quantity} ${e.unit == FoodUnit.serving ? 'porción(es)' : e.unit.name}').join('\n')}',
              ),
              onTap: () => _editMeal(meal),
              trailing: PopupMenuButton<String>(
                tooltip: 'Opciones de la comida',
                onSelected: (a) => _mealAction(meal, a),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar cantidades'),
                  ),
                  PopupMenuItem(value: 'repeat', child: Text('Repetir')),
                  PopupMenuItem(value: 'move', child: Text('Cambiar comida')),
                  PopupMenuItem(
                    value: 'recipe',
                    child: Text('Guardar como receta'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editMeal(LoggedMeal meal) async {
    if (meal.entries.isEmpty) {
      final title = await _text(
        'Renombrar registro heredado',
        value: meal.title ?? '',
      );
      if (title != null && title.isNotEmpty) {
        await _act(() => _days.editMeal(meal.id, title: title, entries: []));
      }
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionRecipeEditor(
          template: MealTemplate(
            id: meal.id,
            name: meal.title ?? mealTypeLabel(meal.mealType),
            entries: meal.entries,
            totals: meal.totals,
            createdAt: meal.date,
          ),
          onSaveMeal: (title, entries) =>
              _days.editMeal(meal.id, title: title, entries: entries),
        ),
      ),
    );
    await _load();
  }

  Future<void> _mealAction(LoggedMeal m, String action) async {
    if (action == 'edit') {
      await _editMeal(m);
      return;
    }
    if (action == 'move') {
      final type = await _chooseMealType();
      if (type != null) {
        final title =
            m.method == 'manual' && m.title == mealTypeLabel(m.mealType)
            ? mealTypeLabel(type)
            : m.title ?? mealTypeLabel(type);
        await _act(
          () => _days.editMeal(
            m.id,
            title: title,
            entries: m.entries,
            mealType: type,
          ),
        );
      }
      return;
    }
    if (action == 'repeat') {
      await _act(
        () => _days.logMeal(
          LoggedMeal(
            date: _date,
            mealType: m.mealType,
            entries: m.entries,
            snapshot: m.totals,
            title: m.title,
            sourceId: m.id,
            method: 'repeat',
          ),
        ),
      );
      return;
    }
    if (action == 'recipe') {
      if (m.entries.isEmpty) {
        _message(
          'Este registro no conserva ingredientes. Agregalos antes de crear una receta.',
        );
        return;
      }
      final name = await _text('Guardar como receta', value: m.title ?? '');
      if (name != null && name.isNotEmpty) {
        await _act(
          () => _recipes.add(
            MealTemplate(
              id: const Uuid().v4(),
              name: name,
              entries: m.entries,
              totals: m.totals,
              createdAt: DateTime.now(),
            ),
          ),
        );
      }
      return;
    }
    if (action == 'delete' &&
        await _confirm(
          'Eliminar comida',
          'Se quitará del diario y de los totales. Podés deshacerlo enseguida.',
        )) {
      await _act(() => _days.deleteMeal(m.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comida eliminada'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => _act(() => _days.restoreMeal(m.id)),
            ),
          ),
        );
      }
    }
  }

  Widget _library() {
    final shown = _templates
        .where(
          (t) =>
              _folder == 'all' ||
              (_folder == 'favorites' ? t.isFavorite : t.folderId == _folder),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _editorial(),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NutritionRecipeEditor()),
            );
            await _load();
          },
          icon: const Icon(Icons.add),
          label: const Text('Crear receta'),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          children: [
            for (final e in {
              'all': 'Todas',
              'favorites': 'Favoritos',
              for (final f in _folders) f.id: f.name,
            }.entries)
              FilterChip(
                label: Text(e.value),
                selected: _folder == e.key,
                onSelected: (_) => setState(() => _folder = e.key),
              ),
            ActionChip(
              label: const Text('Nueva carpeta'),
              onPressed: () async {
                final name = await _text('Nueva carpeta');
                if (name != null && name.isNotEmpty) {
                  await _act(
                    () => _recipes.addFolder(
                      TemplateFolder(
                        id: const Uuid().v4(),
                        name: name,
                        order: _folders.length,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (shown.isEmpty)
          const ListTile(
            title: Text('Todavía no hay recetas aquí'),
            subtitle: Text(
              'Agregá tus ingredientes habituales una sola vez y reutilizalos por ración.',
            ),
          ),
        for (final t in shown)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    t.isFavorite ? Icons.bookmark : Icons.restaurant_outlined,
                  ),
                  title: Text(t.name),
                  subtitle: Text(
                    t.entries.isEmpty
                        ? 'Plantilla heredada · ingredientes sin vincular'
                        : '${t.entries.length} ingredientes · ${t.servings} raciones\n${_number(t.effectiveTotals.kcal, decimals: 0)} kcal en total',
                  ),
                  onTap: () => _recipeAction(t, 'edit'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opciones de receta',
                    onSelected: (a) => _recipeAction(t, a),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          t.isFavorite
                              ? 'Quitar de favoritos'
                              : 'Guardar en favoritos',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'portions',
                        child: Text('Elegir raciones'),
                      ),
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                        value: 'duplicate',
                        child: Text('Duplicar'),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Renombrar'),
                      ),
                      const PopupMenuItem(
                        value: 'move',
                        child: Text('Mover a carpeta'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
                    ],
                  ),
                ),
                if (t.instructions.isNotEmpty)
                  ExpansionTile(
                    title: const Text('Preparación'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(t.instructions),
                      ),
                    ],
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: _busy || t.entries.isEmpty
                          ? null
                          : () => _useRecipe(t, false, quick: true),
                      icon: const Icon(Icons.add),
                      label: const Text('Registrar 1 ración'),
                    ),
                    TextButton.icon(
                      onPressed: _busy || t.entries.isEmpty
                          ? null
                          : () => _useRecipe(t, true),
                      icon: const Icon(Icons.event_outlined),
                      label: const Text('Planificar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _editorial() => ClipRRect(
    borderRadius: BorderRadius.circular(AppShape.card),
    child: Stack(
      children: [
        SizedBox(
          height: 128,
          width: double.infinity,
          child: Image.asset(
            'assets/images/nutrition/nutrition-editorial-v1.webp',
            fit: BoxFit.cover,
            cacheWidth: 960,
            excludeFromSemantics: true,
            errorBuilder: (_, e, s) => const SizedBox(),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.background.withValues(
              alpha: AppVisual.scrimOpacity,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Tus recetas,\na tu medida.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _recipeAction(MealTemplate t, String action) async {
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NutritionRecipeEditor(template: t)),
      );
      await _load();
      return;
    }
    if (action == 'portions') {
      await _useRecipe(t, false);
      return;
    }
    if (action == 'favorite') {
      await _act(() => _recipes.toggleFavorite(t.id));
      return;
    }
    if (action == 'duplicate') {
      await _act(
        () => _recipes.add(
          t.copyWith(
            id: const Uuid().v4(),
            name: '${t.name} (copia)',
            createdAt: DateTime.now(),
          ),
        ),
      );
      return;
    }
    if (action == 'rename') {
      final name = await _text('Renombrar receta', value: t.name);
      if (name != null && name.isNotEmpty) {
        await _act(() => _recipes.update(t.copyWith(name: name)));
      }
      return;
    }
    if (action == 'move') {
      final folder = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Sin carpeta'),
                onTap: () => Navigator.pop(ctx, 'none'),
              ),
              for (final f in _folders)
                ListTile(
                  title: Text(f.name),
                  onTap: () => Navigator.pop(ctx, f.id),
                ),
            ],
          ),
        ),
      );
      if (folder != null) {
        await _act(
          () => _recipes.moveToFolder(t.id, folder == 'none' ? null : folder),
        );
      }
      return;
    }
    if (action == 'delete' &&
        await _confirm(
          'Eliminar receta',
          'Los registros y planes anteriores conservarán su composición.',
        )) {
      await _act(() => _recipes.delete(t.id));
    }
  }

  Future<MealType?> _chooseMealType() => showModalBottomSheet<MealType>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final m in MealType.values)
            ListTile(
              title: Text(mealTypeLabel(m)),
              onTap: () => Navigator.pop(ctx, m),
            ),
        ],
      ),
    ),
  );
  Future<void> _useRecipe(
    MealTemplate t,
    bool planning, {
    bool quick = false,
  }) async {
    var targetDate = _date;
    if (planning) {
      final selected = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: _firstDate(),
        lastDate: _lastDate(),
      );
      if (selected == null || !mounted) return;
      targetDate = selected;
    }
    final countText = quick
        ? '1'
        : await _text(
            planning
                ? 'Planificar raciones'
                : 'Registrar · ${DateFormat.yMd('es').format(targetDate)}',
            value: '1',
            label: 'Cantidad de raciones',
          );
    final count = double.tryParse((countText ?? '').replaceAll(',', '.'));
    if (countText == null) return;
    if (count == null || !count.isFinite || count <= 0) {
      _message('Ingresá una cantidad positiva.');
      return;
    }
    if (!mounted) return;
    final type = t.mealType ?? await _chooseMealType();
    if (type == null) return;
    final portion = t.portion(count);
    await _act(() async {
      await (planning
          ? _days.plan(
              PlannedNutritionMeal(
                id: const Uuid().v4(),
                date: targetDate,
                mealType: type,
                template: portion,
              ),
            )
          : _days.addTemplateToToday(
              portion,
              mealType: type,
              date: targetDate,
            ));
      if (mounted) {
        _message(
          planning
              ? 'Comida planificada, sin registrar consumo.'
              : '${count.toString().replaceAll('.', ',')} ración(es) registradas en ${mealTypeLabel(type)} · ${DateFormat.yMd('es').format(targetDate)}',
        );
      }
    });
  }

  Widget _planner(BuildContext tabContext) => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      Text(
        'Planificar sin registrar',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text(
        'Elegí una receta y la fecha en Diario. Una comida planificada solo suma nutrientes cuando confirmás que la consumiste.',
      ),
      TextButton.icon(
        onPressed: () => DefaultTabController.of(tabContext).animateTo(1),
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Elegir una receta'),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final source = await showDatePicker(
            context: context,
            initialDate: _date.subtract(const Duration(days: 7)),
            firstDate: _firstDate(_date.subtract(const Duration(days: 7))),
            lastDate: _lastDate(),
          );
          if (source == null || !mounted) return;
          if (await _confirm(
            'Copiar semana',
            'Copiar 7 días desde ${DateFormat.yMd('es').format(source)} al período que empieza el ${DateFormat.yMd('es').format(_date)}. No registra consumo.',
          )) {
            await _act(() async {
              final n = await _days.copyPlanWeek(source, _date);
              if (mounted) _message('$n comidas planificadas copiadas.');
            });
          }
        },
        icon: const Icon(Icons.copy_all_outlined),
        label: const Text('Copiar semana al período seleccionado'),
      ),
      if (_plans.isEmpty)
        const ListTile(
          title: Text('Tu plan está vacío'),
          subtitle: Text(
            'Las comidas que planifiques aparecerán aquí con su fecha.',
          ),
        ),
      for (final p in _plans)
        Card(
          child: ListTile(
            title: Text(p.template.name),
            subtitle: Text(
              '${DateFormat.yMMMd('es').format(p.date)} · ${mealTypeLabel(p.mealType)}\n${p.consumed ? 'Registrada' : 'Planificada'} · ${_number(p.template.effectiveTotals.kcal, decimals: 0)} kcal',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (a) async {
                if (a == 'consume') {
                  if (await _confirm(
                    'Registrar comida planificada',
                    'Se registrará en ${DateFormat.yMd('es').format(p.date)}. ¿Confirmás que la consumiste?',
                  )) {
                    await _act(() => _days.consumePlan(p.id));
                  }
                } else if (await _confirm(
                  'Quitar del plan',
                  'Esto no borra una comida que ya hayas registrado.',
                )) {
                  await _act(() => _days.removePlan(p.id));
                }
              },
              itemBuilder: (_) => [
                if (!p.consumed)
                  const PopupMenuItem(
                    value: 'consume',
                    child: Text('Confirmar consumo'),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Quitar del plan'),
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: () async {
          try {
            final items = await _days.shoppingList();
            if (!mounted) return;
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Lista de compras'),
                content: SingleChildScrollView(
                  child: Text(
                    items.isEmpty
                        ? 'No hay ingredientes pendientes.'
                        : items.entries
                              .map((e) {
                                final fields = e.key.split('|');
                                return '${fields[1]}: ${e.value.toStringAsFixed(1)} ${fields.last}';
                              })
                              .join('\n'),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          } catch (_) {
            if (mounted) _message('No se pudo abrir la lista de compras.');
          }
        },
        icon: const Icon(Icons.shopping_basket_outlined),
        label: const Text('Lista de compras'),
      ),
    ],
  );
  Widget _more() => ListView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    children: [
      ListTile(
        leading: const Icon(Icons.compare_arrows),
        title: const Text('Comparar alimentos'),
        subtitle: const Text('Macronutrientes, micronutrientes y fuentes.'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NutritionFoodCompareScreen()),
        ),
      ),
      SwitchListTile(
        title: const Text('Modo profesional'),
        subtitle: const Text(
          'Más detalle, con el mismo diario y las mismas recetas.',
        ),
        value: _pro,
        onChanged: (v) => _act(() => _days.setProfessionalMode(v)),
      ),
      ListTile(
        leading: const Icon(Icons.track_changes),
        title: const Text('Objetivos e historial'),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NutritionGoalEditor(
                repository: _days,
                date: _date,
                goal: _summary!.goal,
              ),
            ),
          );
          await _load();
        },
      ),
      ListTile(
        leading: const Icon(Icons.insights_outlined),
        title: const Text('Estadísticas'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AnalyticsOverviewScreen(nutritionOnly: true),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.edit_note_outlined),
        title: const Text('Notas del día'),
        subtitle: Text(
          (_note['note'] as String?)?.isNotEmpty == true
              ? _note['note'] as String
              : 'Privadas. Hambre, digestión o contexto de tus comidas.',
        ),
        onTap: () async {
          final note = await _text(
            'Notas · ${DateFormat.yMd('es').format(_date)}',
            value: _note['note'] as String? ?? '',
            label: 'Nota personal',
            multiline: true,
          );
          if (note != null) {
            await _act(
              () => _days.saveDailyNote(
                _date,
                note: note,
                supplements: _note['supplements'] as String? ?? '',
              ),
            );
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Suplementos declarados'),
        subtitle: Text(_note['supplements'] as String? ?? 'Sin registro'),
        onTap: () async {
          final text = await _text(
            'Suplementos del día',
            value: _note['supplements'] as String? ?? '',
            label: 'Nombre y cantidad declarada',
            multiline: true,
          );
          if (text != null) {
            await _act(
              () => _days.saveDailyNote(
                _date,
                note: _note['note'] as String? ?? '',
                supplements: text,
              ),
            );
          }
        },
      ),
      ListTile(
        leading: const Icon(Icons.water_drop_outlined),
        title: const Text('Agua e hidratación'),
        subtitle: const Text('Usar el seguimiento existente de Hábitos.'),
        onTap: () => Navigator.pushNamed(context, '/habits'),
      ),
      ListTile(
        leading: const Icon(Icons.schedule_outlined),
        title: const Text('Registro de ayuno (opcional)'),
        subtitle: const Text(
          'Ventanas e historial, sin objetivos automáticos.',
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NutritionFastingScreen(repository: _days),
          ),
        ),
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.file_download_outlined),
        title: const Text('Exportar copia nutricional'),
        subtitle: const Text('Contiene información privada.'),
        onTap: _export,
      ),
      ListTile(
        leading: const Icon(Icons.file_upload_outlined),
        title: const Text('Importar copia nutricional'),
        subtitle: const Text(
          'Previsualizar antes de guardar. No sobrescribe IDs.',
        ),
        onTap: _import,
      ),
      ListTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Datos, fuentes y privacidad'),
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tu alimentación, tus datos'),
            content: const SingleChildScrollView(
              child: Text(
                'Las recetas y comidas se guardan por cuenta. Los datos de invitado siguen separados. USDA se identifica en cada alimento; los productos creados por vos son declarados. — significa información no disponible, no cero.\n\nLa imagen de recetas es una ilustración editorial generada para FIT APP; no representa una comida registrada. No se publican tus datos ni se descuentan calorías por ejercicio automáticamente.\n\nAgua: conservá el registro de Hidratación de Hábitos. No duplicamos su contador. La captura por cámara, reconocimiento IA y conexiones externas solo se habilitarán cuando tengan servicio y permisos verificables.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Future<void> _export() async {
    try {
      final text = await _backup.exportData();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Copia nutricional privada'),
          content: const Text(
            'Incluye comidas, recetas, alimentos propios, favoritos, metas, planes, notas y ventanas registradas. Copiala solo a un lugar de confianza. No incluye contraseñas ni credenciales.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _message('JSON copiado al portapapeles.');
              },
              child: const Text('Copiar JSON'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) _message('No se pudo exportar el diario.');
    }
  }

  Future<void> _import() async {
    final text = await _text(
      'Importar copia del diario',
      label: 'Pegá el JSON exportado',
      multiline: true,
    );
    if (text == null || text.isEmpty) return;
    try {
      final preview = await _backup.inspect(text);
      if (!mounted) return;
      if (preview.conflicts > 0) {
        _message(
          '${preview.conflicts} registros en conflicto. No se sobrescribió nada.',
        );
        return;
      }
      if (await _confirm(
        'Revisar importación',
        '${preview.added} registros nuevos y ${preview.duplicates} existentes que se omitirán. Incluye metas, planes, recetas y notas privadas. ¿Importar sin sobrescribir datos?',
      )) {
        await _act(() async {
          final count = await _backup.importData(text);
          if (mounted) _message('$count registros importados.');
        });
      }
    } catch (_) {
      if (mounted) {
        _message(
          'Formato no válido o versión no compatible. No se sobrescribieron datos.',
        );
      }
    }
  }
}

class NutritionHeroCard extends StatelessWidget {
  const NutritionHeroCard({
    super.key,
    required this.summary,
    required this.dateText,
  });
  final NutritionDaySummary summary;
  final String dateText;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), s = summary;
    final known = s.consumed.kcal;
    final goal = s.goal.kcal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen del día', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              children: [
                Text(
                  '${MacroValues.display(known, decimals: 0)} kcal',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  goal == null
                      ? 'Meta sin configurar'
                      : 'de ${MacroValues.display(goal, decimals: 0)} kcal',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (goal != null && goal > 0 && known != null)
              LinearProgressIndicator(
                value: (known / goal).clamp(0, 1),
                semanticsLabel: 'Energía registrada respecto de tu meta',
              ),
            Text(
              goal == null
                  ? 'Sin meta diaria'
                  : known == null
                  ? 'Energía incompleta'
                  : known <= goal
                  ? 'Restan ${MacroValues.display(goal - known, decimals: 0)} kcal'
                  : '${MacroValues.display(known - goal, decimals: 0)} kcal por encima de la meta',
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.md,
              children: [
                _macro(
                  context,
                  'Proteínas',
                  s.consumed.protein,
                  s.goal.protein,
                ),
                _macro(
                  context,
                  'Carbohidratos',
                  s.consumed.carbs,
                  s.goal.carbs,
                ),
                _macro(context, 'Grasas', s.consumed.fat, s.goal.fat),
              ],
            ),
            if (!s.consumed.isComplete)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('— Nutriente no disponible; no se considera cero.'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _macro(BuildContext ctx, String label, double? value, double? goal) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(ctx).textTheme.labelMedium),
          Text(
            '${MacroValues.display(value)} g',
            style: Theme.of(ctx).textTheme.titleMedium,
          ),
          Text(
            goal == null ? 'Sin meta' : 'Meta ${MacroValues.display(goal)} g',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      );
}

class _NutritionTextDialog extends StatefulWidget {
  const _NutritionTextDialog({
    required this.title,
    required this.value,
    required this.label,
    required this.multiline,
  });
  final String title, value, label;
  final bool multiline;
  @override
  State<_NutritionTextDialog> createState() => _NutritionTextDialogState();
}

class _NutritionTextDialogState extends State<_NutritionTextDialog> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLines: widget.multiline ? 4 : 1,
      decoration: InputDecoration(labelText: widget.label),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Guardar'),
      ),
    ],
  );
}
