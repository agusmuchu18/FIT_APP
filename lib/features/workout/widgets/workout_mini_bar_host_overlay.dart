import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../workout_in_progress_controller.dart';
import 'workout_mini_bar.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class WorkoutMiniBarOverlayController {
  WorkoutMiniBarOverlayController._();

  static const double mainShellBarHeight = 76;
  static final WorkoutMiniBarOverlayController instance = WorkoutMiniBarOverlayController._();

  final ValueNotifier<bool> bottomNavVisible = ValueNotifier(true);
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);

  String? _lastOverlayStateLog;

  bool get shouldHideMiniBar => currentRouteName.value == '/workout/session';

  void updateFromRoute(Route<dynamic>? route) {
    updateFromRouteName(route?.settings.name);
  }

  void updateFromRouteName(String? routeName) {
    if (currentRouteName.value != routeName) {
      currentRouteName.value = routeName;
    }

    // Mantener robustez ante cambios de rutas:
    // por defecto asumimos que la bottom nav está visible, excepto en rutas full-screen.
    const fullScreenRoutesWithoutBottomNav = <String>{
      '/workout/session',
    };
    final showBottomNav = routeName == null || !fullScreenRoutesWithoutBottomNav.contains(routeName);
    if (bottomNavVisible.value != showBottomNav) {
      bottomNavVisible.value = showBottomNav;
    }

    if (kDebugMode) {
      final snapshot =
          'routeName=$routeName|bottomNavVisible=$showBottomNav|shouldHideMiniBar=$shouldHideMiniBar';
      if (_lastOverlayStateLog != snapshot) {
        _lastOverlayStateLog = snapshot;
        debugPrint('[WorkoutMiniBarOverlayController] $snapshot');
      }
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

class WorkoutMiniBarHostOverlay extends StatefulWidget {
  const WorkoutMiniBarHostOverlay({super.key});

  @override
  State<WorkoutMiniBarHostOverlay> createState() => _WorkoutMiniBarHostOverlayState();
}

class _WorkoutMiniBarHostOverlayState extends State<WorkoutMiniBarHostOverlay> {
  static const _animationDuration = Duration(milliseconds: 180);

  bool _didSyncInitialRoute = false;
  String? _lastLayoutLog;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didSyncInitialRoute) {
      return;
    }
    _didSyncInitialRoute = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final routeName = ModalRoute.of(context)?.settings.name;
      WorkoutMiniBarOverlayController.instance.updateFromRouteName(routeName);
    });
  }

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
                final bottomOffset = (bottomNavVisible ? WorkoutMiniBarOverlayController.mainShellBarHeight : 0) + bottomInset + 12;

                if (kDebugMode) {
                  final snapshot =
                      'routeName=${overlayController.currentRouteName.value}|draftNull=${draft == null}|shouldHideMiniBar=${overlayController.shouldHideMiniBar}|bottomNavVisible=$bottomNavVisible|bottomOffset=$bottomOffset';
                  if (_lastLayoutLog != snapshot) {
                    _lastLayoutLog = snapshot;
                    debugPrint('[WorkoutMiniBarHostOverlay] $snapshot');
                  }
                }

                return SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: bottomOffset,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
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
                                      onContinue: () => appNavigatorKey.currentState?.pushNamed('/workout/session'),
                                      onPauseResume: () => draft.isPaused
                                          ? WorkoutInProgressController.instance.resumePausedWorkout()
                                          : WorkoutInProgressController.instance.pause(),
                                      onDiscard: _confirmDiscardDraft,
                                    ),
                            ),
                          ),
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

  Future<void> _confirmDiscardDraft() async {
    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: navigatorContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Descartar entrenamiento'),
        content: const Text('¿Querés descartar el entrenamiento en curso?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Descartar')),
        ],
      ),
    );
    if (confirmed == true) {
      await WorkoutInProgressController.instance.discard();
    }
  }
}
