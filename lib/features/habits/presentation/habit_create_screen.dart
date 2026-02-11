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
  bool _isCustomColorSelected = false;
  HabitFrequency _frequency = HabitFrequency.daily;
  DateTime _startDate = normalizeHabitDay(DateTime.now());
  Set<int> _activeWeekdays = {...kDefaultActiveWeekdays};
  int _intervalWeeks = 1;
  int _dayOfMonth = DateTime.now().day;
  bool _adjustToLastDayIfMissing = true;

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
    _isCustomColorSelected = !_premiumColors.any((color) => color.value == _selectedColor);
    _frequency = initial.frequency;
    _startDate = normalizeHabitDay(initial.startDate);
    _activeWeekdays = {...initial.activeWeekdays};
    _intervalWeeks = initial.intervalWeeks;
    _dayOfMonth = initial.dayOfMonth;
    _adjustToLastDayIfMissing = initial.adjustToLastDayIfMissing;
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('es'),
    );
    if (picked == null) return;
    final normalized = normalizeHabitDay(picked);
    setState(() {
      _startDate = normalized;
      _dayOfMonth = normalized.day;
    });
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

  Future<void> _pickCustomColor() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomColorSheet(initialColor: Color(_selectedColor)),
    );
    if (result == null) return;
    setState(() {
      _selectedColor = result;
      _isCustomColorSelected = true;
    });
  }

  String _formatDate(DateTime date) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
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
                    subtitle: 'Elegí entre más de 50 íconos',
                    child: SizedBox(
                      height: 240,
                      child: GridView.builder(
                        itemCount: kHabitIconOptions.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final option = kHabitIconOptions[index];
                          final selected = option.iconKey == _selectedIconKey;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIconKey = option.iconKey),
                            child: Container(
                              decoration: BoxDecoration(
                                color: selected ? Color(_selectedColor).withOpacity(0.2) : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: selected ? Color(_selectedColor) : Colors.white.withOpacity(0.08), width: selected ? 1.6 : 1),
                              ),
                              child: Stack(
                                children: [
                                  Center(child: Icon(option.iconData, color: selected ? Color(_selectedColor) : AppColors.textSecondary)),
                                  if (selected)
                                    const Positioned(
                                      right: 4,
                                      top: 4,
                                      child: Icon(Icons.check_circle, size: 15, color: AppColors.accent),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  _Section(
                    title: 'Color',
                    subtitle: 'Paleta premium + color personalizado',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._premiumColors.map((color) {
                          final selected = !_isCustomColorSelected && _selectedColor == color.value;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedColor = color.value;
                              _isCustomColorSelected = false;
                            }),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white.withOpacity(0.18))),
                              child: selected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                          );
                        }),
                        GestureDetector(
                          onTap: _pickCustomColor,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isCustomColorSelected ? Color(_selectedColor) : Colors.white.withOpacity(0.06),
                              border: Border.all(
                                color: _isCustomColorSelected ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.2),
                                width: _isCustomColorSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Icon(_isCustomColorSelected ? Icons.check : Icons.palette_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    title: 'Programación',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: _pickStartDate,
                          leading: const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary, size: 20),
                          title: Text('Comienza: ${_formatDate(_startDate)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        SegmentedButton<HabitFrequency>(
                          segments: HabitFrequency.values
                              .map((f) => ButtonSegment<HabitFrequency>(value: f, label: Text(f.label)))
                              .toList(),
                          selected: {_frequency},
                          onSelectionChanged: (value) => setState(() => _frequency = value.first),
                        ),
                        const SizedBox(height: 12),
                        if (_frequency == HabitFrequency.daily)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(7, (index) {
                              const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                              final weekday = index + 1;
                              final selected = _activeWeekdays.contains(weekday);
                              return FilterChip(
                                label: Text(labels[index]),
                                selected: selected,
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _activeWeekdays.add(weekday);
                                    } else if (_activeWeekdays.length > 1) {
                                      _activeWeekdays.remove(weekday);
                                    }
                                  });
                                },
                              );
                            }),
                          ),
                        if (_frequency == HabitFrequency.weekly)
                          Row(
                            children: [
                              const Expanded(child: Text('Repetir cada', style: TextStyle(color: AppColors.textSecondary))),
                              DropdownButton<int>(
                                value: _intervalWeeks,
                                dropdownColor: AppColors.card,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _intervalWeeks = value);
                                },
                                items: List.generate(8, (index) {
                                  final week = index + 1;
                                  return DropdownMenuItem(value: week, child: Text('$week semana${week > 1 ? 's' : ''}'));
                                }),
                              ),
                            ],
                          ),
                        if (_frequency == HabitFrequency.monthly)
                          Column(
                            children: [
                              Row(
                                children: [
                                  const Expanded(child: Text('Día del mes', style: TextStyle(color: AppColors.textSecondary))),
                                  IconButton(
                                    onPressed: _dayOfMonth > 1 ? () => setState(() => _dayOfMonth--) : null,
                                    icon: const Icon(Icons.remove_circle_outline_rounded),
                                  ),
                                  Text('$_dayOfMonth', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                  IconButton(
                                    onPressed: _dayOfMonth < 31 ? () => setState(() => _dayOfMonth++) : null,
                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                  ),
                                ],
                              ),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Si no existe ese día, usar último día', style: TextStyle(color: AppColors.textSecondary)),
                                value: _adjustToLastDayIfMissing,
                                onChanged: (value) => setState(() => _adjustToLastDayIfMissing = value),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    title: 'Contador',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Usar contador', style: TextStyle(color: AppColors.textSecondary)),
                          value: _isCountable,
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
                          startDate: _startDate,
                          activeWeekdays: _activeWeekdays,
                          intervalWeeks: _intervalWeeks,
                          dayOfMonth: _dayOfMonth,
                          adjustToLastDayIfMissing: _adjustToLastDayIfMissing,
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
                                  startDate: built.startDate,
                                  activeWeekdays: built.activeWeekdays,
                                  intervalWeeks: built.intervalWeeks,
                                  dayOfMonth: built.dayOfMonth,
                                  adjustToLastDayIfMissing: built.adjustToLastDayIfMissing,
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

class _CustomColorSheet extends StatefulWidget {
  const _CustomColorSheet({required this.initialColor});

  final Color initialColor;

  @override
  State<_CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<_CustomColorSheet> {
  late int _red;
  late int _green;
  late int _blue;

  @override
  void initState() {
    super.initState();
    _red = widget.initialColor.red;
    _green = widget.initialColor.green;
    _blue = widget.initialColor.blue;
  }

  @override
  Widget build(BuildContext context) {
    final color = Color.fromARGB(255, _red, _green, _blue);
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Color personalizado', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: Colors.white.withOpacity(0.24))),
              ),
            ),
            const SizedBox(height: 14),
            _RgbSlider(label: 'R', value: _red, onChanged: (v) => setState(() => _red = v), activeColor: Colors.redAccent),
            _RgbSlider(label: 'G', value: _green, onChanged: (v) => setState(() => _green = v), activeColor: Colors.greenAccent),
            _RgbSlider(label: 'B', value: _blue, onChanged: (v) => setState(() => _blue = v), activeColor: Colors.blueAccent),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, color.value),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({required this.label, required this.value, required this.onChanged, required this.activeColor});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 44, child: Text('$label $value', style: const TextStyle(color: AppColors.textSecondary))),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: activeColor),
            child: Slider(value: value.toDouble(), min: 0, max: 255, divisions: 255, onChanged: (v) => onChanged(v.round())),
          ),
        ),
      ],
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
  Color(0xFF5EEAD4),
  Color(0xFF38BDF8),
  Color(0xFFA78BFA),
  Color(0xFFF9A8D4),
  Color(0xFF34D399),
  Color(0xFFF59E0B),
  Color(0xFF22D3EE),
  Color(0xFF818CF8),
  Color(0xFFF472B6),
  Color(0xFF4ADE80),
  Color(0xFFE879F9),
  Color(0xFFF97316),
  Color(0xFF84CC16),
  Color(0xFF06B6D4),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFFEAB308),
  Color(0xFF0EA5E9),
];
