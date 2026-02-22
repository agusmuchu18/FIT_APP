import 'package:shared_preferences/shared_preferences.dart';

enum AppAppearanceMode { classic, dark, light, pink }
enum ProgressVisibilityMode { privateOnly, groupShared }
enum AppTextSize { small, normal, large }

class AppPreferences {
  AppPreferences._(this._prefs);

  static const String _appearanceKey = 'app.appearance_mode';
  static const String _notificationsEnabledKey = 'app.notifications.enabled';
  static const String _habitReminderKey = 'app.notifications.habit';
  static const String _workoutReminderKey = 'app.notifications.workout';
  static const String _sleepReminderKey = 'app.notifications.sleep';
  static const String _dailySummaryKey = 'app.notifications.daily_summary';
  static const String _biometricKey = 'app.security.biometric_pin';
  static const String _progressVisibilityKey = 'app.privacy.progress_visibility';
  static const String _textSizeKey = 'app.accessibility.text_size';
  static const String _highContrastKey = 'app.accessibility.high_contrast';
  static const String _reduceAnimationsKey = 'app.accessibility.reduce_animations';

  final SharedPreferences _prefs;

  static Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPreferences._(prefs);
  }

  AppAppearanceMode get appearanceMode =>
      AppAppearanceMode.values.byName(_prefs.getString(_appearanceKey) ?? AppAppearanceMode.dark.name);
  Future<void> setAppearanceMode(AppAppearanceMode mode) => _prefs.setString(_appearanceKey, mode.name);

  bool get notificationsEnabled => _prefs.getBool(_notificationsEnabledKey) ?? true;
  Future<void> setNotificationsEnabled(bool value) => _prefs.setBool(_notificationsEnabledKey, value);

  bool get habitReminders => _prefs.getBool(_habitReminderKey) ?? true;
  Future<void> setHabitReminders(bool value) => _prefs.setBool(_habitReminderKey, value);

  bool get workoutReminders => _prefs.getBool(_workoutReminderKey) ?? true;
  Future<void> setWorkoutReminders(bool value) => _prefs.setBool(_workoutReminderKey, value);

  bool get sleepReminders => _prefs.getBool(_sleepReminderKey) ?? true;
  Future<void> setSleepReminders(bool value) => _prefs.setBool(_sleepReminderKey, value);

  bool get dailySummary => _prefs.getBool(_dailySummaryKey) ?? false;
  Future<void> setDailySummary(bool value) => _prefs.setBool(_dailySummaryKey, value);

  bool get biometricLock => _prefs.getBool(_biometricKey) ?? false;
  Future<void> setBiometricLock(bool value) => _prefs.setBool(_biometricKey, value);

  ProgressVisibilityMode get progressVisibility =>
      ProgressVisibilityMode.values.byName(_prefs.getString(_progressVisibilityKey) ?? ProgressVisibilityMode.privateOnly.name);
  Future<void> setProgressVisibility(ProgressVisibilityMode mode) =>
      _prefs.setString(_progressVisibilityKey, mode.name);

  AppTextSize get textSize =>
      AppTextSize.values.byName(_prefs.getString(_textSizeKey) ?? AppTextSize.normal.name);
  Future<void> setTextSize(AppTextSize value) => _prefs.setString(_textSizeKey, value.name);

  bool get highContrast => _prefs.getBool(_highContrastKey) ?? false;
  Future<void> setHighContrast(bool value) => _prefs.setBool(_highContrastKey, value);

  bool get reduceAnimations => _prefs.getBool(_reduceAnimationsKey) ?? false;
  Future<void> setReduceAnimations(bool value) => _prefs.setBool(_reduceAnimationsKey, value);
}
