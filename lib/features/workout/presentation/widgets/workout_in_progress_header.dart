import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/workout_live_metrics.dart';
import 'radar_chart_painter.dart';

class WorkoutInProgressHeader extends StatefulWidget {
  const WorkoutInProgressHeader({
    super.key,
    required this.startTime,
    required this.totalVolume,
    required this.currentDistribution,
    this.previousDistribution,
  });

  final DateTime startTime;
  final double totalVolume;
  final Map<String, double> currentDistribution;
  final Map<String, double>? previousDistribution;

  @override
  State<WorkoutInProgressHeader> createState() => _WorkoutInProgressHeaderState();
}

class _WorkoutInProgressHeaderState extends State<WorkoutInProgressHeader> {
  late final ValueNotifier<Duration> _elapsedNotifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _elapsedNotifier = ValueNotifier(_computeElapsed());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedNotifier.value = _computeElapsed();
    });
  }

  @override
  void didUpdateWidget(covariant WorkoutInProgressHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime) {
      _elapsedNotifier.value = _computeElapsed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsedNotifier.dispose();
    super.dispose();
  }

  Duration _computeElapsed() {
    final diff = DateTime.now().difference(widget.startTime);
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final formattedVolume = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(widget.totalVolume.round());
    final currentValues = WorkoutLiveMetrics.radarMuscles
        .map((muscle) => (widget.currentDistribution[muscle] ?? 0).clamp(0, 1).toDouble())
        .toList();
    final previousValues = widget.previousDistribution == null
        ? null
        : WorkoutLiveMetrics.radarMuscles
            .map((muscle) => (widget.previousDistribution![muscle] ?? 0).clamp(0, 1).toDouble())
            .toList();

    return Container(
      height: 206,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.surface.withOpacity(0.85),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ValueListenableBuilder<Duration>(
              valueListenable: _elapsedNotifier,
              builder: (context, elapsed, _) {
                return _MetricColumn(
                  label: 'Tiempo',
                  value: _formatElapsed(elapsed),
                  valueStyle: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _MetricColumn(
              label: 'Volumen',
              valueWidget: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: Text(
                  '$formattedVolume kg',
                  key: ValueKey(formattedVolume),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: RadarChartPainter(
                      labels: WorkoutLiveMetrics.radarMuscles,
                      currentValues: currentValues,
                      previousValues: previousValues,
                      accentColor: accent,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  previousValues == null ? 'Actual' : 'Actual / Anterior',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueStyle,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        valueWidget ??
            Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: valueStyle ?? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
      ],
    );
  }
}
