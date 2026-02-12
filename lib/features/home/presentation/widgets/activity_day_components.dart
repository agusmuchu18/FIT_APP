import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../common/theme/app_colors.dart';

enum ActivityModuleType {
  workout,
  meal,
  sleep,
}

extension ActivityModuleTypeX on ActivityModuleType {
  String get label {
    switch (this) {
      case ActivityModuleType.workout:
        return 'Entrenamiento';
      case ActivityModuleType.meal:
        return 'Alimentación';
      case ActivityModuleType.sleep:
        return 'Sueño';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityModuleType.workout:
        return Icons.fitness_center_rounded;
      case ActivityModuleType.meal:
        return Icons.restaurant_menu_rounded;
      case ActivityModuleType.sleep:
        return Icons.nightlight_round;
    }
  }

  Color get color {
    switch (this) {
      case ActivityModuleType.workout:
        return AppColors.accentTraining;
      case ActivityModuleType.meal:
        return AppColors.accentFood;
      case ActivityModuleType.sleep:
        return AppColors.accentSleep;
    }
  }
}

class ActivityModuleTile extends StatelessWidget {
  const ActivityModuleTile({
    super.key,
    required this.module,
    required this.subtitle,
    required this.count,
    required this.hasActivity,
    required this.onTap,
  });

  final ActivityModuleType module;
  final String subtitle;
  final int count;
  final bool hasActivity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textOpacity = hasActivity ? 1.0 : 0.62;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surface.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: SizedBox(
            height: 92,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: module.color.withOpacity(0.20),
                    ),
                    child: Icon(module.icon, color: module.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                module.label,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.white.withOpacity(textOpacity),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            if (hasActivity)
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: module.color.withOpacity(0.20),
                                    border: Border.all(
                                      color: module.color.withOpacity(0.45),
                                    ),
                                  ),
                                  child: Text(
                                    '$count',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: module.color,
                                          fontWeight: FontWeight.w800,
                                          height: 1,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary.withOpacity(textOpacity),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.60),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TimelineEvent {
  const TimelineEvent({
    required this.module,
    required this.description,
    required this.timeLabel,
    this.orderDate,
  });

  final ActivityModuleType module;
  final String description;
  final String timeLabel;
  final DateTime? orderDate;
}

class ActivityTimelineSection extends StatelessWidget {
  const ActivityTimelineSection({
    super.key,
    required this.events,
  });

  final List<TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline del día',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          Text(
            'No hay eventos registrados este día.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          )
        else
          ...List.generate(
            events.length,
            (index) {
              final event = events[index];
              final isLast = index == events.length - 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: event.module.color.withOpacity(0.20),
                            ),
                            child: Icon(
                              event.module.icon,
                              size: 12,
                              color: event.module.color,
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 1.5,
                              height: 28,
                              margin: const EdgeInsets.only(top: 6),
                              color: Colors.white.withOpacity(0.08),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.timeLabel,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              event.description,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class ModuleStatsHeader extends StatelessWidget {
  const ModuleStatsHeader({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        children.length,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == children.length - 1 ? 0 : 16),
          child: children[index],
        ),
      ),
    );
  }
}

class GlassStatCard extends StatelessWidget {
  const GlassStatCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class RingStat extends StatelessWidget {
  const RingStat({
    super.key,
    required this.progress,
    required this.color,
    required this.value,
    required this.label,
    this.size = 106,
  });

  final double progress;
  final Color color;
  final String value;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        tween: Tween<double>(begin: 0, end: safeProgress),
        builder: (context, valueProgress, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 9,
                valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.15)),
                backgroundColor: Colors.transparent,
              ),
              CircularProgressIndicator(
                value: valueProgress,
                strokeWidth: 9,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                backgroundColor: Colors.transparent,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      this.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.label,
    required this.trailing,
    required this.color,
    this.height = 10,
  });

  final double value;
  final String label;
  final String trailing;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              trailing,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Container(
            height: height,
            color: Colors.white.withOpacity(0.12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: safeValue,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(height),
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.85),
                        Color.lerp(color, Colors.white, 0.2) ?? color,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class EmptyModuleState extends StatelessWidget {
  const EmptyModuleState({
    super.key,
    required this.message,
    required this.ctaLabel,
    required this.onCtaTap,
  });

  final String message;
  final String ctaLabel;
  final VoidCallback onCtaTap;

  @override
  Widget build(BuildContext context) {
    return GlassStatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onCtaTap,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class DayRecordTile extends StatelessWidget {
  const DayRecordTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String fallbackTimeLabelForModule(ActivityModuleType module) {
  switch (module) {
    case ActivityModuleType.workout:
      return 'Sin hora · entreno';
    case ActivityModuleType.meal:
      return 'Sin hora · comida';
    case ActivityModuleType.sleep:
      return 'Sin hora · sueño';
  }
}

DateTime? parseEntryDate(String rawId) {
  final parsed = DateTime.tryParse(rawId);
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}

String formatTimeLabel(DateTime? date) {
  if (date == null) return '';
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String formatDateChipText(DateTime date) {
  const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  final capWeekday = '${weekday[0].toUpperCase()}${weekday.substring(1)}';
  final capMonth = '${month[0].toUpperCase()}${month.substring(1)}';
  return '$capWeekday, ${date.day} $capMonth';
}

String formatDateLong(DateTime date) {
  const weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
}

List<TimelineEvent> sortTimeline(List<TimelineEvent> events) {
  final list = List<TimelineEvent>.from(events);
  list.sort((a, b) {
    if (a.orderDate == null && b.orderDate == null) return 0;
    if (a.orderDate == null) return 1;
    if (b.orderDate == null) return -1;
    return a.orderDate!.compareTo(b.orderDate!);
  });
  return list;
}

double percentage(int current, int target) {
  if (target <= 0) return 0;
  return (current / target).clamp(0.0, 1.0);
}

double percentageDouble(double current, double target) {
  if (target <= 0) return 0;
  return (current / target).clamp(0.0, 1.0);
}

String compactNumber(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.05) {
    return rounded.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

double average(List<int> values) {
  if (values.isEmpty) return 0;
  final sum = values.reduce((a, b) => a + b);
  return sum / math.max(1, values.length);
}
