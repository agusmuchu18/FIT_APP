import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/theme/app_colors.dart';
import '../../common/widgets/primary_button.dart';
import '../domain/habit_gallery_engine.dart';
import '../domain/habit_models.dart';
import 'habit_create_screen.dart';

class HabitGallerySheet extends StatefulWidget {
  const HabitGallerySheet({
    super.key,
    required this.onAddHabit,
    required this.onAddMany,
    required this.onTemplatesConfirmed,
    required this.alreadyAddedTemplateIds,
    required this.userContext,
    required this.popularityByTemplate,
  });

  final Future<void> Function(HabitEntry habit) onAddHabit;
  final Future<void> Function(List<HabitEntry> habits) onAddMany;
  final Future<void> Function(List<String> templateIds) onTemplatesConfirmed;
  final Set<String> alreadyAddedTemplateIds;
  final HabitUserContext userContext;
  final Map<String, int> popularityByTemplate;

  @override
  State<HabitGallerySheet> createState() => _HabitGallerySheetState();
}

class _HabitGallerySheetState extends State<HabitGallerySheet>
    with TickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: habitCategories.length, vsync: this);
  final TextEditingController _searchController = TextEditingController();

  final Set<String> selectedTemplateIds = <String>{};
  late final Set<String> alreadyAddedTemplateIds;
  final Map<String, HabitCreationConfig> _configs = <String, HabitCreationConfig>{};
  late final Map<String, int> _popularityByTemplate;

  HabitSearchScope _searchScope = HabitSearchScope.currentCategory;
  HabitSortMode _sortMode = HabitSortMode.relevance;
  Timer? _searchDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    alreadyAddedTemplateIds = Set<String>.from(widget.alreadyAddedTemplateIds);
    _popularityByTemplate = Map<String, int>.from(widget.popularityByTemplate);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool _isAlreadyAdded(HabitTemplate template) =>
      alreadyAddedTemplateIds.contains(template.templateId);

  void _showAlreadyAddedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1300),
        content: Text('Este hábito ya está agregado'),
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _toggleSelect(HabitTemplate template) {
    if (_isAlreadyAdded(template)) {
      _showAlreadyAddedSnackBar();
      return;
    }

    final didSelect = !selectedTemplateIds.contains(template.templateId);
    HapticFeedback.selectionClick();

    setState(() {
      if (didSelect) {
        selectedTemplateIds.add(template.templateId);
      } else {
        selectedTemplateIds.remove(template.templateId);
      }
    });
  }

  Future<void> _configureTemplate(HabitTemplate template) async {
    if (_isAlreadyAdded(template)) {
      _showAlreadyAddedSnackBar();
      return;
    }

    HabitCreationConfig current =
        _configs[template.templateId] ?? template.defaultConfig();
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
                  Text(
                    'Configurar ${template.name}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<HabitFrequency>(
                    segments: HabitFrequency.values
                        .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                        .toList(),
                    selected: {current.frequency},
                    onSelectionChanged: (selection) =>
                        setModal(() => current = current.copyWith(frequency: selection.first)),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: current.isCountable,
                    title: const Text(
                      'Contable',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (value) =>
                        setModal(() => current = current.copyWith(isCountable: value)),
                  ),
                  if (current.isCountable)
                    TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Meta diaria',
                        labelStyle: TextStyle(color: AppColors.textMuted),
                      ),
                      onChanged: (value) =>
                          current = current.copyWith(targetCount: int.tryParse(value) ?? 1),
                    ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Guardar configuración',
                    onPressed: () => Navigator.pop(context, current),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (config == null) return;

    setState(() {
      _configs[template.templateId] = config;
      selectedTemplateIds.add(template.templateId);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _confirmBatch() async {
    if (selectedTemplateIds.isEmpty) return;

    final selectedTemplates = kHabitTemplates
        .where((template) =>
            selectedTemplateIds.contains(template.templateId) &&
            !alreadyAddedTemplateIds.contains(template.templateId))
        .toList(growable: false);

    final toAdd = selectedTemplates
        .map((template) => template.buildHabit(overrideConfig: _configs[template.templateId]))
        .toList(growable: false);

    if (toAdd.isEmpty) {
      _showAlreadyAddedSnackBar();
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    HapticFeedback.mediumImpact();
    await widget.onAddMany(toAdd);
    await widget.onTemplatesConfirmed(
      selectedTemplates.map((e) => e.templateId).toList(growable: false),
    );
    if (!mounted) return;

    setState(() {
      for (final template in selectedTemplates) {
        _popularityByTemplate[template.templateId] =
            (_popularityByTemplate[template.templateId] ?? template.popularityScore) + 1;
      }
    });

    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        content: Text('Agregaste ${toAdd.length} hábitos'),
      ),
    );
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
                  const Text(
                    'Galería',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: selectedTemplateIds.isEmpty ? null : _confirmBatch,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: habitCategories
                    .map((category) => Tab(text: category))
                    .toList(growable: false),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar hábitos...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                        ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('En esta categoría'),
                    selected: _searchScope == HabitSearchScope.currentCategory,
                    onSelected: (_) => setState(
                      () => _searchScope = HabitSearchScope.currentCategory,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('En todas'),
                    selected: _searchScope == HabitSearchScope.allCategories,
                    onSelected: (_) =>
                        setState(() => _searchScope = HabitSearchScope.allCategories),
                  ),
                  const Spacer(),
                  DropdownButton<HabitSortMode>(
                    value: _sortMode,
                    dropdownColor: AppColors.card,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortMode = value);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: HabitSortMode.relevance,
                        child: Text('Relevancia'),
                      ),
                      DropdownMenuItem(
                        value: HabitSortMode.popularity,
                        child: Text('Popularidad'),
                      ),
                      DropdownMenuItem(
                        value: HabitSortMode.alphabetical,
                        child: Text('A-Z'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: habitCategories.map((category) {
                    final templates = buildGalleryTemplates(
                      allTemplates: kHabitTemplates,
                      currentCategory: category,
                      searchScope: _searchScope,
                      query: _query,
                      sortMode: _sortMode,
                      user: widget.userContext,
                      popularityByTemplate: _popularityByTemplate,
                      alreadyAddedTemplateIds: alreadyAddedTemplateIds,
                    );

                    if (templates.isEmpty) {
                      return const Center(
                        child: Text(
                          'No se encontraron hábitos',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                      child: ListView.separated(
                        key: ValueKey('$category-$_query-$_searchScope-$_sortMode'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: templates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final selected = selectedTemplateIds.contains(template.templateId);
                          final isAdded = _isAlreadyAdded(template);
                          final color = Color(template.colorArgb);
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _toggleSelect(template),
                            onLongPress: () => _configureTemplate(template),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? color.withOpacity(0.12) : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? color.withOpacity(0.8)
                                      : Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color.withOpacity(0.2),
                                    ),
                                    child: Icon(iconForKey(template.iconKey), color: color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                template.name,
                                                style: const TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (_sortMode == HabitSortMode.relevance && index < 3)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(20),
                                                  color: Colors.white.withOpacity(0.08),
                                                ),
                                                child: const Text(
                                                  'Recomendado',
                                                  style: TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          template.subtitle,
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Configurar',
                                    onPressed: isAdded
                                        ? _showAlreadyAddedSnackBar
                                        : () => _configureTemplate(template),
                                    icon: Icon(
                                      Icons.more_horiz_rounded,
                                      color: isAdded
                                          ? AppColors.textMuted.withOpacity(0.45)
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isAdded
                                          ? Colors.white.withOpacity(0.07)
                                          : selected
                                              ? color
                                              : Colors.transparent,
                                      border: Border.all(
                                        color: isAdded
                                            ? Colors.white.withOpacity(0.24)
                                            : selected
                                                ? color
                                                : color.withOpacity(0.8),
                                      ),
                                    ),
                                    child: IconButton(
                                      tooltip: isAdded ? 'Agregado' : 'Seleccionar',
                                      onPressed: () => _toggleSelect(template),
                                      icon: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 220),
                                        switchInCurve: Curves.easeOut,
                                        switchOutCurve: Curves.easeOut,
                                        transitionBuilder: (child, animation) =>
                                            ScaleTransition(scale: animation, child: child),
                                        child: isAdded
                                            ? Icon(
                                                Icons.check_rounded,
                                                key: const ValueKey('added'),
                                                color: Colors.white.withOpacity(0.45),
                                              )
                                            : selected
                                                ? const Icon(
                                                    Icons.check_rounded,
                                                    key: ValueKey('check'),
                                                    color: Colors.white,
                                                  )
                                                : Icon(
                                                    Icons.add_rounded,
                                                    key: const ValueKey('add'),
                                                    color: color,
                                                  ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  0,
                  8,
                  0,
                  MediaQuery.of(context).padding.bottom + 10,
                ),
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
