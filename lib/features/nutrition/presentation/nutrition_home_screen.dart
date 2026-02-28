import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../data/nutrition_day_repository.dart';
import '../data/templates_repository.dart';
import '../domain/models.dart';
import 'food_log_screen.dart';
import 'utils/nutrition_formatters.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({super.key});

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  final _templatesRepository = TemplatesRepository();
  final _dayRepository = NutritionDayRepository();

  NutritionDaySummary? _summary;
  List<MealTemplate> _templates = [];
  List<TemplateFolder> _folders = [];
  List<RecentNutritionItem> _recents = [];
  String _selectedFolder = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await Future.wait([
      _dayRepository.getTodaySummary(),
      _templatesRepository.getTemplates(),
      _templatesRepository.getFolders(),
      _dayRepository.getRecents(),
    ]);
    if (!mounted) return;
    setState(() {
      _summary = data[0] as NutritionDaySummary;
      _templates = data[1] as List<MealTemplate>;
      _folders = data[2] as List<TemplateFolder>;
      _recents = data[3] as List<RecentNutritionItem>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final date = DateFormat("EEE d MMM", 'es').format(DateTime.now()).toLowerCase();
    final templates = _filteredTemplates();

    return Scaffold(
      appBar: AppBar(title: const Text('Alimentación')),
      body: _loading || summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  NutritionHeroCard(summary: summary, dateText: 'Hoy · $date'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 1,
                      shadowColor: Colors.black.withOpacity(0.24),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showQuickAddSheet(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('+ Registrar comida'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ShortcutPill(
                        icon: Icons.auto_awesome_motion_outlined,
                        label: 'Usar plantilla',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pushNamed(context, '/nutrition/templates').then((_) => _load());
                        },
                      ),
                      _ShortcutPill(
                        icon: Icons.search,
                        label: 'Buscar alimento',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodLogScreen()));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, i) {
                        final mealType = MealType.values[i];
                        final macros = summary.byMealType[mealType] ?? MacroValues.zero;
                        return MealQuickTile(
                          mealType: mealType,
                          kcal: macros.kcal.round(),
                          goalKcal: math.max(350, (summary.goal.kcal / MealType.values.length).round()),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showQuickAddSheet(context, mealType: mealType);
                          },
                          onAddTap: () {
                            HapticFeedback.lightImpact();
                            _showQuickAddSheet(context, mealType: mealType);
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: MealType.values.length,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Plantillas', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pushNamed(context, '/nutrition/templates').then((_) => _load()), child: const Text('Ver todo')),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pushNamed(context, '/nutrition/template_editor').then((_) => _load()),
                        child: Ink(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TemplateFolderChipsPremium(
                    folders: _folders,
                    selected: _selectedFolder,
                    onSelected: (id) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFolder = id);
                    },
                    onNewFolder: _newFolder,
                  ),
                  const SizedBox(height: 14),
                  if (templates.isEmpty)
                    PremiumEmptyState(
                      icon: Icons.folder_copy_outlined,
                      title: 'No hay plantillas todavía',
                      bullets: const [
                        'Guardá tus comidas favoritas para reutilizarlas en segundos.',
                        'Organizalas por momento del día para registrar más rápido.',
                      ],
                      primaryActionLabel: 'Crear plantilla',
                      onPrimaryAction: () => Navigator.pushNamed(context, '/nutrition/template_editor').then((_) => _load()),
                      linkActionLabel: 'Ver ejemplos',
                      onLinkAction: () {
                        // TODO: Reemplazar por catálogo real de ejemplos de plantillas.
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ejemplos próximamente')));
                      },
                    )
                  else
                    Column(
                      children: templates
                          .map(
                            (template) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TemplateCard(
                                template: template,
                                onAdd: () => _onAddTemplate(template),
                                onMenu: (action) => _onTemplateAction(template, action),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  const SizedBox(height: 24),
                  Text('Recientes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (_recents.isEmpty)
                    const PremiumEmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'Sin recientes por ahora',
                      bullets: ['Cuando repitas comidas aparecerán acá.', 'Podrás agregar con un toque usando “Repetir”.'],
                    )
                  else
                    ..._recents.take(5).map(
                          (item) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                            leading: const CircleAvatar(child: Icon(Icons.schedule)),
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${mealTypeLabel(item.mealType)} · ${NutritionFormatters.formatKcal(item.kcal)}'),
                            trailing: TextButton(
                              onPressed: () async {
                                HapticFeedback.selectionClick();
                                await _dayRepository.duplicateRecent(item);
                                await _load();
                              },
                              child: const Text('Repetir'),
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  List<MealTemplate> _filteredTemplates() {
    if (_selectedFolder == 'all') return _templates;
    if (_selectedFolder == 'favorite') return _templates.where((t) => t.isFavorite).toList();
    return _templates.where((t) => t.folderId == _selectedFolder).toList();
  }

  Future<void> _newFolder() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva carpeta'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nombre carpeta')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await _templatesRepository.addFolder(TemplateFolder(id: const Uuid().v4(), name: value, order: _folders.length + 10));
    await _load();
  }

  Future<void> _onAddTemplate(MealTemplate template, {MealType? mealType}) async {
    final type = mealType ?? template.mealType ?? await _askMealType();
    if (type == null) return;
    await _dayRepository.addTemplateToToday(template, mealType: type);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se agregó ${template.name} a ${mealTypeLabel(type)}')));
    }
    await _load();
  }

  Future<void> _onTemplateAction(MealTemplate template, String action) async {
    switch (action) {
      case 'favorite':
        await _templatesRepository.toggleFavorite(template.id);
        break;
      case 'duplicate':
        await _templatesRepository.add(
          template.copyWith(
            id: const Uuid().v4(),
            name: '${template.name} (copia)',
            createdAt: DateTime.now(),
          ),
        );
        break;
      case 'rename':
        final text = TextEditingController(text: template.name);
        final result = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Renombrar plantilla'),
            content: TextField(controller: text),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, text.text.trim()), child: const Text('Guardar')),
            ],
          ),
        );
        if (result != null && result.isNotEmpty) {
          await _templatesRepository.update(template.copyWith(name: result));
        }
        break;
      case 'delete':
        await _templatesRepository.delete(template.id);
        break;
      case 'move':
        final folderId = await _askFolder(template.folderId);
        if (folderId != null) {
          await _templatesRepository.moveToFolder(template.id, folderId == 'none' ? null : folderId);
        }
        break;
    }
    await _load();
  }

  Future<String?> _askFolder(String? current) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            RadioListTile<String>(value: 'none', groupValue: current ?? 'none', onChanged: (v) => Navigator.pop(context, v), title: const Text('Sin carpeta')),
            ..._folders.map(
              (folder) => RadioListTile<String>(
                value: folder.id,
                groupValue: current,
                onChanged: (v) => Navigator.pop(context, v),
                title: Text(folder.name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<MealType?> _askMealType() {
    return showModalBottomSheet<MealType>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: MealType.values
              .map((type) => ListTile(title: Text(mealTypeLabel(type)), onTap: () => Navigator.pop(context, type)))
              .toList(growable: false),
        ),
      ),
    );
  }

  Future<void> _showQuickAddSheet(BuildContext context, {MealType? mealType}) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Buscar alimento'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => FoodLogScreen(initialMealType: mealType)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_motion_outlined),
              title: const Text('Usar plantilla'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/nutrition/templates').then((_) => _load());
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Duplicar comida reciente'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/nutrition/quick_add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Crear plantilla'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/nutrition/template_editor').then((_) => _load());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class NutritionHeroCard extends StatelessWidget {
  const NutritionHeroCard({required this.summary, required this.dateText, super.key});

  final NutritionDaySummary summary;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    final consumed = summary.consumed.kcal.round();
    final goal = summary.goal.kcal.round();
    final remaining = summary.remainingKcal;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const RadialGradient(
              center: Alignment(-0.55, -0.65),
              radius: 1.35,
              colors: [Color(0xFF2A3A52), Color(0xFF172131), Color(0xFF121A27)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.14), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resumen de hoy', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(dateText, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => HapticFeedback.selectionClick(),
                    icon: Icon(Icons.more_horiz, color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                            child: Text(
                              NutritionFormatters.formatNumberCompact(consumed),
                              key: ValueKey(consumed),
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 38, height: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'de ${NutritionFormatters.formatNumberCompact(goal)} kcal',
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.72)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HeroVisualPlaceholder(hasData: consumed > 0),
                ],
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      remaining >= 0
                          ? 'Restan ${NutritionFormatters.formatNumberCompact(remaining)}'
                          : 'Excedido ${NutritionFormatters.formatNumberCompact(remaining.abs())}',
                      key: ValueKey(remaining),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: MacroTile(
                      icon: Icons.fitness_center,
                      label: 'Proteínas',
                      value: summary.consumed.protein,
                      total: summary.goal.protein,
                      gradient: const [Color(0xFF87E7FF), Color(0xFF4FC3F7)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MacroTile(
                      icon: Icons.grain,
                      label: 'Carbs',
                      value: summary.consumed.carbs,
                      total: summary.goal.carbs,
                      gradient: const [Color(0xFFFFE082), Color(0xFFFFB74D)],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MacroTile(
                      icon: Icons.opacity,
                      label: 'Grasas',
                      value: summary.consumed.fat,
                      total: summary.goal.fat,
                      gradient: const [Color(0xFFF8BBD0), Color(0xFFF48FB1)],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MacroTile extends StatelessWidget {
  const MacroTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.total,
    required this.gradient,
    super.key,
  });

  final IconData icon;
  final String label;
  final double value;
  final double total;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.76))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${NutritionFormatters.formatNumberCompact(value.round())}/${NutritionFormatters.formatNumberCompact(total.round())} g',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 6, color: Colors.white.withOpacity(0.12)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  height: 6,
                  width: 72 * pct,
                  decoration: BoxDecoration(gradient: LinearGradient(colors: gradient)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MealQuickTile extends StatelessWidget {
  const MealQuickTile({
    required this.mealType,
    required this.kcal,
    required this.goalKcal,
    required this.onTap,
    required this.onAddTap,
    super.key,
  });

  final MealType mealType;
  final int kcal;
  final int goalKcal;
  final VoidCallback onTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final pct = goalKcal <= 0 ? 0.0 : (kcal / goalKcal).clamp(0.0, 1.0);
    final isLoaded = kcal > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        width: 168,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: isLoaded ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_mealIcon(mealType), size: 24, color: Colors.white.withOpacity(0.9)),
                const Spacer(),
                GestureDetector(
                  onTap: onAddTap,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.14),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.add, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(mealTypeLabel(mealType), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${NutritionFormatters.formatNumberCompact(kcal)} kcal', style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(height: 4),
            Text(
              isLoaded ? 'Cargado' : 'Vacío',
              style: TextStyle(fontSize: 12, color: isLoaded ? Colors.greenAccent.shade100 : Colors.white70),
            ),
            const Spacer(),
            if (isLoaded)
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(height: 5, color: Colors.white.withOpacity(0.12)),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 5,
                      width: 140 * pct,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF80D8FF), Color(0xFF00E5FF)]),
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  IconData _mealIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.lunch_dining_outlined;
      case MealType.snack:
        return Icons.coffee_outlined;
      case MealType.dinner:
        return Icons.dinner_dining_outlined;
      case MealType.supper:
        return Icons.icecream_outlined;
    }
  }
}

class TemplateFolderChipsPremium extends StatelessWidget {
  const TemplateFolderChipsPremium({
    required this.folders,
    required this.selected,
    required this.onSelected,
    required this.onNewFolder,
    super.key,
  });

  final List<TemplateFolder> folders;
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final chips = <_ChipMeta>[
      const _ChipMeta(id: 'all', label: 'Todas', icon: Icons.apps),
      const _ChipMeta(id: 'favorite', label: '⭐ Favoritos', icon: Icons.star_border),
      ...folders.map((f) => _ChipMeta(id: f.id, label: f.name, icon: Icons.folder_open)),
      const _ChipMeta(id: 'new', label: '+ Nueva', icon: Icons.add_circle_outline),
    ];

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, i) {
          final chip = chips[i];
          final isSelected = chip.id == selected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isSelected ? 16 : 14),
              color: isSelected ? Colors.white.withOpacity(0.16) : Colors.white.withOpacity(0.06),
              border: Border.all(color: isSelected ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.14)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: chip.id == 'new' ? onNewFolder : () => onSelected(chip.id),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSelected ? 14 : 12, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chip.icon, size: 15, color: Colors.white.withOpacity(0.86)),
                    const SizedBox(width: 6),
                    Text(chip.label, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: chips.length,
      ),
    );
  }
}

class TemplateCard extends StatelessWidget {
  const TemplateCard({required this.template, required this.onAdd, required this.onMenu, super.key});

  final MealTemplate template;
  final VoidCallback onAdd;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final totals = template.effectiveTotals;
    final previewItems = template.effectiveItems.take(3).map((e) => '• ${e.name}').toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(template.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              PopupMenuButton<String>(
                onSelected: onMenu,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'move', child: Text('Mover a carpeta')),
                  PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                  PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  PopupMenuItem(value: 'favorite', child: Text('Marcar favorito')),
                ],
              ),
            ],
          ),
          Text('${NutritionFormatters.formatNumberCompact(totals.kcal.round())} kcal', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _macroPill('P ${totals.protein.round()}g'),
              _macroPill('C ${totals.carbs.round()}g'),
              _macroPill('G ${totals.fat.round()}g'),
            ],
          ),
          const SizedBox(height: 10),
          ...previewItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(item, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
              )),
          if (previewItems.isEmpty)
            Text('• Sin alimentos definidos', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                child: const Text('Agregar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

class PremiumEmptyState extends StatelessWidget {
  const PremiumEmptyState({
    required this.icon,
    required this.title,
    required this.bullets,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.linkActionLabel,
    this.onLinkAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final List<String> bullets;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? linkActionLabel;
  final VoidCallback? onLinkAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.white.withOpacity(0.82)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          ...bullets.map((bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: Colors.white.withOpacity(0.72))),
                    Expanded(child: Text(bullet, style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.74)))),
                  ],
                ),
              )),
          if (primaryActionLabel != null && onPrimaryAction != null) ...[
            const SizedBox(height: 8),
            FilledButton(onPressed: onPrimaryAction, child: Text(primaryActionLabel!)),
          ],
          if (linkActionLabel != null && onLinkAction != null)
            TextButton(onPressed: onLinkAction, child: Text(linkActionLabel!)),
        ],
      ),
    );
  }
}

class _HeroVisualPlaceholder extends StatelessWidget {
  const _HeroVisualPlaceholder({required this.hasData});

  final bool hasData;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: hasData
          ? CustomPaint(painter: _RadarPainter(), child: const SizedBox.expand())
          : Icon(Icons.insights_outlined, color: Colors.white.withOpacity(0.74)),
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = math.min(size.width, size.height) * 0.42;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24
      ..strokeWidth = 1;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.tealAccent.withOpacity(0.18);

    final path = Path();
    for (var i = 0; i < 3; i++) {
      final angle = (-math.pi / 2) + i * (2 * math.pi / 3);
      final p = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, base);

    final valuePath = Path();
    const factors = [0.7, 0.55, 0.82];
    for (var i = 0; i < 3; i++) {
      final angle = (-math.pi / 2) + i * (2 * math.pi / 3);
      final p = Offset(center.dx + radius * factors[i] * math.cos(angle), center.dy + radius * factors[i] * math.sin(angle));
      if (i == 0) {
        valuePath.moveTo(p.dx, p.dy);
      } else {
        valuePath.lineTo(p.dx, p.dy);
      }
    }
    valuePath.close();
    canvas.drawPath(valuePath, fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipMeta {
  const _ChipMeta({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}
