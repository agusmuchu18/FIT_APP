import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/theme/app_colors.dart';

class HabitsTrackerScreen extends StatefulWidget {
  const HabitsTrackerScreen({super.key});

  @override
  State<HabitsTrackerScreen> createState() => _HabitsTrackerScreenState();
}

class _HabitsTrackerScreenState extends State<HabitsTrackerScreen> {
  final List<_HabitItem> _habits = [
    _HabitItem(
      id: 'read',
      name: 'Leer',
      icon: Icons.menu_book_rounded,
      iconColor: const Color(0xFF67D1FF),
    ),
    _HabitItem(
      id: 'breakfast',
      name: 'Desayuno Fit',
      icon: Icons.breakfast_dining_rounded,
      iconColor: const Color(0xFFFF9AA2),
    ),
    _HabitItem(
      id: 'teeth',
      name: 'Cepillarse los dientes',
      icon: Icons.brush_rounded,
      iconColor: const Color(0xFF7BB7FF),
      countLabel: '0/2 Contar',
    ),
  ];

  int _selectedDayIndex = 6;

  void _toggleCompleted(_HabitItem habit) {
    setState(() {
      habit.completed = !habit.completed;
    });
    HapticFeedback.lightImpact();
  }

  void _showHabitActions(_HabitItem habit) {
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
                  setState(() => habit.completed = false);
                },
              ),
              _ActionSheetItem(
                icon: Icons.list_alt_rounded,
                label: 'Registro de hábitos',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = const ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final dates = const ['26', '27', '28', '29', '30', '31', '1'];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.warning,
        onPressed: () {},
        child: const Icon(Icons.add_rounded, color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
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
                  _RightPillActions(),
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
                        final habit = _habits[index];
                        return Dismissible(
                          key: ValueKey(habit.id),
                          direction: DismissDirection.horizontal,
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              _toggleCompleted(habit);
                              return false;
                            }
                            if (direction == DismissDirection.endToStart) {
                              _showHabitActions(habit);
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
                            onLongPress: () => _showHabitActions(habit),
                            child: _HabitRow(habit: habit),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => Divider(
                        height: 22,
                        color: Colors.white.withOpacity(0.06),
                      ),
                      itemCount: _habits.length,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitItem {
  _HabitItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconColor,
    this.countLabel,
    this.completed = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color iconColor;
  final String? countLabel;
  bool completed;
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

class _RightPillActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: const [
          Icon(Icons.view_agenda_outlined, color: AppColors.textSecondary, size: 18),
          SizedBox(width: 10),
          Icon(Icons.tune_rounded, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({required this.habit});

  final _HabitItem habit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = habit.completed ? AppColors.textMuted : AppColors.textSecondary;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: habit.iconColor.withOpacity(0.2),
          ),
          child: Icon(habit.icon, color: habit.iconColor, size: 22),
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
              if (habit.countLabel != null) ...[
                const SizedBox(height: 4),
                Text(
                  habit.countLabel!,
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
              habit.completed ? '1' : '0',
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
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
