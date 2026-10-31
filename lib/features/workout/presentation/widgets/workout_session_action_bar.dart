import 'package:flutter/material.dart';

import '../../../common/theme/app_layout.dart';
import '../../../common/widgets/fit_glyph.dart';
import '../../application/workout_session_controller.dart';
import 'rest_timer_banner.dart';

/// Bottom controls: rest timer, one primary action and compact secondaries.
/// Finishing early lives in the app bar, always one tap away.
class WorkoutSessionActionBar extends StatelessWidget {
  const WorkoutSessionActionBar({
    super.key,
    required this.controller,
    required this.onAdd,
    required this.onFinish,
    required this.onPause,
    required this.onSettings,
    required this.onDiscard,
  });
  final WorkoutSessionController controller;
  final VoidCallback onAdd, onFinish, onPause, onSettings, onDiscard;

  @override
  Widget build(BuildContext context) {
    final finalize =
        controller.allSetsCompleted || controller.completionNeedsRecovery;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.hasActiveRest)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: RestTimerBanner(controller: controller),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppShape.control),
                      ),
                    ),
                    onPressed: controller.isFinishing
                        ? null
                        : finalize
                        ? onFinish
                        : controller.canEdit
                        ? onAdd
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        controller.isFinishing
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : FitGlyph(
                                kind: finalize
                                    ? FitGlyphKind.check
                                    : FitGlyphKind.add,
                              ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            controller.isFinishing
                                ? 'Guardando entrenamiento…'
                                : finalize
                                ? 'Finalizar entrenamiento'
                                : 'Agregar ejercicio',
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  tooltip: controller.isPaused
                      ? 'Reanudar sesión'
                      : 'Pausar sesión',
                  onPressed: controller.canEdit ? onPause : null,
                  icon: Icon(
                    controller.isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  enabled: !controller.isFinishing,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case 'add':
                        onAdd();
                      case 'settings':
                        onSettings();
                      case 'discard':
                        onDiscard();
                    }
                  },
                  itemBuilder: (_) => [
                    if (finalize)
                      PopupMenuItem(
                        value: 'add',
                        enabled: controller.canEdit,
                        child: const Text('Agregar ejercicio'),
                      ),
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Configuración'),
                    ),
                    PopupMenuItem(
                      value: 'discard',
                      enabled: controller.canEdit,
                      child: Text(
                        'Descartar sesión',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
