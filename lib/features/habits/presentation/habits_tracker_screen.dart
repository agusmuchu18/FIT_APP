import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../common/theme/app_colors.dart';
import '../../common/widgets/primary_button.dart';

class HabitsTrackerScreen extends StatefulWidget {
  const HabitsTrackerScreen({super.key});

  @override
  State<HabitsTrackerScreen> createState() => _HabitsTrackerScreenState();
}

class _HabitsTrackerScreenState extends State<HabitsTrackerScreen> {
  static const String _habitsBoxName = 'fit_habits';
  static const _accentColors = [
    Color(0xFF67D1FF),
    Color(0xFFFF9AA2),
    Color(0xFF7BB7FF),
    Color(0xFFFFD166),
    Color(0xFFB892FF),
    Color(0xFF8BE8C1),
  ];
  static const _accentIcons = [
    Icons.menu_book_rounded,
    Icons.bolt_rounded,
    Icons.check_circle_rounded,
    Icons.nightlight_round,
    Icons.local_fire_department_rounded,
    Icons.favorite_rounded,
  ];

  final Map<String, bool> _completionState = {};
  late final Future<Box<String>> _habitsBoxFuture;

  int _selectedDayIndex = 6;

  @override
  void initState() {
    super.initState();
    _habitsBoxFuture = Hive.openBox<String>(_habitsBoxName);
  }

  void _showHabitActions(Box<String> box, _HabitEntry habit) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionSheetItem(
                icon: Icons.restart_alt_rounded,
                label: 'Resetear',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _completionState[habit.id] = false);
                },
              ),
              _ActionSheetItem(
                icon: Icons.list_alt_rounded,
                label: 'Registro de hábitos',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _ActionSheetItem(
                icon: Icons.edit_rounded,
                label: 'Editar',
                onTap: () {
                  Navigator.pop(context);
                  _showHabitEditor(box: box, habit: habit);
                },
              ),
              _ActionSheetItem(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                iconColor: const Color(0xFFFF6B6B),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await _confirmDelete(habit.name);
                  if (confirmed ?? false) {
                    await box.delete(habit.id);
                    setState(() => _completionState.remove(habit.id));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDelete(String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Eliminar hábito',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            '¿Seguro que quieres eliminar "$name"?',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHabitEditor({required Box<String> box, _HabitEntry? habit}) {
    final nameController = TextEditingController(text: habit?.name ?? '');
    final targetController = TextEditingController(
      text: habit?.targetCount?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var isCountable = habit?.targetCount != null;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit == null ? 'Nuevo hábito' : 'Editar hábito',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Nombre del hábito',
                          labelStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un nombre válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Hábito contable',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: isCountable,
                              onChanged: (value) {
                                setModalState(() => isCountable = value);
                              },
                              activeColor: AppColors.warning,
                            ),
                          ],
                        ),
                      ),
                      if (isCountable) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: targetController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Objetivo',
                            labelStyle: const TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (!isCountable) return null;
                            final parsed = int.tryParse(value ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Ingresa un número válido';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: habit == null ? 'Crear hábito' : 'Guardar cambios',
                        icon: Icons.check_rounded,
                        onPressed: () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final name = nameController.text.trim();
                          final targetCount = isCountable
                              ? int.tryParse(targetController.text.trim())
                              : null;
                          final entry = habit == null
                              ? _HabitEntry.create(name: name, targetCount: targetCount)
                              : habit.copyWith(name: name, targetCount: targetCount);

                          await box.put(entry.id, jsonEncode(entry.toJson()));
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<_HabitEntry> _loadHabits(Box<String> box) {
    return box.values
        .map(_HabitEntry.tryDecode)
        .whereType<_HabitEntry>()
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  _HabitAccent _accentFor(String id) {
    final index = id.hashCode.abs() % _accentColors.length;
    return _HabitAccent(
      icon: _accentIcons[index % _accentIcons.length],
      color: _accentColors[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = const ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final dates = const ['26', '27', '28', '29', '30', '31', '1'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<Box<String>>(
          future: _habitsBoxFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final box = snapshot.data!;
            return ValueListenableBuilder<Box<String>>(
              valueListenable: box.listenable(),
              builder: (context, _, __) {
                final habits = _loadHabits(box);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _CircularIconButton(
                            icon: Icons.pie_chart_outline,
                            onTap: () {},
                          ),
                          const Spacer(),
                          Text(
                            'Hábito',
                            style: textTheme.titleLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          _HeaderPillButton(
                            label: 'Nuevo hábito',
                            icon: Icons.add_rounded,
                            onTap: () => _showHabitEditor(box: box),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            final selected = index == _selectedDayIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedDayIndex = index),
                              child: Column(
                                children: [
                                  Text(
                                    days[index],
                                    style: textTheme.labelLarge?.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? AppColors.warning
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected
                                            ? Colors.transparent
                                            : Colors.white.withOpacity(0.08),
                                      ),
                                    ),
                                    child: Text(
                                      dates[index],
                                      style: textTheme.labelLarge?.copyWith(
                                        color: selected
                                            ? Colors.black
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 18),
                          itemCount: days.length,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 16,
                              ),
                              itemBuilder: (context, index) {
                                final habit = habits[index];
                                final accent = _accentFor(habit.id);
                                final completed = _completionState[habit.id] ?? false;
                                return Dismissible(
                                  key: ValueKey(habit.id),
                                  direction: DismissDirection.horizontal,
                                  confirmDismiss: (direction) async {
                                    if (direction == DismissDirection.startToEnd) {
                                      setState(
                                        () => _completionState[habit.id] = !completed,
                                      );
                                      HapticFeedback.lightImpact();
                                      return false;
                                    }
                                    if (direction == DismissDirection.endToStart) {
                                      _showHabitActions(box, habit);
                                      return false;
                                    }
                                    return false;
                                  },
                                  background: _SwipeBackground(
                                    color: const Color(0xFF19C37D),
                                    icon: Icons.check_rounded,
                                    alignment: Alignment.centerLeft,
                                  ),
                                  secondaryBackground: _SwipeBackground(
                                    color: const Color(0xFF4420B5),
                                    icon: Icons.close_rounded,
                                    alignment: Alignment.centerRight,
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _showHabitEditor(box: box, habit: habit),
                                    onLongPress: () => _showHabitActions(box, habit),
                                    child: _HabitRow(
                                      habit: habit,
                                      icon: accent.icon,
                                      iconColor: accent.color,
                                      completed: completed,
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => Divider(
                                height: 22,
                                color: Colors.white.withOpacity(0.06),
                              ),
                              itemCount: habits.length,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HabitEntry {
  _HabitEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    this.targetCount,
  });

  factory _HabitEntry.create({
    required String name,
    int? targetCount,
  }) {
    return _HabitEntry(
      id: const Uuid().v4(),
      name: name,
      targetCount: targetCount,
      createdAt: DateTime.now().toUtc(),
    );
  }

  final String id;
  final String name;
  final int? targetCount;
  final DateTime createdAt;

  _HabitEntry copyWith({
    String? name,
    int? targetCount,
  }) {
    return _HabitEntry(
      id: id,
      name: name ?? this.name,
      targetCount: targetCount,
      createdAt: createdAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'targetCount': targetCount,
        'createdAt': createdAt.toIso8601String(),
      };

  static _HabitEntry? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final map = decoded.cast<String, Object?>();
      final id = map['id'] as String? ?? '';
      if (id.isEmpty) return null;
      return _HabitEntry(
        id: id,
        name: map['name'] as String? ?? '',
        targetCount: map['targetCount'] is int
            ? map['targetCount'] as int
            : int.tryParse('${map['targetCount'] ?? ''}'),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now().toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}

class _HabitAccent {
  const _HabitAccent({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class _CircularIconButton extends StatelessWidget {
  const _CircularIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  const _HeaderPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.icon,
    required this.iconColor,
    required this.completed,
  });

  final _HabitEntry habit;
  final IconData icon;
  final Color iconColor;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = completed ? AppColors.textMuted : AppColors.textSecondary;
    final countLabel = habit.targetCount == null
        ? null
        : '0/${habit.targetCount} Contar';

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withOpacity(0.2),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.name,
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (countLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  countLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              completed ? '1' : '0',
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Racha Actual',
              style: textTheme.labelSmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      color: color,
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }
}

class _ActionSheetItem extends StatelessWidget {
  const _ActionSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
