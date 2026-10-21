import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../workout_in_progress_controller.dart';
import 'workout_mini_bar.dart';
import '../presentation/widgets/workout_units_host.dart';
import '../../../core/data/account_storage_scope.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Widget workoutMiniBarAppBuilder(BuildContext context, Widget? child) {
  return WorkoutUnitsHost(
    key: ValueKey(AccountStorageScope.current),
    child: _WorkoutAppOverlay(child: child),
  );
}

class _WorkoutAppOverlay extends StatefulWidget {
  const _WorkoutAppOverlay({required this.child});

  final Widget? child;

  @override
  State<_WorkoutAppOverlay> createState() => _WorkoutAppOverlayState();
}

class _WorkoutAppOverlayState extends State<_WorkoutAppOverlay> {
  late final OverlayEntry _appEntry = OverlayEntry(
    builder: (_) => widget.child ?? const SizedBox.shrink(),
  );
  late final OverlayEntry _miniBarEntry = OverlayEntry(
    builder: (_) => const WorkoutMiniBarHostOverlay(),
  );

  @override
  void didUpdateWidget(covariant _WorkoutAppOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _appEntry.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _appEntry.remove();
    _miniBarEntry.remove();
    _appEntry.dispose();
    _miniBarEntry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Overlay(initialEntries: [_appEntry, _miniBarEntry]);
}

class WorkoutMiniBarOverlayController {
  WorkoutMiniBarOverlayController._();

  static const double mainShellBarHeight = 76;
  static final WorkoutMiniBarOverlayController instance =
      WorkoutMiniBarOverlayController._();

  final ValueNotifier<bool> bottomNavVisible = ValueNotifier(true);
  final ValueNotifier<String?> currentRouteName = ValueNotifier(null);
  final ValueNotifier<bool> modalVisible = ValueNotifier(false);

  String? _lastOverlayStateLog;

  bool get shouldHideMiniBar =>
      modalVisible.value ||
      !const {'/', '/home', '/workout'}.contains(currentRouteName.value);

  void updateFromRoute(Route<dynamic>? route) {
    updateFromRouteName(route?.settings.name);
  }

  void updateFromRouteName(String? routeName) {
    if (currentRouteName.value != routeName) {
      currentRouteName.value = routeName;
    }

    final showBottomNav = const {'/', '/home'}.contains(routeName);
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
  final _routes = <Route<dynamic>>[];
  void _sync() {
    controller.modalVisible.value = _routes.any((r) => r is PopupRoute);
    controller.updateFromRoute(_routes.whereType<PageRoute>().lastOrNull);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) _routes.clear();
    _routes.add(route);
    _sync();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
    _sync();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _sync();
    super.didRemove(route, previousRoute);
  }
}

class WorkoutMiniBarHostOverlay extends StatefulWidget {
  const WorkoutMiniBarHostOverlay({super.key});

  @override
  State<WorkoutMiniBarHostOverlay> createState() =>
      _WorkoutMiniBarHostOverlayState();
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
      if (routeName != null) {
        WorkoutMiniBarOverlayController.instance.updateFromRouteName(routeName);
      }
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
          builder: (context, bottomNavVisible, _) {
            return ListenableBuilder(
              listenable: Listenable.merge([
                overlayController.currentRouteName,
                overlayController.modalVisible,
              ]),
              builder: (context, _) {
                final hidden =
                    draft == null ||
                    overlayController.shouldHideMiniBar ||
                    MediaQuery.viewInsetsOf(context).bottom > 0;
                final bottomInset = MediaQuery.of(context).padding.bottom;
                final bottomOffset =
                    (bottomNavVisible
                        ? WorkoutMiniBarOverlayController.mainShellBarHeight
                        : 0) +
                    bottomInset +
                    12;

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
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : _animationDuration,
                          offset: hidden ? const Offset(0, 1) : Offset.zero,
                          child: AnimatedOpacity(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : _animationDuration,
                            opacity: hidden ? 0 : 1,
                            child: IgnorePointer(
                              ignoring: hidden,
                              child: draft == null
                                  ? const SizedBox.shrink()
                                  : WorkoutMiniBar(
                                      draft: draft,
                                      onContinue: () => appNavigatorKey
                                          .currentState
                                          ?.pushNamed('/workout/session'),
                                      onPauseResume: () => draft.isPaused
                                          ? WorkoutInProgressController.instance
                                                .resumePausedWorkout()
                                          : WorkoutInProgressController.instance
                                                .pause(),
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
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await WorkoutInProgressController.instance.discard();
    }
  }
}
