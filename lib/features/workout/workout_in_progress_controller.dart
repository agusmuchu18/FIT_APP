import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkoutInProgressDraft {
  const WorkoutInProgressDraft({
    required this.startTime,
    required this.isPaused,
    required this.pausedAt,
    required this.accumulatedPaused,
    required this.lastUpdated,
  });

  final DateTime startTime;
  final bool isPaused;
  final DateTime? pausedAt;
  final Duration accumulatedPaused;
  final DateTime lastUpdated;

  WorkoutInProgressDraft copyWith({
    DateTime? startTime,
    bool? isPaused,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    Duration? accumulatedPaused,
    DateTime? lastUpdated,
  }) {
    return WorkoutInProgressDraft(
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
    return WorkoutInProgressDraft(
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
  static final WorkoutInProgressController instance = WorkoutInProgressController._();

  final ValueNotifier<WorkoutInProgressDraft?> _draftNotifier = ValueNotifier(null);
  SharedPreferences? _prefs;

  WorkoutInProgressDraft? get currentDraft => _draftNotifier.value;
  ValueListenable<WorkoutInProgressDraft?> watchDraft() => _draftNotifier;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await refresh();
  }

  Future<void> refresh() async {
    _prefs ??= await SharedPreferences.getInstance();
    _setFromRaw(_prefs?.getString(draftKey));
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

  Future<void> resume() async {
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
    _draftNotifier.value = null;
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
