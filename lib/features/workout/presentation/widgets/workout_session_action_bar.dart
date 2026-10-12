import 'package:flutter/material.dart';

import '../../../common/theme/app_layout.dart';
import '../../../common/widgets/fit_glyph.dart';
import '../../application/workout_session_controller.dart';
import 'rest_timer_banner.dart';

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
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
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
              RestTimerBanner(controller: controller),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
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
                  children: [
                    controller.isFinishing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : FitGlyph(
                            kind: finalize
                                ? FitGlyphKind.check
                                : FitGlyphKind.add,
                          ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        controller.isFinishing
                            ? 'Guardando entrenamiento…'
                            : finalize
                            ? 'Finalizar entrenamiento'
                            : 'Agregar ejercicio',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (finalize && controller.canEdit)
              TextButton.icon(
                onPressed: onAdd,
                icon: const FitGlyph(kind: FitGlyphKind.add),
                label: const Text('Agregar ejercicio'),
              ),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              children: [
                TextButton.icon(
                  onPressed: controller.canEdit ? onPause : null,
                  icon: Icon(
                    controller.isPaused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(
                    controller.isPaused ? 'Reanudar sesión' : 'Pausar sesión',
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de sesión',
                  enabled: !controller.isFinishing,
                  onSelected: (action) {
                    switch (action) {
                      case 'finish':
                        onFinish();
                      case 'settings':
                        onSettings();
                      case 'discard':
                        onDiscard();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'finish',
                      enabled: controller.completedSets > 0,
                      child: const Text('Finalizar anticipadamente'),
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
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Más opciones'),
                        SizedBox(width: AppSpacing.xs),
                        FitGlyph(kind: FitGlyphKind.chevronDown),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
