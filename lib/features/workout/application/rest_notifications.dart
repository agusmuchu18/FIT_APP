import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Schedules the "rest is over" alert while the app is in the background.
///
/// In the foreground the session screen (or the mini bar) vibrates and plays
/// a sound itself, so the notification exists only for a locked phone or
/// another app in front. Every failure is swallowed: recording a workout must
/// never depend on notifications.
abstract class RestNotifier {
  /// Asks for notification permission once, the first time a rest starts.
  Future<void> ensurePermission();
  Future<void> scheduleRestEnd(Duration remaining, {String? workoutName});
  Future<void> cancelRestEnd();
}

class RestNotifications {
  const RestNotifications._();

  /// Replaceable in tests.
  static RestNotifier instance = LocalRestNotifier();
}

class LocalRestNotifier implements RestNotifier {
  LocalRestNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 7301;
  static const _permissionAskedKey = 'rest_notifications_permission_asked_v1';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _initialization;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<bool> _initialize() {
    return _initialization ??= _plugin
        .initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            // Permission is requested explicitly at the first rest instead.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false,
            ),
          ),
        )
        .then((ready) => ready ?? false)
        .catchError((Object _) {
          _initialization = null;
          return false;
        });
  }

  @override
  Future<void> ensurePermission() async {
    if (!_supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_permissionAskedKey) ?? false) return;
      await prefs.setBool(_permissionAskedKey, true);
      if (!await _initialize()) return;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true);
      }
    } catch (_) {
      // Without permission the in-app alert still works.
    }
  }

  @override
  Future<void> scheduleRestEnd(
    Duration remaining, {
    String? workoutName,
  }) async {
    if (!_supported || remaining <= Duration.zero) return;
    try {
      if (!await _initialize()) return;
      var mode = AndroidScheduleMode.inexactAllowWhileIdle;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final exact = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications();
        if (exact ?? false) mode = AndroidScheduleMode.exactAllowWhileIdle;
      }
      final name = workoutName?.trim();
      await _plugin.zonedSchedule(
        id: _notificationId,
        // An absolute instant: no time-zone database is needed.
        scheduledDate: tz.TZDateTime.now(tz.UTC).add(remaining),
        title: 'Descanso terminado',
        body: name == null || name.isEmpty
            ? 'Seguí con tu próxima serie.'
            : 'Seguí con tu próxima serie de $name.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            'Descanso entre series',
            channelDescription: 'Avisa cuando termina el descanso.',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.active,
          ),
        ),
        androidScheduleMode: mode,
      );
    } catch (_) {
      // The rest still ends in the app; only the background alert is lost.
    }
  }

  @override
  Future<void> cancelRestEnd() async {
    if (!_supported || _initialization == null) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {
      // Nothing scheduled or the plugin is unavailable: nothing to cancel.
    }
  }
}
