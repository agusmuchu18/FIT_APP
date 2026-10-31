import '../domain/training_program.dart';

import 'dart:convert';
import 'dart:async';

import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

import '../../../core/data/account_storage_scope.dart';

import '../domain/session_models.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
part 'workout_history_changes.dart';

class WorkoutDraftIdentity {
  const WorkoutDraftIdentity({
    this.sessionId,
    this.routineId,
    this.routineName,
    this.sourceSessionId,
    this.programExecution,
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
  final ProgramExecutionRef? programExecution;
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
  static final _historyRevisions = <String, ValueNotifier<int>>{};
  static final _performanceCaches =
      <
        String,
        ({int revision, DateTime day, Future<TrainingPerformanceIndex> value})
      >{};
  ValueListenable<int> get historyRevision =>
      _historyRevisions.putIfAbsent(_scope, () => ValueNotifier(0));

  void invalidateHistory() {
    _performanceCaches.remove(_scope);
    final revision = _historyRevisions.putIfAbsent(
      _scope,
      () => ValueNotifier(0),
    );
    revision.value++;
  }

  Future<TrainingPerformanceIndex> performanceIndex({bool refresh = false}) {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final cached = _performanceCaches[_scope];
    if (!refresh &&
        cached != null &&
        cached.revision == historyRevision.value &&
        cached.day == day) {
      return cached.value;
    }
    late final Future<TrainingPerformanceIndex> future;
    future = listAllSessions().then(TrainingPerformanceIndex.new).catchError((
      Object error,
      StackTrace trace,
    ) {
      if (identical(_performanceCaches[_scope]?.value, future)) {
        _performanceCaches.remove(_scope);
      }
      Error.throwWithStackTrace(error, trace);
    });
    if (_performanceCaches.length >= 4 &&
        !_performanceCaches.containsKey(_scope)) {
      _performanceCaches.remove(_performanceCaches.keys.first);
    }
    _performanceCaches[_scope] = (
      revision: historyRevision.value,
      day: day,
      value: future,
    );
    return future;
  }

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
    return _sortedRows(
      box
          .toMap()
          .entries
          .where((e) => e.key != WorkoutHistoryChanges.storageKey)
          .map((e) => e.value),
    );
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
        programExecution: json['programExecution'] is Map
            ? ProgramExecutionRef.fromJson(
                Map<String, dynamic>.from(json['programExecution'] as Map),
              )
            : null,
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
    ProgramExecutionRef? programExecution,
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
        'programExecution':
            programExecution?.toJson() ?? previous?['programExecution'],
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
    ProgramExecutionRef? programExecution,
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
      'programExecution': programExecution?.toJson(),
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
    invalidateHistory();
    if (clearDraftAfterSave) await clearDraft();
  }

  Future<List<ExerciseInSession>?> loadLatestCompletedSessionExercises() async {
    final sessions = await listAllSessions();
    final latest = sessions.lastOrNull;
    if (latest == null) return null;
    return [
      for (final e in latest.exercises)
        ExerciseInSession(
          id: e.instanceId ?? e.id,
          exerciseId: e.id,
          name: e.name,
          plan: e,
          notes: e.notes,
          isTimed: WorkoutAnalytics.isTimed(e),
          isDistance: e.measurement == 'distance',
          isAssisted: e.targetLoadType == RoutineExerciseLoadType.assistedKg,
          sets: [
            for (var i = 0; i < e.sets.length; i++)
              SetInSession(
                id: e.sets[i].id,
                index: i + 1,
                kg: e.sets[i].externalLoadKg,
                assistanceKg: e.sets[i].assistanceKg,
                reps: e.sets[i].reps,
                durationSeconds: e.sets[i].durationSeconds,
                distanceMeters: e.sets[i].distanceMeters,
                done: e.sets[i].done == true,
                loadConvention: e.sets[i].loadConvention,
                implementCount: e.sets[i].implementCount,
              ),
          ],
        ),
    ];
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
            programExecution: json['programExecution'] is Map
                ? ProgramExecutionRef.fromJson(
                    Map<String, dynamic>.from(json['programExecution'] as Map),
                  )
                : null,
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
    return applyHistoryChanges(parsed);
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
    return applyHistoryChanges(byId.values.toList());
  }

  Future<WorkoutSession?> findSession(String id) async {
    for (final session in await listAllSessions()) {
      if (session.id == id) return session;
    }
    return null;
  }

  /// Only confirmed, compatible results may suggest values for a new draft.
  /// Historical references remain a separate legacy-friendly presentation API.
  Future<List<SetEntry>> getCompatibleSuggestions(
    ExerciseInSession exercise,
  ) async {
    final mapped = WorkoutAnalytics.fromLive([exercise]).single;
    final seed =
        mapped.sets.firstOrNull ??
        SetEntry(id: '', loadType: exercise.defaultMode);
    final key = exerciseLoadKey(mapped, seed);
    final index = await performanceIndex();
    final id = WorkoutAnalytics.definition(mapped)?.id ?? mapped.id;
    final history = index.exerciseHistory(id, loadKey: key);
    if (history.isEmpty &&
        (seed.loadType ?? exercise.defaultMode) ==
            RoutineExerciseLoadType.assistedKg &&
        seed.assistanceKg == null) {
      return index
              .exerciseHistory(id)
              .where(
                (o) =>
                    o.sets.isNotEmpty &&
                    WorkoutAnalytics.setLoadType(o.exercise, o.sets.first) ==
                        RoutineExerciseLoadType.assistedKg &&
                    o.sets.first.loadConvention == seed.loadConvention,
              )
              .firstOrNull
              ?.sets ??
          const [];
    }
    return history.firstOrNull?.sets ?? const [];
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
    invalidateHistory();
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
    for (final session in (await listAllSessions()).reversed) {
      final matching = session.exercises.where(
        (e) => (WorkoutAnalytics.definition(e)?.id ?? e.id) == exerciseId,
      );
      final sets = [
        for (final e in matching)
          ...e.sets.where(
            (s) => s.done != false && WorkoutAnalytics.isRecordedSet(e, s),
          ),
      ];
      if (sets.isNotEmpty) {
        return [
          for (final e in matching)
            for (final s in e.sets.where(
              (s) => s.done != false && WorkoutAnalytics.isRecordedSet(e, s),
            ))
              PreviousSet(
                loadType: WorkoutAnalytics.setLoadType(e, s),
                loadIsAmbiguous:
                    s.loadIsAmbiguous ||
                    WorkoutAnalytics.setLoadType(e, s) == null,
                kg: s.externalLoadKg,
                reps: s.reps,
                durationSeconds: s.durationSeconds,
                assistanceKg: s.assistanceKg,
              ),
        ];
      }
    }
    return _partialLegacyPrevious(exerciseId);
  }

  /// Earliest versions saved reference-only rows without session identity/date.
  /// Preserve that display contract, but never promote these rows into records,
  /// suggestions or analytics, and never reread an identified/tombstoned session.
  Future<List<PreviousSet>> _partialLegacyPrevious(String exerciseId) async {
    final prefs = await ScopedPreferences.getInstance(scope: _scope);
    final raw = prefs.get(legacySessionsKey);
    List<dynamic> legacy = [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is List) legacy = decoded.reversed.toList();
    } catch (_) {
      /* Unreadable originals remain in storage. */
    }
    for (final row in [...await _readSessionRows(), ...legacy]) {
      try {
        final json = Map<String, dynamic>.from(
          (row is String ? jsonDecode(row) : row) as Map,
        );
        if (json['id'] != null || json['date'] != null) continue;
        for (final e in (json['exercises'] as List? ?? [])) {
          if ((e['exerciseId'] ?? e['id']) != exerciseId) continue;
          final previous = <PreviousSet>[];
          for (final set in (e['sets'] as List? ?? [])) {
            if (set is! Map || set['done'] == false) continue;
            double? positive(Object? n, {bool zero = false}) =>
                n is num && n.isFinite && (zero ? n >= 0 : n > 0)
                ? n.toDouble()
                : null;
            final reps = positive(set['reps']),
                seconds = positive(set['durationSeconds']);
            if (reps == null && seconds == null) continue;
            if (reps != null && reps != reps.roundToDouble() ||
                seconds != null && seconds != seconds.roundToDouble()) {
              continue;
            }
            previous.add(
              PreviousSet(
                kg: positive(set['kg'] ?? set['externalLoadKg'], zero: true),
                loadType: decodeSetLoadType(set['loadType']),
                loadIsAmbiguous:
                    set['loadIsAmbiguous'] == true ||
                    (set['loadType'] == null &&
                        (set['kg'] ?? set['externalLoadKg']) != null),
                reps: reps?.toInt(),
                durationSeconds: seconds?.toInt(),
                assistanceKg: positive(set['assistanceKg'], zero: true),
              ),
            );
          }
          if (previous.isNotEmpty) return previous;
        }
      } catch (_) {
        /* Skip one malformed reference, preserving subsequent rows. */
      }
    }
    return [];
  }
}
