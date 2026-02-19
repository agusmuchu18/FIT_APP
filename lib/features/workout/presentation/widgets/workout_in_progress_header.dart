import 'dart:async';
import 'dart:ui';

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
    required this.completedSets,
    required this.totalSets,
    this.collapseProgress = 0,
  });

  final DateTime startTime;
  final double totalVolume;
  final Map<String, double> currentDistribution;
  final Map<String, double>? previousDistribution;
  final int completedSets;
  final int totalSets;
  final double collapseProgress;

  @override
  State<WorkoutInProgressHeader> createState() => _WorkoutInProgressHeaderState();
}

class _WorkoutInProgressHeaderState extends State<WorkoutInProgressHeader> {
  late final ValueNotifier<Duration> _elapsedNotifier;
  Timer? _timer;
  bool _showGlow = true;

  @override
  void initState() {
    super.initState();
    _elapsedNotifier = ValueNotifier(_computeElapsed());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedNotifier.value = _computeElapsed();
      if (_elapsedNotifier.value.inSeconds.isEven) {
        setState(() => _showGlow = !_showGlow);
      }
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
    final progress = widget.totalSets == 0 ? 0.0 : (widget.completedSets / widget.totalSets).clamp(0.0, 1.0);
    final formattedVolume = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag()).format(widget.totalVolume.round());
    final currentValues = WorkoutLiveMetrics.radarMuscles
        .map((muscle) => (widget.currentDistribution[muscle] ?? 0).clamp(0, 1).toDouble())
        .toList();
    final previousValues = widget.previousDistribution == null
        ? null
        : WorkoutLiveMetrics.radarMuscles
            .map((muscle) => (widget.previousDistribution![muscle] ?? 0).clamp(0, 1).toDouble())
            .toList();
    final collapse = Curves.easeOut.transform(widget.collapseProgress.clamp(0, 1));
    final heroHeight = lerpDouble(234, 134, collapse)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      height: heroHeight,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.25,
          colors: [
            accent.withOpacity(0.22),
            theme.colorScheme.surface.withOpacity(0.9),
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.76),
          ],
          stops: const [0.02, 0.52, 1],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 1800),
              opacity: _showGlow ? 0.3 : 0.15,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    center: const Alignment(0.8, -0.8),
                    radius: 1.1,
                    colors: [accent.withOpacity(0.24), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: ValueListenableBuilder<Duration>(
                        valueListenable: _elapsedNotifier,
                        builder: (context, elapsed, _) {
                          return _MetricColumn(
                            label: 'Tiempo',
                            value: _formatElapsed(elapsed),
                            valueStyle: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: lerpDouble(40, 24, collapse),
                              height: 1,
                            ),
                            labelColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                            spacing: 6,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _MetricColumn(
                        label: 'Volumen',
                        labelColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        spacing: 6,
                        valueWidget: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                          child: Text(
                            '$formattedVolume kg',
                            key: ValueKey(formattedVolume),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: lerpDouble(28, 18, collapse),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeOut,
                      child: collapse > 0.55
                          ? const SizedBox.shrink()
                          : SizedBox(
                              key: const ValueKey('radar'),
                              width: 130,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: TweenAnimationBuilder<double>(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      tween: Tween<double>(begin: 0, end: 1),
                                      builder: (context, value, _) {
                                        final animatedCurrent = currentValues.map((point) => point * value).toList();
                                        final animatedPrevious = previousValues?.map((point) => point * value).toList();
                                        return CustomPaint(
                                          painter: RadarChartPainter(
                                            labels: WorkoutLiveMetrics.radarMuscles,
                                            currentValues: animatedCurrent,
                                            previousValues: animatedPrevious,
                                            accentColor: accent,
                                          ),
                                          child: const SizedBox.expand(),
                                        );
                                      },
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
                    ),
                  ],
                ),
              ),
              if (collapse < 0.9) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.completedSets} de ${widget.totalSets} series completadas',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.75),
                    valueColor: AlwaysStoppedAnimation<Color>(accent.withOpacity(0.92)),
                  ),
                ),
              ],
            ],
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
    required this.labelColor,
    this.spacing = 4,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final TextStyle? valueStyle;
  final Color labelColor;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: labelColor)),
        SizedBox(height: spacing),
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
