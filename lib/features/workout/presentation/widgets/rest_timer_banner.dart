import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/workout_session_controller.dart';
import '../../../common/theme/app_layout.dart';

class RestTimerBanner extends StatefulWidget {
  const RestTimerBanner({super.key, required this.controller});

  final WorkoutSessionController controller;

  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner>
    with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTicker();
      if (mounted) setState(() {});
    } else {
      _ticker?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final remaining = controller.restRemainingAt(DateTime.now());
    final seconds = remaining.inSeconds;
    final label = seconds == 0
        ? 'Descanso completo'
        : 'Descanso · ${_twoDigits(seconds ~/ 60)}:${_twoDigits(seconds % 60)}';
    final total = controller.restDurationSeconds;
    final progress = total > 0 ? (1 - seconds / total).clamp(0.0, 1.0) : 1.0;
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppShape.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (controller.isPaused) const Text('En pausa'),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            label: 'Progreso del descanso',
            child: LinearProgressIndicator(value: progress),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: controller.extendRest,
                child: const Text('+30 s'),
              ),
              TextButton(
                onPressed: controller.skipRest,
                child: const Text('Saltar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
