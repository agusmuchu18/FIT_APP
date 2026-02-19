import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutInProgressDraft {
  const WorkoutInProgressDraft({
    required this.workoutId,
    required this.routineName,
    required this.startTime,
    required this.isPaused,
    required this.pausedAt,
    required this.accumulatedPaused,
    required this.lastUpdated,
  });

  final String workoutId;
  final String routineName;
  final DateTime startTime;
  final bool isPaused;
  final DateTime? pausedAt;
  final Duration accumulatedPaused;
  final DateTime lastUpdated;

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
      workoutId: (workoutId == null || workoutId.isEmpty) ? 'active-workout' : workoutId,
      routineName: (routineName == null || routineName.isEmpty) ? 'Entrenamiento activo' : routineName,
      startTime: startTime,
      isPaused: json['isPaused'] as bool? ?? false,
      pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
      accumulatedPaused: Duration(seconds: json['accumulatedPausedSeconds'] as int? ?? 0),
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? startTime,
    );
  }
}

class WorkoutInProgressController {
  WorkoutInProgressController._();

  static const String draftKey = 'pro_workout_draft';
  static const String draftV2Key = 'workout_in_progress_v2_draft';
  static final WorkoutInProgressController instance = WorkoutInProgressController._();

  final ValueNotifier<WorkoutInProgressDraft?> _draftNotifier = ValueNotifier(null);
  SharedPreferences? _prefs;
  VoidCallback? _resumeHandler;

  WorkoutInProgressDraft? get currentDraft => _draftNotifier.value;
  ValueListenable<WorkoutInProgressDraft?> watchDraft() => _draftNotifier;
  bool get hasActiveWorkout => currentDraft != null;
  DateTime? get startTime => currentDraft?.startTime;
  String? get routineName => currentDraft?.routineName;
  String? get workoutId => currentDraft?.workoutId;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await refresh();
  }

  Future<void> refresh() async {
    _prefs ??= await SharedPreferences.getInstance();
    _setFromRaw(
      _prefs?.getString(draftV2Key) ?? _prefs?.getString(draftKey),
    );
  }

  void syncFromRaw(String? rawDraft) {
    _setFromRaw(rawDraft);
  }

  Future<void> pause() async {
    final raw = _prefs?.getString(draftKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now();
    json['isPaused'] = true;
    json['pausedAt'] = now.toIso8601String();
    json['lastUpdated'] = now.toIso8601String();
    final encoded = jsonEncode(json);
    await _prefs?.setString(draftKey, encoded);
    _setFromRaw(encoded);
  }

  Future<void> resumePausedWorkout() async {
    final raw = _prefs?.getString(draftKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final now = DateTime.now();
    final pausedAt = DateTime.tryParse(json['pausedAt'] as String? ?? '');
    final currentPausedSeconds = json['accumulatedPausedSeconds'] as int? ?? 0;
    final extraPaused = pausedAt == null ? 0 : now.difference(pausedAt).inSeconds;
    json['isPaused'] = false;
    json['pausedAt'] = null;
    json['accumulatedPausedSeconds'] = currentPausedSeconds + extraPaused;
    json['lastUpdated'] = now.toIso8601String();
    final encoded = jsonEncode(json);
    await _prefs?.setString(draftKey, encoded);
    _setFromRaw(encoded);
  }

  Future<void> discard() async {
    await _prefs?.remove(draftKey);
    await _prefs?.remove(draftV2Key);
    _draftNotifier.value = null;
  }

  void registerResumeHandler(VoidCallback handler) {
    _resumeHandler = handler;
  }

  void resume() {
    _resumeHandler?.call();
  }

  void _setFromRaw(String? rawDraft) {
    if (rawDraft == null) {
      _draftNotifier.value = null;
      return;
    }
    try {
      final json = jsonDecode(rawDraft) as Map<String, dynamic>;
      _draftNotifier.value = WorkoutInProgressDraft.fromJson(json);
    } catch (_) {
      _draftNotifier.value = null;
    }
  }
}
