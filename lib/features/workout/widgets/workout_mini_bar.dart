import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../common/theme/app_colors.dart';
import '../workout_in_progress_controller.dart';

class WorkoutMiniBar extends StatefulWidget {
  const WorkoutMiniBar({
    super.key,
    required this.draft,
    required this.onContinue,
    required this.onPauseResume,
    required this.onDiscard,
  });

  final WorkoutInProgressDraft draft;
  final VoidCallback onContinue;
  final VoidCallback onPauseResume;
  final VoidCallback onDiscard;

  @override
  State<WorkoutMiniBar> createState() => _WorkoutMiniBarState();
}

class _WorkoutMiniBarState extends State<WorkoutMiniBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _configureTicker();
  }

  @override
  void didUpdateWidget(covariant WorkoutMiniBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.isPaused != widget.draft.isPaused) {
      _configureTicker();
    }
  }

  void _configureTicker() {
    _ticker?.cancel();
    if (widget.draft.isPaused) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final elapsed = _elapsed(widget.draft);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onContinue,
        borderRadius: BorderRadius.circular(20),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? colorScheme.primary.withOpacity(0.06)
              : colorScheme.primary.withOpacity(0.03),
        ),
        child: Ink(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.14),
                ),
                child: const Icon(Icons.fitness_center, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entrenamiento en curso',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _format(elapsed),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (widget.draft.isPaused) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: colorScheme.secondary.withOpacity(0.15),
                            ),
                            child: Text(
                              'Pausado',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: widget.draft.isPaused ? 'Reanudar' : 'Pausar',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onPauseResume,
                    icon: Icon(widget.draft.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  ),
                  IconButton(
                    tooltip: 'Descartar',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDiscard,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Duration _elapsed(WorkoutInProgressDraft draft) {
    final now = draft.isPaused ? (draft.pausedAt ?? DateTime.now()) : DateTime.now();
    final value = now.difference(draft.startTime) - draft.accumulatedPaused;
    return value.isNegative ? Duration.zero : value;
  }

  String _format(Duration duration) {
    final total = duration.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
