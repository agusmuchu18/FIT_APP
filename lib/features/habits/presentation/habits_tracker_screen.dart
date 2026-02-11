import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../ui/motion/widgets/habit_check_overlay.dart';
import '../../common/theme/app_colors.dart';
import '../domain/habit_models.dart';
import 'habit_create_screen.dart';
import 'habit_gallery_sheet.dart';

const double kHabitTileRadius = 24;
const double _kSwipeIconHorizontalPadding = 18;
const double _kSwipeIconBubbleSize = 46;

class HabitsTrackerScreen extends StatefulWidget {
  const HabitsTrackerScreen({super.key});

  @override
  State<HabitsTrackerScreen> createState() => _HabitsTrackerScreenState();
}

class _HabitsTrackerScreenState extends State<HabitsTrackerScreen> {
  static const String _habitsBoxName = 'fit_habits';

  final Map<String, bool> _completionState = {};
  late final Future<Box<String>> _habitsBoxFuture;

  late DateTime _today;
  late DateTime _selectedDay;
  bool _hasManualSelection = false;
  Timer? _midnightTimer;

  DateTime normalizeDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    _today = normalizeDay(DateTime.now());
    _selectedDay = _today;
    _habitsBoxFuture = Hive.openBox<String>(_habitsBoxName);
    _scheduleTimerUntilNextMidnight();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleTimerUntilNextMidnight() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), _handleDayChanged);
  }

  void _handleDayChanged() {
    if (!mounted) return;
    final currentDay = normalizeDay(DateTime.now());
    if (currentDay != _today) {
      setState(() {
        _today = currentDay;
        if (!_hasManualSelection) {
          _selectedDay = _today;
        }
      });
    }
    _scheduleTimerUntilNextMidnight();
  }

  List<_HabitEntry> _loadHabits(Box<String> box) {
    return box.values.map((raw) {
      try {
        final map = (jsonDecode(raw) as Map).cast<String, Object?>();
        return _HabitEntry.fromModel(HabitEntry.tryDecode(map));
      } catch (_) {
        return null;
      }
    }).whereType<_HabitEntry>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> _saveHabit(Box<String> box, HabitEntry habit) async {
    await box.put(habit.id, jsonEncode(habit.toJson()));
  }

  Future<void> _addMany(Box<String> box, List<HabitEntry> habits) async {
    final entries = <String, String>{
      for (final habit in habits) habit.id: jsonEncode(habit.toJson()),
    };
    await box.putAll(entries);
  }


  Set<String> _loadAddedTemplateIds(Box<String> box) {
    final ids = <String>{};
    for (final raw in box.values) {
      try {
        final map = (jsonDecode(raw) as Map).cast<String, Object?>();
        final templateId = map['sourceTemplateId'] as String?;
        if (templateId != null && templateId.isNotEmpty) {
          ids.add(templateId);
        }
      } catch (_) {
        // Ignora entradas corruptas.
      }
    }
    return ids;
  }

  void _showHabitActions(Box<String> box, _HabitEntry habit) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
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
                  await box.delete(habit.id);
                  if (!mounted) return;
                  setState(() => _completionState.remove(habit.id));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showHabitEditor({required Box<String> box, _HabitEntry? habit}) async {
    final result = await Navigator.push<HabitEntry>(
      context,
      MaterialPageRoute(builder: (_) => HabitCreateScreen(initialHabit: habit?.toModel())),
    );
    if (result == null) return;
    await _saveHabit(box, result);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(habit == null ? 'Hábito creado' : 'Hábito actualizado')),
    );
  }

  List<DateTime> _daysOfWeek() {
    final endDay = _today;
    final startDay = endDay.subtract(const Duration(days: 6));
    return List<DateTime>.generate(7, (index) => normalizeDay(startDay.add(Duration(days: index))));
  }

  String _weekdayLetter(DateTime day) {
    switch (day.weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'M';
      case DateTime.wednesday:
        return 'M';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
    }
    return '';
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekDays = _daysOfWeek();
    final dayLabels = weekDays.map(_weekdayLetter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<Box<String>>(
          future: _habitsBoxFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final box = snapshot.data!;
            return ValueListenableBuilder<Box<String>>(
              valueListenable: box.listenable(),
              builder: (context, _, __) {
                final habits = _loadHabits(box)
                    .where((habit) => shouldAppearOn(habit.toModel(), _selectedDay))
                    .toList();
                final bottomPad = MediaQuery.of(context).padding.bottom + 110;
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _CircularIconButton(icon: Icons.pie_chart_outline, onTap: () {}),
                          const Spacer(),
                          Text('Hábito', style: textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          _HeaderPillButton(
                            label: 'Nuevo hábito',
                            icon: Icons.add_rounded,
                            onTap: () {
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.background,
                                builder: (_) => FractionallySizedBox(
                                  heightFactor: 0.93,
                                  child: HabitGallerySheet(
                                    onAddHabit: (habit) => _saveHabit(box, habit),
                                    onAddMany: (habits) => _addMany(box, habits),
                                    alreadyAddedTemplateIds: _loadAddedTemplateIds(box),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: weekDays.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 18),
                          itemBuilder: (context, index) {
                            final day = weekDays[index];
                            final selected = _isSameDay(day, _selectedDay);
                            final isToday = _isSameDay(day, _today);
                            return GestureDetector(
                              onTap: () => setState(() {
                                _hasManualSelection = true;
                                _selectedDay = day;
                              }),
                              child: Column(children: [
                                Text(dayLabels[index], style: textTheme.labelLarge?.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected ? AppColors.warning : Colors.transparent,
                                    border: Border.all(color: isToday && !selected ? AppColors.warning.withOpacity(0.7) : Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Text('${day.day}', style: textTheme.labelLarge?.copyWith(color: selected ? Colors.black : AppColors.textSecondary, fontWeight: FontWeight.w700)),
                                ),
                              ]),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            itemCount: habits.length,
                            separatorBuilder: (_, __) => Divider(height: 22, color: Colors.white.withOpacity(0.06)),
                            itemBuilder: (context, index) {
                              final habit = habits[index];
                              final completed = _completionState[habit.id] ?? false;
                              return Dismissible(
                                key: ValueKey(habit.id),
                                direction: DismissDirection.horizontal,
                                confirmDismiss: (direction) async {
                                  if (direction == DismissDirection.startToEnd) {
                                    setState(() => _completionState[habit.id] = !completed);
                                    HapticFeedback.lightImpact();
                                  } else {
                                    _showHabitActions(box, habit);
                                  }
                                  return false;
                                },
                                background: const _SwipeBackground(
                                  icon: Icons.check_rounded,
                                  alignment: Alignment.centerLeft,
                                  startColor: AppColors.success,
                                  endColor: Color(0xFF2FD678),
                                ),
                                secondaryBackground: const _SwipeBackground(
                                  icon: Icons.close_rounded,
                                  alignment: Alignment.centerRight,
                                  startColor: Color(0xFF37207A),
                                  endColor: AppColors.accentSleep,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(kHabitTileRadius),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(kHabitTileRadius),
                                      onTap: () => _showHabitEditor(box: box, habit: habit),
                                      onLongPress: () => _showHabitActions(box, habit),
                                      child: _HabitRow(habit: habit, completed: completed),
                                    ),
                                  ),
                                ),
                              );
                            },
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
  const _HabitEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.iconKey,
    required this.colorArgb,
    required this.category,
    required this.frequency,
    required this.isCountable,
    required this.goalDays,
    required this.isForever,
    required this.startDate,
    required this.activeWeekdays,
    required this.intervalWeeks,
    required this.dayOfMonth,
    required this.adjustToLastDayIfMissing,
    this.sourceTemplateId,
    this.targetCount,
    this.subtitle,
  });

  static _HabitEntry? fromModel(HabitEntry? model) {
    if (model == null) return null;
    return _HabitEntry(
      id: model.id,
      name: model.name,
      createdAt: model.createdAt,
      iconKey: model.iconKey,
      colorArgb: model.colorArgb,
      category: model.category,
      frequency: model.frequency,
      isCountable: model.isCountable,
      goalDays: model.goalDays,
      isForever: model.isForever,
      startDate: model.startDate,
      activeWeekdays: model.activeWeekdays,
      intervalWeeks: model.intervalWeeks,
      dayOfMonth: model.dayOfMonth,
      adjustToLastDayIfMissing: model.adjustToLastDayIfMissing,
      sourceTemplateId: model.sourceTemplateId,
      targetCount: model.targetCount,
      subtitle: model.subtitle,
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final String iconKey;
  final int colorArgb;
  final String category;
  final HabitFrequency frequency;
  final bool isCountable;
  final int? goalDays;
  final bool isForever;
  final DateTime startDate;
  final Set<int> activeWeekdays;
  final int intervalWeeks;
  final int dayOfMonth;
  final bool adjustToLastDayIfMissing;
  final String? sourceTemplateId;
  final int? targetCount;
  final String? subtitle;

  HabitEntry toModel() {
    return HabitEntry(
      id: id,
      name: name,
      iconKey: iconKey,
      colorArgb: colorArgb,
      category: category,
      frequency: frequency,
      isCountable: isCountable,
      goalDays: goalDays,
      isForever: isForever,
      startDate: startDate,
      activeWeekdays: activeWeekdays,
      intervalWeeks: intervalWeeks,
      dayOfMonth: dayOfMonth,
      adjustToLastDayIfMissing: adjustToLastDayIfMissing,
      sourceTemplateId: sourceTemplateId,
      createdAt: createdAt,
      targetCount: targetCount,
      subtitle: subtitle,
    );
  }
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
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.card, border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  const _HeaderPillButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [Icon(icon, color: AppColors.textSecondary, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}

class _HabitRow extends StatefulWidget {
  const _HabitRow({required this.habit, required this.completed});

  final _HabitEntry habit;
  final bool completed;

  @override
  State<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends State<_HabitRow> {
  final GlobalKey<HabitCheckOverlayState> _checkKey = GlobalKey<HabitCheckOverlayState>();
  late bool _wasCompleted;

  @override
  void initState() {
    super.initState();
    _wasCompleted = widget.completed;
  }

  @override
  void didUpdateWidget(covariant _HabitRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wasCompleted && widget.completed) _checkKey.currentState?.play();
    _wasCompleted = widget.completed;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countLabel = widget.habit.isCountable ? '0/${widget.habit.targetCount ?? 1} Contar' : null;
    final frequencyLabel = widget.habit.frequency.label;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.54),
        borderRadius: BorderRadius.circular(kHabitTileRadius),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Stack(children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Color(widget.habit.colorArgb).withOpacity(0.2)),
              child: Icon(iconForKey(widget.habit.iconKey), color: Color(widget.habit.colorArgb), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.habit.name, style: textTheme.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(widget.habit.subtitle ?? '$frequencyLabel · ${widget.habit.category}', style: textTheme.labelMedium?.copyWith(color: AppColors.textMuted)),
                if (countLabel != null) Text(countLabel, style: textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
              ]),
            ),
            Text(widget.completed ? '1' : '0', style: textTheme.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          Positioned.fill(child: Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.only(right: 6), child: HabitCheckOverlay(key: _checkKey)))),
        ]),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.startColor, required this.endColor, required this.icon, required this.alignment});

  final Color startColor;
  final Color endColor;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isLeading = alignment == Alignment.centerLeft;
    final baseOpacity = Theme.of(context).brightness == Brightness.dark ? 0.84 : 0.76;
    return ClipRRect(
      borderRadius: BorderRadius.circular(kHabitTileRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kHabitTileRadius),
          gradient: LinearGradient(
            begin: isLeading ? Alignment.centerLeft : Alignment.centerRight,
            end: isLeading ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              startColor.withOpacity(baseOpacity),
              endColor.withOpacity(baseOpacity + 0.06),
            ],
          ),
        ),
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kSwipeIconHorizontalPadding),
            child: _SwipeIconBubble(icon: icon),
          ),
        ),
      ),
    );
  }
}

class _SwipeIconBubble extends StatelessWidget {
  const _SwipeIconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSwipeIconBubbleSize,
      height: _kSwipeIconBubbleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.95), size: 24),
    );
  }
}

class _ActionSheetItem extends StatelessWidget {
  const _ActionSheetItem({required this.icon, required this.label, required this.onTap, this.iconColor});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}
