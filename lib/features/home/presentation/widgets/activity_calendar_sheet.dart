import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/home_activity_utils.dart';

class ActivityCalendarSheet extends StatefulWidget {
  const ActivityCalendarSheet({
    super.key,
    required this.activeDays,
    required this.initialSelectedDay,
  });

  final Set<DateTime> activeDays;
  final DateTime initialSelectedDay;

  static Future<DateTime?> show(
    BuildContext context, {
    required Set<DateTime> activeDays,
    required DateTime initialSelectedDay,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ActivityCalendarSheet(
        activeDays: activeDays,
        initialSelectedDay: initialSelectedDay,
      ),
    );
  }

  @override
  State<ActivityCalendarSheet> createState() => _ActivityCalendarSheetState();
}

class _ActivityCalendarSheetState extends State<ActivityCalendarSheet> {
  late DateTime _selectedDay;
  late DateTime _focusedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = normalizeDay(widget.initialSelectedDay);
    _focusedDay = _selectedDay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF111B2E).withOpacity(0.94),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TableCalendar<void>(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2100),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                      availableGestures: AvailableGestures.horizontalSwipe,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      eventLoader: (day) {
                        final hasEvents = hasActivity(day: day, activeDays: widget.activeDays);
                        return hasEvents ? const [Object()] : const [];
                      },
                      onDaySelected: (selectedDay, focusedDay) {
                        final normalized = normalizeDay(selectedDay);
                        setState(() {
                          _selectedDay = normalized;
                          _focusedDay = focusedDay;
                        });
                        Navigator.of(context).pop(normalized);
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      calendarStyle: CalendarStyle(
                        defaultTextStyle: const TextStyle(color: Colors.white),
                        weekendTextStyle: const TextStyle(color: Colors.white),
                        outsideTextStyle:
                            TextStyle(color: Colors.white.withOpacity(0.42)),
                        selectedDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.6),
                        ),
                        todayDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.secondary.withOpacity(0.32),
                        ),
                        markersMaxCount: 1,
                        markerDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
                        titleTextStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                        weekendStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          return _CalendarDayCell(
                            day: day,
                            hasActivity: hasActivity(day: day, activeDays: widget.activeDays),
                            isSelected: isSameDay(day, _selectedDay),
                            isToday: isSameDay(day, DateTime.now()),
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _CalendarDayCell(
                            day: day,
                            hasActivity: hasActivity(day: day, activeDays: widget.activeDays),
                            isSelected: isSameDay(day, _selectedDay),
                            isToday: true,
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _CalendarDayCell(
                            day: day,
                            hasActivity: hasActivity(day: day, activeDays: widget.activeDays),
                            isSelected: true,
                            isToday: isSameDay(day, DateTime.now()),
                          );
                        },
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
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.hasActivity,
    required this.isSelected,
    required this.isToday,
  });

  final DateTime day;
  final bool hasActivity;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color borderColor = Colors.transparent;
    if (hasActivity) {
      borderColor = Colors.white.withOpacity(0.65);
    }
    if (isSelected) {
      borderColor = theme.colorScheme.secondary;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: hasActivity || isSelected ? 1.4 : 0),
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.46)
            : isToday
                ? theme.colorScheme.secondary.withOpacity(0.16)
                : Colors.transparent,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
