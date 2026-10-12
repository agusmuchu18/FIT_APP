import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../core/data/account_storage_scope.dart';

import '../domain/session_models.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';

class WorkoutDraftIdentity {
  const WorkoutDraftIdentity({
    this.sessionId,
    this.routineId,
    this.routineName,
    this.sourceSessionId,
    this.workoutType = WorkoutType.strength,
    this.isPaused = false,
    this.pausedAt,
    this.accumulatedPaused = Duration.zero,
    this.restStartedAtElapsedSeconds,
    this.restDurationSeconds,
    this.restSourceSetId,
  });

  final String? sessionId;
  final String? routineId;
  final String? routineName;
  final String? sourceSessionId;
  final WorkoutType workoutType;
  final bool isPaused;
  final DateTime? pausedAt;
  final Duration accumulatedPaused;
  final int? restStartedAtElapsedSeconds;
  final int? restDurationSeconds;
  final String? restSourceSetId;
}

class WorkoutRepository {
  WorkoutRepository() : _scope = AccountStorageScope.current;
  final String _scope;
  String get storageScope => _scope;
  int _invalidRichRows = 0, _invalidLegacyRows = 0, _invalidMigrationRows = 0;
  int get unreadableHistoryRows =>
      _invalidRichRows + _invalidLegacyRows + _invalidMigrationRows;
  bool get isCurrentScope => _scope == AccountStorageScope.current;
  String get sessionsBoxName =>
      AccountStorageScope.boxName(richSessionsBoxName, _scope);
  static const richSessionsBoxName = 'fit_workout_sessions';
  static const draftKey = 'workout_in_progress_v2_draft';
  static const sessionsKey = 'workout_in_progress_v2_sessions';
  static const legacySessionsKey = 'pro_workout_sessions';

  Box<String>? get _sessionsBox => Hive.isBoxOpen(sessionsBoxName)
      ? Hive.box<String>(sessionsBoxName)
      : null;

  Future<List<String>> _readSessionRows() async {
    _invalidMigrationRows = 0;
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final legacyRows = prefs.getStringList(sessionsKey) ?? [];
    final box = _sessionsBox;
    if (box == null) return _sortedRows(legacyRows);

    // Keep the old list untouched until migration has been audited on devices.
    for (final raw in legacyRows) {
      String? id;
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        id = decoded['id'] as String?;
      } catch (_) {
        _invalidMigrationRows++;
        // A corrupt row remains in preferences and cannot erase valid rows.
        continue;
      }
      if (id != null && id.isNotEmpty && !box.containsKey(id)) {
        // Storage failures must surface; never silently hide an unmigrated row.
        await box.put(id, raw);
      }
    }
    return _sortedRows(box.values);
  }

  List<String> _sortedRows(Iterable<String> values) {
    final rows = [
      for (final raw in values) (raw: raw, date: _sessionDate(raw)),
    ];
    rows.sort((a, b) => b.date.compareTo(a.date));
    return rows.map((row) => row.raw).toList();
  }

  DateTime _sessionDate(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.tryParse(json['date'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Future<DateTime?> loadDraftStartTime() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.tryParse(json['sessionStart'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<List<ExerciseInSession>?> loadDraftExercises() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final serialized = json['exercises'] as List<dynamic>? ?? [];
      return serialized
          .map(
            (item) => ExerciseInSession.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      throw const FormatException(
        'El borrador no se puede leer; se conserva sin sobrescribir.',
      );
    }
  }

  Future<WorkoutDraftIdentity?> loadDraftIdentity() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return WorkoutDraftIdentity(
        sessionId: json['workoutId'] as String?,
        routineId: json['routineId'] as String?,
        routineName: json['routineName'] as String?,
        sourceSessionId: json['sourceSessionId'] as String?,
        workoutType: WorkoutType.values.firstWhere(
          (type) => type.name == json['workoutType'],
          orElse: () => WorkoutType.strength,
        ),
        isPaused: json['isPaused'] as bool? ?? false,
        pausedAt: DateTime.tryParse(json['pausedAt'] as String? ?? ''),
        accumulatedPaused: Duration(
          seconds: json['accumulatedPausedSeconds'] as int? ?? 0,
        ),
        restStartedAtElapsedSeconds:
            json['restStartedAtElapsedSeconds'] as int?,
        restDurationSeconds: json['restDurationSeconds'] as int?,
        restSourceSetId: json['restSourceSetId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> persistDraft(List<ExerciseInSession> exercises) async {
    final startTime = await loadDraftStartTime() ?? DateTime.now();
    await persistDraftWithStartTime(exercises, startTime: startTime);
  }

  Future<void> persistDraftWithStartTime(
    List<ExerciseInSession> exercises, {
    required DateTime startTime,
    String? workoutId,
    String? routineId,
    String? routineName,
    String? sourceSessionId,
    WorkoutType workoutType = WorkoutType.strength,
    int? restStartedAtElapsedSeconds,
    int? restDurationSeconds,
    String? restSourceSetId,
    bool clearRest = false,
  }) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    Map<String, dynamic>? previous;
    final raw = prefs.getString(draftKey);
    if (raw != null && workoutId != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if (decoded['workoutId'] == workoutId) previous = decoded;
      } catch (_) {
        // Damaged draft metadata must not prevent a valid save.
      }
    }
    final now = DateTime.now().toIso8601String();
    await prefs.setString(
      draftKey,
      jsonEncode({
        'updatedAt': now,
        'lastUpdated': now,
        'sessionStart': startTime.toIso8601String(),
        'workoutId': workoutId,
        'routineId': routineId,
        'routineName': routineName,
        'sourceSessionId': sourceSessionId ?? previous?['sourceSessionId'],
        'workoutType': workoutType.name,
        'isPaused': previous?['isPaused'] ?? false,
        'pausedAt': previous?['pausedAt'],
        'accumulatedPausedSeconds': previous?['accumulatedPausedSeconds'] ?? 0,
        'restStartedAtElapsedSeconds': clearRest
            ? null
            : (restStartedAtElapsedSeconds ??
                  previous?['restStartedAtElapsedSeconds']),
        'restDurationSeconds': clearRest
            ? null
            : (restDurationSeconds ?? previous?['restDurationSeconds']),
        'restSourceSetId': clearRest
            ? null
            : (restSourceSetId ?? previous?['restSourceSetId']),
        'exercises': exercises.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> clearDraft() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    await prefs.remove(draftKey);
  }

  Future<void> markCompletionPending(String sessionId) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.getString(draftKey);
    if (raw == null) {
      throw StateError('Falta el borrador que se quiere finalizar.');
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['workoutId'] != sessionId) {
      throw StateError('El borrador pertenece a otra sesión.');
    }
    json['completionPending'] = true;
    await prefs.setString(draftKey, jsonEncode(json));
  }

  Future<String?> pendingCompletionId() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.getString(draftKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return json['completionPending'] == true
          ? json['workoutId'] as String?
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> persistCompletedWorkout(
    List<ExerciseInSession> exercises, {
    required String sessionId,
    String? routineId,
    String? routineName,
    WorkoutType workoutType = WorkoutType.strength,
    Duration? duration,
    DateTime? completedAt,
    DateTime? startedAt,
    Duration? totalDuration,
    String? sourceSessionId,
    bool clearDraftAfterSave = true,
  }) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final stored = await _readSessionRows();
    final now = completedAt ?? DateTime.now();
    final metrics = WorkoutReport(
      WorkoutSession(
        id: sessionId,
        type: workoutType,
        date: now,
        exercises: WorkoutAnalytics.fromLive(exercises),
      ),
    );
    final totalDoneSets = metrics.performedSets;
    final volumeKg = metrics.externalVolume;

    final session = {
      'id': sessionId,
      'date': now.toUtc().toIso8601String(),
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'sourceSessionId': sourceSessionId,
      'totalDurationSeconds': totalDuration?.inSeconds,
      'routineId': routineId,
      'routineName': routineName,
      'workoutType': workoutType.name,
      'durationMinutes': duration?.inMinutes,
      'durationSeconds': duration?.inSeconds,
      'durationIsActive': true,
      'totalDoneSets': totalDoneSets,
      'totalVolumeKg': volumeKg,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
    final encoded = jsonEncode(session);
    final box = _sessionsBox;
    if (box != null) {
      await box.put(sessionId, encoded);
    } else {
      stored.removeWhere((raw) {
        try {
          return (jsonDecode(raw) as Map<String, dynamic>)['id'] == sessionId;
        } catch (_) {
          return false;
        }
      });
      stored.insert(0, encoded);
      await prefs.setStringList(sessionsKey, stored);
    }
    if (clearDraftAfterSave) await clearDraft();
  }

  Future<List<ExerciseInSession>?> loadLatestCompletedSessionExercises() async {
    final values = await _readSessionRows();
    if (values.isEmpty) return null;

    for (final raw in values) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final serialized = json['exercises'] as List<dynamic>? ?? [];
        return serialized
            .map(
              (item) => ExerciseInSession.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<List<WorkoutSession>> listSessions() async {
    _invalidRichRows = 0;
    final values = await _readSessionRows();
    final parsed = <WorkoutSession>[];
    for (final raw in values) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final exercises = WorkoutAnalytics.fromLive(
          (json['exercises'] as List<dynamic>? ?? [])
              .map(
                (rawExercise) => ExerciseInSession.fromJson(
                  Map<String, dynamic>.from(rawExercise as Map),
                ),
              )
              .toList(),
        );

        parsed.add(
          WorkoutSession(
            id: json['id'] as String,
            type: WorkoutType.values.firstWhere(
              (type) => type.name == json['workoutType'],
              orElse: () => WorkoutType.strength,
            ),
            date: DateTime.parse(json['date'] as String),
            templateId: json['routineId'] as String?,
            templateName: json['routineName'] as String?,
            durationMinutes: json['durationMinutes'] as int?,
            durationSeconds: json['durationSeconds'] as int?,
            durationIsActive: json['durationIsActive'] as bool?,
            totalDurationSeconds: json['totalDurationSeconds'] as int?,
            startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
            sourceSessionId: json['sourceSessionId'] as String?,
            exercises: exercises,
            notes: json['notes'] as String?,
          ),
        );
      } catch (_) {
        _invalidRichRows++;
        continue;
      }
    }
    parsed.sort((a, b) => a.date.compareTo(b.date));
    return parsed;
  }

  Future<List<WorkoutSession>> listAllSessions() async {
    _invalidLegacyRows = 0;
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final byId = <String, WorkoutSession>{};
    final raw = prefs.get(legacySessionsKey);
    try {
      final rows = raw is String ? jsonDecode(raw) : raw;
      if (rows is List) {
        for (final row in rows) {
          try {
            final decoded = row is String ? jsonDecode(row) : row;
            final session = WorkoutSession.fromJson(
              Map<String, dynamic>.from(decoded as Map),
            );
            byId[session.id] = session;
          } catch (_) {
            _invalidLegacyRows++;
          }
        }
      }
    } catch (_) {
      _invalidLegacyRows++;
    }
    for (final session in await listSessions()) {
      byId[session.id] = session;
    }
    return byId.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<WorkoutSession?> findSession(String id) async {
    for (final session in await listAllSessions()) {
      if (session.id == id) return session;
    }
    return null;
  }

  /// Append/upsert one new legacy session, preserving every other raw row.
  Future<void> persistLegacySession(WorkoutSession session) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final value = prefs.get(legacySessionsKey);
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded != null && decoded is! List) {
      throw const FormatException('Historial antiguo ilegible.');
    }
    final rows = List<dynamic>.from(decoded as List? ?? []);
    rows.removeWhere((row) {
      try {
        final map = row is String ? jsonDecode(row) : row;
        return map is Map && map['id'] == session.id;
      } catch (_) {
        return false;
      }
    });
    rows.add(session.toJson());
    await prefs.setString(legacySessionsKey, jsonEncode(rows));
  }

  Future<String?> pendingLegacyCompletionId() async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.getString('pro_workout_draft');
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map)['pendingCompletedSessionId'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCompletedLegacyDraft(String id) async {
    if (await pendingLegacyCompletionId() != id) return;
    await (await ScopedPreferences.getInstance(scope: _scope))
        .remove('pro_workout_draft');
  }

  Future<List<PreviousSet>> getPreviousSetsForExercise(
    String exerciseId,
  ) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final legacyValue = prefs.get(legacySessionsKey);
    List<dynamic> legacySessions = [];
    if (legacyValue is String) {
      try {
        final decoded = jsonDecode(legacyValue);
        if (decoded is List) legacySessions = decoded.reversed.toList();
      } catch (_) {
        // A damaged legacy entry must not hide valid current sessions.
      }
    } else if (legacyValue is List) {
      legacySessions = legacyValue.reversed.toList();
    }

    final sessions = <dynamic>[...await _readSessionRows(), ...legacySessions];

    for (final raw in sessions) {
      try {
        final decoded = raw is String ? jsonDecode(raw) : raw;
        final json = Map<String, dynamic>.from(decoded as Map);
        final exercises = (json['exercises'] as List<dynamic>? ?? []);
        for (final exerciseRaw in exercises) {
          final exercise = Map<String, dynamic>.from(exerciseRaw as Map);
          final currentExerciseId =
              exercise['exerciseId'] as String? ?? exercise['id'] as String?;
          if (currentExerciseId != exerciseId) continue;

          final sets = (exercise['sets'] as List<dynamic>? ?? []);
          final previous = sets
              .where((setRaw) => (setRaw as Map)['done'] != false)
              .map((setRaw) {
                final set = Map<String, dynamic>.from(setRaw as Map);
                final kg =
                    (set['kg'] as num?)?.toDouble() ??
                    (set['externalLoadKg'] as num?)?.toDouble();
                final reps = set['reps'] as int?;
                return PreviousSet(
                  kg: kg,
                  reps: reps,
                  durationSeconds: set['durationSeconds'] as int?,
                  assistanceKg: (set['assistanceKg'] as num?)?.toDouble(),
                );
              })
              .toList();
          if (previous.isNotEmpty) return previous;
        }
      } catch (_) {
        continue;
      }
    }

    return [];
  }
}
