import 'package:flutter/material.dart';

import '../workout_in_progress_controller.dart';
import 'workout_mini_bar.dart';

class WorkoutMiniBarOverlayController {
  WorkoutMiniBarOverlayController._();

  static const double mainShellBarHeight = 76;
  static final WorkoutMiniBarOverlayController instance = WorkoutMiniBarOverlayController._();

  final ValueNotifier<bool> bottomNavVisible = ValueNotifier(false);
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);

  bool get shouldHideMiniBar => currentRouteName.value == '/workout/session';

  void updateFromRoute(Route<dynamic>? route) {
    final routeName = route?.settings.name;
    if (currentRouteName.value != routeName) {
      currentRouteName.value = routeName;
    }
    final showBottomNav = routeName == '/home';
    if (bottomNavVisible.value != showBottomNav) {
      bottomNavVisible.value = showBottomNav;
    }
  }
}

class WorkoutMiniBarRouteObserver extends NavigatorObserver {
  WorkoutMiniBarRouteObserver();

  final controller = WorkoutMiniBarOverlayController.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.updateFromRoute(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.updateFromRoute(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    controller.updateFromRoute(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.updateFromRoute(previousRoute);
    super.didRemove(route, previousRoute);
  }
}

class WorkoutMiniBarHostOverlay extends StatelessWidget {
  const WorkoutMiniBarHostOverlay({super.key});

  static const _animationDuration = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final overlayController = WorkoutMiniBarOverlayController.instance;

    return ValueListenableBuilder<WorkoutInProgressDraft?>(
      valueListenable: WorkoutInProgressController.instance.watchDraft(),
      builder: (context, draft, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: overlayController.bottomNavVisible,
          builder: (context, bottomNavVisible, __) {
            return ValueListenableBuilder<String?>(
              valueListenable: overlayController.currentRouteName,
              builder: (context, _, ___) {
                final hidden = draft == null || overlayController.shouldHideMiniBar;
                final bottomInset = MediaQuery.of(context).padding.bottom;
                final bottomOffset = bottomInset + (bottomNavVisible ? WorkoutMiniBarOverlayController.mainShellBarHeight : 12) + 12;

                return Positioned(
                  left: 20,
                  right: 20,
                  bottom: bottomOffset,
                  child: AnimatedSlide(
                    duration: _animationDuration,
                    offset: hidden ? const Offset(0, 1) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: _animationDuration,
                      opacity: hidden ? 0 : 1,
                      child: IgnorePointer(
                        ignoring: hidden,
                        child: draft == null
                            ? const SizedBox.shrink()
                            : WorkoutMiniBar(
                                draft: draft,
                                onContinue: () => Navigator.of(context).pushNamed('/workout/session'),
                                onPauseResume: () => draft.isPaused
                                    ? WorkoutInProgressController.instance.resume()
                                    : WorkoutInProgressController.instance.pause(),
                                onDiscard: () => _confirmDiscardDraft(context),
                              ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDiscardDraft(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar entrenamiento'),
        content: const Text('¿Querés descartar el entrenamiento en curso?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmed == true) {
      await WorkoutInProgressController.instance.discard();
    }
  }
}
