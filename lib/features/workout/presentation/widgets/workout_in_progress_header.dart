import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'workout_units_host.dart';

import 'package:intl/intl.dart';

import '../../domain/workout_live_metrics.dart';
import 'radar_chart_painter.dart';

String formatVolume(num value) {
  if (value < 10000) {
    return NumberFormat('#,###', 'en_US').format(value.round());
  }
  if (value < 100000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  if (value < 1000000) {
    return '${(value / 1000).round()}K';
  }
  return '${(value / 1000000).toStringAsFixed(1)}M';
}

class WorkoutInProgressHeader extends StatefulWidget {
  const WorkoutInProgressHeader({
    super.key,
    required this.startTime,
    this.isPaused = false,
    this.pausedAt,
    this.accumulatedPaused = Duration.zero,
    required this.totalVolume,
    required this.currentDistribution,
    this.previousDistribution,
    required this.completedSets,
    required this.totalSets,
    this.collapseProgress = 0,
  });

  final DateTime startTime;
  final bool isPaused;
  final DateTime? pausedAt;
  final Duration accumulatedPaused;
  final double totalVolume;
  final Map<String, double> currentDistribution;
  final Map<String, double>? previousDistribution;
  final int completedSets;
  final int totalSets;
  final double collapseProgress;

  @override
  State<WorkoutInProgressHeader> createState() =>
      _WorkoutInProgressHeaderState();
}

class _WorkoutInProgressHeaderState extends State<WorkoutInProgressHeader>
    with WidgetsBindingObserver {
  late final ValueNotifier<Duration> _elapsedNotifier;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _elapsedNotifier = ValueNotifier(_computeElapsed());
    _startClock();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedNotifier.value = _computeElapsed();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _elapsedNotifier.value = _computeElapsed();
      _startClock();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutInProgressHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startTime != widget.startTime ||
        oldWidget.isPaused != widget.isPaused ||
        oldWidget.pausedAt != widget.pausedAt ||
        oldWidget.accumulatedPaused != widget.accumulatedPaused) {
      _elapsedNotifier.value = _computeElapsed();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _elapsedNotifier.dispose();
    super.dispose();
  }

  Duration _computeElapsed() {
    final end = widget.isPaused
        ? (widget.pausedAt ?? DateTime.now())
        : DateTime.now();
    final diff = end.difference(widget.startTime) - widget.accumulatedPaused;
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final progress = widget.totalSets == 0
        ? 0.0
        : (widget.completedSets / widget.totalSets).clamp(0.0, 1.0);
    final formattedVolume = WorkoutUnits.of(context)
        .valueWithUnit('kg·rep', widget.totalVolume);
    final currentValues = WorkoutLiveMetrics.radarMuscles
        .map(
          (muscle) =>
              (widget.currentDistribution[muscle] ?? 0).clamp(0, 1).toDouble(),
        )
        .toList();
    final previousValues = widget.previousDistribution == null
        ? null
        : WorkoutLiveMetrics.radarMuscles
              .map(
                (muscle) => (widget.previousDistribution![muscle] ?? 0)
                    .clamp(0, 1)
                    .toDouble(),
              )
              .toList();
    final collapse = Curves.easeOut.transform(
      widget.collapseProgress.clamp(0, 1),
    );
    final heroHeight = lerpDouble(234, 134, collapse)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (MediaQuery.sizeOf(context).width < 400 ||
        MediaQuery.textScalerOf(context).scale(16) > 20) {
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: _elapsedNotifier,
                builder: (_, elapsed, _) => Text(
                  '${widget.isPaused ? 'En pausa' : 'Tiempo activo'} · ${_formatElapsed(elapsed)}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              Text('Volumen externo · $formattedVolume'),
              const SizedBox(height: 12),
              Text(
                '${widget.completedSets} de ${widget.totalSets} series completadas',
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                semanticsLabel: 'Progreso de series',
              ),
              if (collapse < .55) ...[
                const SizedBox(height: 12),
                Center(
                  child: _radar(context, currentValues, previousValues, accent),
                ),
                const Text(
                  'Distribución estimada; no mide activación muscular.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 240),
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
            accent.withValues(alpha: 0.22),
            theme.colorScheme.surface.withValues(alpha: 0.9),
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.76),
          ],
          stops: const [0.02, 0.52, 1],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 1800),
              opacity: 0.25,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    center: const Alignment(0.8, -0.8),
                    radius: 1.1,
                    colors: [
                      accent.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
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
                            labelColor: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                            spacing: 6,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricColumn(
                        label: 'Carga externa',
                        labelColor: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.7),
                        spacing: 6,
                        valueWidget: AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 280),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            formattedVolume,
                            key: ValueKey(formattedVolume),
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: lerpDouble(28, 18, collapse),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130,
                      child: AnimatedSwitcher(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeOut,
                        child: collapse > 0.55
                            ? const SizedBox.shrink()
                            : Column(
                                key: const ValueKey('radar'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: TweenAnimationBuilder<double>(
                                      duration: reduceMotion
                                          ? Duration.zero
                                          : const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                      tween: Tween<double>(begin: 0, end: 1),
                                      builder: (context, value, _) {
                                        final animatedCurrent = currentValues
                                            .map((point) => point * value)
                                            .toList();
                                        final animatedPrevious = previousValues
                                            ?.map((point) => point * value)
                                            .toList();
                                        return RepaintBoundary(
                                          child: CustomPaint(
                                            painter: RadarChartPainter(
                                              labels: WorkoutLiveMetrics
                                                  .radarMuscles,
                                              currentValues: animatedCurrent,
                                              previousValues: animatedPrevious,
                                              accentColor: accent,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    previousValues == null
                                        ? 'Estimado · actual'
                                        : 'Estimado · actual / previo',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
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
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.85,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.75),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      accent.withValues(alpha: 0.92),
                    ),
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

  Widget _radar(
    BuildContext context,
    List<double> current,
    List<double>? previous,
    Color accent,
  ) {
    final label = WorkoutLiveMetrics.radarMuscles
        .map(
          (muscle) =>
              '$muscle: ${((widget.currentDistribution[muscle] ?? 0) * 100).round()}%',
        )
        .join(', ');
    return Semantics(
      label: 'Distribución muscular estimada. $label',
      child: RepaintBoundary(
        child: SizedBox(
          width: 190,
          height: 170,
          child: CustomPaint(
            painter: RadarChartPainter(
              labels: WorkoutLiveMetrics.radarMuscles,
              currentValues: current,
              previousValues: previous,
              accentColor: accent,
            ),
          ),
        ),
      ),
    );
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
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: labelColor),
        ),
        SizedBox(height: spacing),
        valueWidget ??
            Text(
              value ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  valueStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
      ],
    );
  }
}
