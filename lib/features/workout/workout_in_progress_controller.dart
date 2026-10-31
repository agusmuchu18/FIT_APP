import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/data/account_storage_scope.dart';

class WorkoutInProgressDraft {
  const WorkoutInProgressDraft({
    required this.workoutId,
    required this.routineName,
    required this.startTime,
    required this.isPaused,
    required this.pausedAt,
    required this.accumulatedPaused,
    required this.lastUpdated,
    this.restStartedAtElapsedSeconds,
    this.restDurationSeconds,
  });

  final String workoutId;
  final String routineName;
  final DateTime startTime;
  final bool isPaused;
  final DateTime? pausedAt;
  final Duration accumulatedPaused;
  final DateTime lastUpdated;
  final int? restStartedAtElapsedSeconds;
  final int? restDurationSeconds;

  /// Active (unpaused) time, the clock the rest timer is measured against.
  Duration elapsedAt(DateTime now) {
    final end = isPaused ? (pausedAt ?? now) : now;
    final value = end.difference(startTime) - accumulatedPaused;
    return value.isNegative ? Duration.zero : value;
  }

  /// Remaining rest, or null when no rest is running.
  Duration? restRemainingAt(DateTime now) {
    final started = restStartedAtElapsedSeconds;
    final duration = restDurationSeconds;
    if (started == null || duration == null) return null;
    final remaining = duration - (elapsedAt(now).inSeconds - started);
    return Duration(seconds: remaining > 0 ? remaining : 0);
  }

  WorkoutInProgressDraft copyWith({
    String? workoutId,
    String? routineName,
    DateTime? startTime,
    bool? isPaused,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    Duration? accumulatedPaused,
    DateTime? lastUpdated,
  }) {
    return WorkoutInProgressDraft(
      workoutId: workoutId ?? this.workoutId,
      routineName: routineName ?? this.routineName,
      startTime: startTime ?? this.startTime,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      accumulatedPaused: accumulatedPaused ?? this.accumulatedPaused,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      restStartedAtElapsedSeconds: restStartedAtElapsedSeconds,
      restDurationSeconds: restDurationSeconds,
    );
  }

  factory WorkoutInProgressDraft.fromJson(Map<String, dynamic> json) {
    final startTime = DateTime.tryParse(json['sessionStart'] as String? ?? '');
    if (startTime == null) {
      throw const FormatException('Draft missing sessionStart');
    }
    final routineName = (json['routineName'] as String?)?.trim();
    final workoutId = (json['workoutId'] as String?)?.trim();
    return WorkoutInProgressDraft(
      workoutId: (workoutId == null || workoutId.isEmpty)
          ? 'active-workout'
          : workoutId,
      routineName: (routineName == null || routineName.isEmpty)
          ? 'Entrenamiento activo'
          : routineName,
      startTime: startTime,
      isPaused: json['isPaused'] as bool? ?? false,
      pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
      accumulatedPaused: Duration(
        seconds: json['accumulatedPausedSeconds'] as int? ?? 0,
      ),
      lastUpdated:
          DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? startTime,
      restStartedAtElapsedSeconds: json['restStartedAtElapsedSeconds'] is int
          ? json['restStartedAtElapsedSeconds'] as int
          : null,
      restDurationSeconds: json['restDurationSeconds'] is int
          ? json['restDurationSeconds'] as int
          : null,
    );
  }
}

class WorkoutInProgressController {
  WorkoutInProgressController._();

  static const String draftKey = 'pro_workout_draft';
  static const String draftV2Key = 'workout_in_progress_v2_draft';
  static final WorkoutInProgressController instance =
      WorkoutInProgressController._();

  final ValueNotifier<WorkoutInProgressDraft?> _draftNotifier = ValueNotifier(
    null,
  );
  ScopedPreferences? _prefs;
  VoidCallback? _resumeHandler;
  String? _activeDraftKey;

  WorkoutInProgressDraft? get currentDraft => _draftNotifier.value;
  ValueListenable<WorkoutInProgressDraft?> watchDraft() => _draftNotifier;
  bool get hasActiveWorkout => currentDraft != null;
  bool get isLegacyDraftActive => _activeDraftKey == draftKey;
  DateTime? get startTime => currentDraft?.startTime;
  String? get routineName => currentDraft?.routineName;
  String? get workoutId => currentDraft?.workoutId;

  Future<void> initialize() async {
    await refresh();
  }

  void resetSession() {
    _prefs = null;
    _activeDraftKey = null;
    _resumeHandler = null;
    _draftNotifier.value = null;
  }

  Future<void> refresh() async {
    final prefs = await ScopedPreferences.getInstance();
    if (prefs.scope != AccountStorageScope.current) return;
    _prefs = prefs;
    final rawV2 = prefs.getString(draftV2Key);
    final rawV1 = prefs.getString(draftKey);

    if (_trySetFromRaw(rawV2, source: draftV2Key)) {
      return;
    }
    _trySetFromRaw(rawV1, source: draftKey);
  }

  void syncFromRaw(String? rawDraft) {
    if (_prefs?.scope != AccountStorageScope.current) return;
    final currentV2 = _prefs?.getString(draftV2Key);
    if (currentV2 != null && _trySetFromRaw(currentV2, source: draftV2Key)) {
      return;
    }
    _trySetFromRaw(rawDraft, source: draftKey);
  }

  Future<void> pause() async {
    final active = await _loadActiveRaw();
    if (active == null || active.json['isPaused'] == true) return;
    final json = active.json;
    final now = DateTime.now();
    json['isPaused'] = true;
    json['pausedAt'] = now.toIso8601String();
    json['lastUpdated'] = now.toIso8601String();
    final encoded = jsonEncode(json);
    await active.prefs.setString(active.key, encoded);
    if (active.prefs.scope == AccountStorageScope.current) {
      _trySetFromRaw(encoded, source: active.key);
    }
  }

  Future<void> resumePausedWorkout() async {
    final active = await _loadActiveRaw();
    if (active == null || active.json['isPaused'] != true) return;
    final json = active.json;
    final now = DateTime.now();
    final pausedAt = DateTime.tryParse(json['pausedAt'] as String? ?? '');
    final currentPausedSeconds = json['accumulatedPausedSeconds'] as int? ?? 0;
    final extraPaused = pausedAt == null
        ? 0
        : now.difference(pausedAt).inSeconds.clamp(0, 1 << 31);
    json['isPaused'] = false;
    json['pausedAt'] = null;
    json['accumulatedPausedSeconds'] = currentPausedSeconds + extraPaused;
    json['lastUpdated'] = now.toIso8601String();
    final encoded = jsonEncode(json);
    await active.prefs.setString(active.key, encoded);
    if (active.prefs.scope == AccountStorageScope.current) {
      _trySetFromRaw(encoded, source: active.key);
    }
  }

  Future<void> discard() async {
    final active = await _loadActiveRaw();
    if (active == null) return;
    await active.prefs.remove(active.key);
    await refresh();
  }

  Future<({String key, Map<String, dynamic> json, ScopedPreferences prefs})?>
  _loadActiveRaw() async {
    final prefs = await ScopedPreferences.getInstance();
    if (prefs.scope != AccountStorageScope.current) return null;
    _prefs = prefs;
    for (final key in [draftV2Key, draftKey]) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        WorkoutInProgressDraft.fromJson(json);
        return (key: key, json: json, prefs: prefs);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  void registerResumeHandler(VoidCallback handler) {
    _resumeHandler = handler;
  }

  void resume() {
    _resumeHandler?.call();
  }

  bool _trySetFromRaw(String? rawDraft, {String? source}) {
    if (rawDraft == null) {
      _draftNotifier.value = null;
      _activeDraftKey = null;
      return false;
    }
    try {
      final json = jsonDecode(rawDraft) as Map<String, dynamic>;
      _draftNotifier.value = WorkoutInProgressDraft.fromJson(json);
      _activeDraftKey = source;
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[WorkoutInProgressController] Failed parsing draft from ${source ?? 'unknown'}: $error',
        );
      }
      _draftNotifier.value = null;
      _activeDraftKey = null;
      return false;
    }
  }
}
