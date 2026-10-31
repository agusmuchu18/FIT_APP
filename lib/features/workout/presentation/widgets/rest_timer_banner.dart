import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/rest_notifications.dart';
import '../../application/workout_session_controller.dart';
import '../../../common/theme/app_layout.dart';

class RestTimerBanner extends StatefulWidget {
  const RestTimerBanner({super.key, required this.controller});

  final WorkoutSessionController controller;

  /// How long "Descanso completo" stays visible before it closes itself.
  static const autoDismissDelay = Duration(seconds: 3);

  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner>
    with WidgetsBindingObserver {
  Timer? _ticker;
  Timer? _dismiss;
  String? _alertedKey;
  String? _warnedKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    // The first rest is the moment the notification makes sense to the user.
    unawaited(RestNotifications.instance.ensurePermission());
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final controller = widget.controller;
    if (controller.hasActiveRest && !controller.isPaused) {
      final key = controller.restKey;
      final seconds = controller.restRemainingAt(DateTime.now()).inSeconds;
      if (seconds <= 3 && seconds > 0 && _warnedKey != key) {
        _warnedKey = key;
        _feedback(HapticFeedback.lightImpact);
      }
      if (seconds == 0 && _alertedKey != key) {
        _alertedKey = key;
        _feedback(HapticFeedback.heavyImpact);
        _feedback(() => SystemSound.play(SystemSoundType.alert));
        _dismiss?.cancel();
        _dismiss = Timer(RestTimerBanner.autoDismissDelay, () {
          if (!mounted) return;
          final current = widget.controller;
          if (current.hasActiveRest &&
              current.restKey == key &&
              current.restRemainingAt(DateTime.now()) == Duration.zero) {
            current.skipRest();
          }
        });
      }
    }
    setState(() {});
  }

  void _feedback(Future<void> Function() call) {
    unawaited(call().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dismiss?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTicker();
      _tick();
    } else {
      _ticker?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final remaining = controller.restRemainingAt(DateTime.now());
    final seconds = remaining.inSeconds;
    final finished = seconds == 0;
    final label = finished
        ? 'Descanso completo'
        : '${_twoDigits(seconds ~/ 60)}:${_twoDigits(seconds % 60)}';
    final total = controller.restDurationSeconds;
    final progress = total > 0 ? (1 - seconds / total).clamp(0.0, 1.0) : 1.0;
    final colors = Theme.of(context).colorScheme;
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final source = controller.restSourceExerciseName;

    final title = Semantics(
      liveRegion: finished,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    final subtitle = controller.isPaused
        ? 'Descanso en pausa'
        : finished
        ? 'Seguí con la próxima serie'
        : source == null
        ? 'Descanso'
        : 'Descanso · $source';
    final buttons = [
      TextButton(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: finished ? null : () => controller.adjustRest(-15),
        child: const Text('−15 s'),
      ),
      TextButton(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: () => controller.adjustRest(15),
        child: const Text('+15 s'),
      ),
      TextButton(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: controller.skipRest,
        child: Text(finished ? 'Cerrar' : 'Saltar'),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: finished ? colors.tertiaryContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppShape.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (enlarged) ...[
            title,
            Text(subtitle),
            Wrap(spacing: 4, runSpacing: 4, children: buttons),
          ] else
            Row(
              children: [
                Icon(
                  finished ? Icons.notifications_active : Icons.timer_outlined,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                ...buttons,
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Semantics(
              label: 'Progreso del descanso',
              child: LinearProgressIndicator(value: progress),
            ),
          ),
        ],
      ),
    );
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
