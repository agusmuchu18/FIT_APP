import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  _HeroCard(summary: summary, dateText: 'Hoy · $date'),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    onPressed: () => _showQuickAddSheet(context),
                    icon: const Icon(Icons.add),
                    label: const Text('+ Registrar comida'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, i) {
                        final mealType = MealType.values[i];
                        final macros = summary.byMealType[mealType] ?? MacroValues.zero;
                        return _MealQuickCard(
                          mealType: mealType,
                          kcal: macros.kcal.round(),
                          onAdd: () => _showQuickAddSheet(context, mealType: mealType),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: MealType.values.length,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Plantillas', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      TextButton(onPressed: () => Navigator.pushNamed(context, '/nutrition/templates').then((_) => _load()), child: const Text('Ver todo')),
                      IconButton(
                        onPressed: () => Navigator.pushNamed(context, '/nutrition/template_editor').then((_) => _load()),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FolderRow(
                    folders: _folders,
                    selected: _selectedFolder,
                    onSelected: (id) => setState(() => _selectedFolder = id),
                    onNewFolder: _newFolder,
                  ),
                  const SizedBox(height: 12),
                  if (templates.isEmpty)
                    _EmptyCard(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Todavía no tenés plantillas',
                      action: 'Crear plantilla',
                      onAction: () => Navigator.pushNamed(context, '/nutrition/template_editor').then((_) => _load()),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 380 ? 1 : 2;
                        return GridView.builder(
                          itemCount: templates.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.06,
                          ),
                          itemBuilder: (_, i) => _TemplateCard(
                            template: templates[i],
                            onAdd: () => _onAddTemplate(templates[i]),
                            onMenu: (action) => _onTemplateAction(templates[i], action),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 22),
                  Text('Recientes', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (_recents.isEmpty)
                    const _EmptyCard(icon: Icons.history_toggle_off, title: 'Sin recientes por ahora', subtitle: 'Cuando repitas comidas aparecerán acá.')
                  else
                    ..._recents.take(5).map(
                          (item) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                            leading: const CircleAvatar(child: Icon(Icons.schedule)),
                            title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${mealTypeLabel(item.mealType)} · ${NutritionFormatters.formatKcal(item.kcal)}'),
                            trailing: TextButton(
                              onPressed: () async {
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary, required this.dateText});

  final NutritionDaySummary summary;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    final remaining = summary.remainingKcal;
    final hasMeals = summary.consumed.kcal > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [Color(0xFF1D2838), Color(0xFF141B26)]),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Alimentación', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(dateText),
            const SizedBox(height: 18),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${NutritionFormatters.formatNumberCompact(summary.consumed.kcal.round())} / ${NutritionFormatters.formatNumberCompact(summary.goal.kcal.round())} kcal',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 34, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Text(remaining >= 0 ? 'Restan ${NutritionFormatters.formatNumberCompact(remaining)}' : 'Excedido ${NutritionFormatters.formatNumberCompact(remaining.abs())}'),
            if (!hasMeals) ...[
              const SizedBox(height: 10),
              const Text('Empezá registrando tu primera comida'),
            ],
            const SizedBox(height: 16),
            _MacroBar(label: 'Proteínas', value: summary.consumed.protein, total: summary.goal.protein),
            const SizedBox(height: 8),
            _MacroBar(label: 'Carbs', value: summary.consumed.carbs, total: summary.goal.carbs),
            const SizedBox(height: 8),
            _MacroBar(label: 'Grasas', value: summary.consumed.fat, total: summary.goal.fat),
            const SizedBox(height: 12),
            const _MiniRadarPlaceholder(),
          ]),
        ),
      ),
    );
  }
}

class _MiniRadarPlaceholder extends StatelessWidget {
  const _MiniRadarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: CustomPaint(
        painter: _RadarPainter(),
        child: const SizedBox.expand(),
      ),
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
      ..color = Colors.tealAccent.withOpacity(0.16);

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

class _MacroBar extends StatelessWidget {
  const _MacroBar({required this.label, required this.value, required this.total});

  final String label;
  final double value;
  final double total;

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text('${value.round()}/${total.round()} g', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: pct, minHeight: 7, backgroundColor: Colors.white12),
        ),
      ],
    );
  }
}

class _MealQuickCard extends StatelessWidget {
  const _MealQuickCard({required this.mealType, required this.kcal, required this.onAdd});

  final MealType mealType;
  final int kcal;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mealTypeLabel(mealType), style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${NutritionFormatters.formatNumberCompact(kcal)} kcal'),
            Text(kcal == 0 ? 'Vacío' : 'Cargado', style: TextStyle(color: kcal == 0 ? Colors.orangeAccent : Colors.greenAccent, fontSize: 12)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: CircleAvatar(radius: 13, child: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folders,
    required this.selected,
    required this.onSelected,
    required this.onNewFolder,
  });

  final List<TemplateFolder> folders;
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onNewFolder;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      ChoiceChip(label: const Text('Todas'), selected: selected == 'all', onSelected: (_) => onSelected('all')),
      ChoiceChip(label: const Text('⭐ Favoritos'), selected: selected == 'favorite', onSelected: (_) => onSelected('favorite')),
      ...folders.map((f) => ChoiceChip(label: Text(f.name), selected: selected == f.id, onSelected: (_) => onSelected(f.id))),
      ActionChip(label: const Text('Nueva carpeta'), avatar: const Icon(Icons.create_new_folder_outlined, size: 16), onPressed: onNewFolder),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(scrollDirection: Axis.horizontal, itemBuilder: (_, i) => chips[i], separatorBuilder: (_, __) => const SizedBox(width: 8), itemCount: chips.length),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onAdd, required this.onMenu});

  final MealTemplate template;
  final VoidCallback onAdd;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final totals = template.effectiveTotals;
    final preview = template.effectiveItems.take(3).map((e) => e.name).join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.48),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(child: Text(template.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
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
        const SizedBox(height: 4),
        Text('${totals.kcal.round()} kcal · P ${totals.protein.round()} C ${totals.carbs.round()} G ${totals.fat.round()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        Text(preview.isEmpty ? 'Sin alimentos definidos' : preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        const Spacer(),
        FilledButton(onPressed: onAdd, child: const Text('Agregar')),
      ]),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.title, this.subtitle, this.action, this.onAction});

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: const TextStyle(fontSize: 12))],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
