import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../../common/widgets/primary_button.dart';
import '../domain/habit_models.dart';

class HabitCreateScreen extends StatefulWidget {
  const HabitCreateScreen({super.key, this.initialHabit});

  final HabitEntry? initialHabit;

  @override
  State<HabitCreateScreen> createState() => _HabitCreateScreenState();
}

class _HabitCreateScreenState extends State<HabitCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _customGoalController = TextEditingController(text: '30');

  String _selectedIconKey = 'spark';
  int _selectedColor = _premiumColors.first.value;
  HabitFrequency _frequency = HabitFrequency.daily;
  bool _isCountable = false;
  int _targetCount = 1;
  int? _goalDays = 21;
  bool _isForever = false;


  @override
  void initState() {
    super.initState();
    final initial = widget.initialHabit;
    if (initial == null) return;
    _nameController.text = initial.name;
    _selectedIconKey = initial.iconKey;
    _selectedColor = initial.colorArgb;
    _frequency = initial.frequency;
    _isCountable = initial.isCountable;
    _targetCount = initial.targetCount ?? 1;
    _goalDays = initial.goalDays;
    _isForever = initial.isForever;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customGoalController.dispose();
    super.dispose();
  }

  Future<void> _askCustomGoal() async {
    final value = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Días personalizados', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _customGoalController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ej: 50',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.08))),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Guardar',
                onPressed: () {
                  Navigator.pop(context, int.tryParse(_customGoalController.text.trim()));
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || value == null || value <= 0) return;
    setState(() {
      _goalDays = value;
      _isForever = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nuevo hábito'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _Section(
                    title: 'Nombre',
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Ej: Caminar 30 minutos',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                    ),
                  ),
                  _Section(
                    title: 'Icono',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _iconOptions.map((key) {
                        final selected = key == _selectedIconKey;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIconKey = key),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected ? Color(_selectedColor).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: selected ? Color(_selectedColor) : Colors.white.withOpacity(0.08), width: selected ? 1.6 : 1),
                            ),
                            child: Stack(
                              children: [
                                Center(child: Icon(iconForKey(key), color: AppColors.textPrimary)),
                                if (selected)
                                  const Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Icon(Icons.check_circle, size: 16, color: AppColors.accent),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  _Section(
                    title: 'Color',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _premiumColors.map((color) {
                        final selected = color.value == _selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color.value),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: selected ? Colors.white : Colors.white24, width: selected ? 2 : 1),
                            ),
                            child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  _Section(
                    title: 'Frecuencia',
                    child: SegmentedButton<HabitFrequency>(
                      segments: HabitFrequency.values
                          .map((f) => ButtonSegment(value: f, label: Text(f.label)))
                          .toList(),
                      selected: {_frequency},
                      onSelectionChanged: (value) => setState(() => _frequency = value.first),
                    ),
                  ),
                  _Section(
                    title: 'Contable',
                    subtitle: 'Activalo si querés registrar cantidad diaria.',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          value: _isCountable,
                          title: const Text('Hábito contable', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          onChanged: (value) => setState(() => _isCountable = value),
                        ),
                        if (_isCountable)
                          TextField(
                            keyboardType: TextInputType.number,
                            onChanged: (value) => _targetCount = int.tryParse(value) ?? 1,
                            decoration: InputDecoration(
                              labelText: 'Meta diaria',
                              labelStyle: const TextStyle(color: AppColors.textMuted),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.04),
                            ),
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    title: 'Días objetivo',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [7, 21, 30, 45, 100, 365]
                          .map((days) => _GoalChip(
                                label: '$days',
                                selected: !_isForever && _goalDays == days,
                                onTap: () => setState(() {
                                  _goalDays = days;
                                  _isForever = false;
                                }),
                              ))
                          .toList()
                        ..addAll([
                          _GoalChip(label: 'Personalizado', selected: false, onTap: _askCustomGoal),
                          _GoalChip(
                            label: 'Para siempre',
                            selected: _isForever,
                            onTap: () => setState(() {
                              _isForever = true;
                              _goalDays = null;
                            }),
                          ),
                        ]),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(color: AppColors.background.withOpacity(0.9), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04)))),
              child: PrimaryButton(
                label: 'Guardar',
                icon: Icons.check_rounded,
                onPressed: canSave
                    ? () {
                        final initial = widget.initialHabit;
                        final built = HabitEntry.create(
                          name: _nameController.text.trim(),
                          iconKey: _selectedIconKey,
                          colorArgb: _selectedColor,
                          category: initial?.category ?? 'Personal',
                          frequency: _frequency,
                          isCountable: _isCountable,
                          goalDays: _goalDays,
                          isForever: _isForever,
                          targetCount: _isCountable ? _targetCount : null,
                        );
                        Navigator.pop(
                          context,
                          initial == null
                              ? built
                              : HabitEntry(
                                  id: initial.id,
                                  name: built.name,
                                  iconKey: built.iconKey,
                                  colorArgb: built.colorArgb,
                                  category: built.category,
                                  frequency: built.frequency,
                                  isCountable: built.isCountable,
                                  goalDays: built.goalDays,
                                  isForever: built.isForever,
                                  createdAt: initial.createdAt,
                                  targetCount: built.targetCount,
                                  subtitle: initial.subtitle,
                                ),
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(label),
      labelStyle: TextStyle(color: selected ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.w600),
      backgroundColor: Colors.white.withOpacity(0.05),
      selectedColor: AppColors.accentSecondary,
    );
  }
}

const _iconOptions = ['spark', 'water', 'breakfast', 'nutrition', 'read', 'workout', 'meditate', 'smile', 'moon', 'heart'];

const _premiumColors = [
  Color(0xFF67D1FF),
  Color(0xFF2AF5D2),
  Color(0xFF9C6ADE),
  Color(0xFFFF9AA2),
  Color(0xFFFFD166),
  Color(0xFF60D394),
  Color(0xFF4FC3F7),
  Color(0xFF8B7CFF),
  Color(0xFF26A69A),
  Color(0xFFF06292),
  Color(0xFF7BB7FF),
  Color(0xFFB892FF),
];
