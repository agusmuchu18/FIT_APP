import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../../common/widgets/primary_button.dart';
import '../domain/habit_models.dart';
import 'habit_create_screen.dart';

class HabitGallerySheet extends StatefulWidget {
  const HabitGallerySheet({super.key, required this.onAddHabit, required this.onAddMany});

  final Future<void> Function(HabitEntry habit) onAddHabit;
  final Future<void> Function(List<HabitEntry> habits) onAddMany;

  @override
  State<HabitGallerySheet> createState() => _HabitGallerySheetState();
}

class _HabitGallerySheetState extends State<HabitGallerySheet> with TickerProviderStateMixin {
  late final TabController _tabController = TabController(length: habitCategories.length, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final Set<String> _selectedIds = <String>{};
  final Map<String, HabitCreationConfig> _configs = <String, HabitCreationConfig>{};

  Future<void> _quickAdd(HabitTemplate template) async {
    await widget.onAddHabit(template.buildHabit());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hábito agregado')));
  }

  void _toggleSelect(HabitTemplate template) {
    setState(() {
      if (_selectedIds.contains(template.id)) {
        _selectedIds.remove(template.id);
      } else {
        _selectedIds.add(template.id);
      }
    });
  }

  Future<void> _configureTemplate(HabitTemplate template) async {
    HabitCreationConfig current = _configs[template.id] ?? template.defaultConfig();
    final config = await showModalBottomSheet<HabitCreationConfig>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configurar ${template.name}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 12),
                  SegmentedButton<HabitFrequency>(
                    segments: HabitFrequency.values.map((f) => ButtonSegment(value: f, label: Text(f.label))).toList(),
                    selected: {current.frequency},
                    onSelectionChanged: (selection) => setModal(() => current = current.copyWith(frequency: selection.first)),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: current.isCountable,
                    title: const Text('Contable', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    onChanged: (value) => setModal(() => current = current.copyWith(isCountable: value)),
                  ),
                  if (current.isCountable)
                    TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(labelText: 'Meta diaria', labelStyle: TextStyle(color: AppColors.textMuted)),
                      onChanged: (value) => current = current.copyWith(targetCount: int.tryParse(value) ?? 1),
                    ),
                  const SizedBox(height: 12),
                  PrimaryButton(label: 'Agregar', onPressed: () => Navigator.pop(context, current)),
                ],
              ),
            ),
          );
        });
      },
    );

    if (config == null) return;
    _configs[template.id] = config;
    await widget.onAddHabit(template.buildHabit(overrideConfig: config));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hábito agregado')));
  }

  Future<void> _confirmBatch() async {
    if (_selectedIds.isEmpty) return;
    final toAdd = kHabitTemplates
        .where((template) => _selectedIds.contains(template.id))
        .map((template) => template.buildHabit(overrideConfig: _configs[template.id]))
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    await widget.onAddMany(toAdd);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('${toAdd.length} hábitos agregados')));
    Navigator.pop(context);
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<HabitEntry>(
      context,
      MaterialPageRoute(builder: (_) => const HabitCreateScreen()),
    );
    if (created == null) return;
    final messenger = ScaffoldMessenger.of(context);
    await widget.onAddHabit(created);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Hábito agregado')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: habitCategories.length,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  const Spacer(),
                  const Text('Galería', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: _selectedIds.isEmpty ? null : _confirmBatch,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: habitCategories.map((category) => Tab(text: category)).toList(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: habitCategories.map((category) {
                    final templates = kHabitTemplates.where((t) => t.category == category).toList();
                    return ListView.separated(
                      itemCount: templates.length,
                      separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.06)),
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        final selected = _selectedIds.contains(template.id);
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _toggleSelect(template),
                          onLongPress: () => _configureTemplate(template),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? Color(template.colorArgb).withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: selected ? Color(template.colorArgb).withOpacity(0.8) : Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(template.colorArgb).withOpacity(0.2)),
                                  child: Icon(iconForKey(template.iconKey), color: Color(template.colorArgb)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(template.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(template.subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Configurar',
                                  onPressed: () => _configureTemplate(template),
                                  icon: const Icon(Icons.more_horiz_rounded, color: AppColors.textMuted),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Color(template.colorArgb).withOpacity(0.8)),
                                  ),
                                  child: IconButton(
                                    onPressed: () => _quickAdd(template),
                                    icon: Icon(Icons.add_rounded, color: Color(template.colorArgb)),
                                  ),
                                ),
                                if (selected) const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.check_circle_rounded, color: AppColors.accentSecondary, size: 18),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(0, 8, 0, MediaQuery.of(context).padding.bottom + 10),
                child: PrimaryButton(
                  label: 'Crear un nuevo hábito',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _openCreate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
