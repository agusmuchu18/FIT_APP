import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/workout_repository.dart';
import '../pro/models/workout_models.dart';
import '../workout_in_progress_controller.dart';
import 'routines_repository.dart';

enum RoutineSortOption { smart, recent, mostUsed, alphabetical }

class RoutineMetadata {
  const RoutineMetadata({
    this.pinned = false,
    this.usageCount = 0,
    this.lastUsedAt,
  });

  final bool pinned;
  final int usageCount;
  final DateTime? lastUsedAt;

  RoutineMetadata copyWith({
    bool? pinned,
    int? usageCount,
    DateTime? lastUsedAt,
    bool clearLastUsedAt = false,
  }) {
    return RoutineMetadata(
      pinned: pinned ?? this.pinned,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'pinned': pinned,
        'usageCount': usageCount,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory RoutineMetadata.fromJson(Map<String, dynamic> json) {
    return RoutineMetadata(
      pinned: json['pinned'] as bool? ?? false,
      usageCount: json['usageCount'] as int? ?? 0,
      lastUsedAt: DateTime.tryParse(json['lastUsedAt'] as String? ?? ''),
    );
  }
}

class TrainingHomeController extends ChangeNotifier {
  static const _sessionsKey = 'pro_workout_sessions';
  static const _draftKey = 'pro_workout_draft';
  static const _metadataKey = 'pro_workout_template_metadata';
  static const _sortKey = 'pro_workout_sort_preference';
  static const _foldersKey = 'pro_workout_folders';

  final Uuid _uuid = const Uuid();
  final RoutinesRepository _routinesRepository = RoutinesRepository();
  final WorkoutRepository _workoutRepository = WorkoutRepository();

  SharedPreferences? _prefs;
  bool _initialized = false;
  List<WorkoutTemplate> _routines = [];
  List<WorkoutSession> _sessions = [];
  Map<String, RoutineMetadata> _metadata = {};
  List<RoutineFolder> _folders = [];
  RoutineSortOption _sortOption = RoutineSortOption.smart;
  String? _draftRaw;

  bool get initialized => _initialized;
  List<WorkoutTemplate> get routines => _sortedRoutines();
  List<RoutineFolder> get sortedFolders {
    final items = [..._folders];
    items.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.unmodifiable(items);
  }
  bool get hasRoutines => _routines.isNotEmpty;
  bool get hasDraft => _draftRaw != null;
  RoutineSortOption get sortOption => _sortOption;
  List<RoutineFolder> get folders => sortedFolders;
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);

  DateTime? get draftStart {
    if (_draftRaw == null) return null;
    try {
      final json = jsonDecode(_draftRaw!) as Map<String, dynamic>;
      return DateTime.tryParse(json['sessionStart'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  WorkoutSession? get latestSession => _sessions.isEmpty ? null : _sessions.last;

  bool get hasSessionToday {
    final last = latestSession;
    if (last == null) return false;
    final now = DateTime.now();
    return now.year == last.date.year && now.month == last.date.month && now.day == last.date.day;
  }

  RoutineMetadata metadataFor(String routineId) {
    return _metadata[routineId] ?? const RoutineMetadata();
  }

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    _routinesRepository.watchRoutines().addListener(_onRoutinesChanged);
    await _loadTemplates();
    await _loadSessions();
    await _loadMetadata();
    await _loadDraft();
    await _loadSortOption();
    await _loadFolders();
    WorkoutInProgressController.instance.syncFromRaw(_draftRaw);
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadTemplates();
    await _loadSessions();
    await _loadMetadata();
    await _loadDraft();
    await _loadSortOption();
    await _loadFolders();
    WorkoutInProgressController.instance.syncFromRaw(_draftRaw);
    notifyListeners();
  }

  Future<void> setSortOption(RoutineSortOption option) async {
    _sortOption = option;
    await _prefs?.setString(_sortKey, option.name);
    notifyListeners();
  }

  Future<void> discardDraft() async {
    _draftRaw = null;
    await _prefs?.remove(_draftKey);
    WorkoutInProgressController.instance.syncFromRaw(null);
    notifyListeners();
  }

  Future<void> markRoutineStarted(WorkoutTemplate routine) async {
    final current = metadataFor(routine.id);
    _metadata[routine.id] = current.copyWith(
      usageCount: current.usageCount + 1,
      lastUsedAt: DateTime.now(),
    );
    await _persistMetadata();
    notifyListeners();
  }

  Future<void> togglePinned(WorkoutTemplate routine) async {
    final current = metadataFor(routine.id);
    _metadata[routine.id] = current.copyWith(pinned: !current.pinned);
    await _persistMetadata();
    notifyListeners();
  }

  Future<void> deleteRoutine(WorkoutTemplate routine) async {
    _routines = _routines.where((element) => element.id != routine.id).toList();
    _metadata.remove(routine.id);
    await _persistTemplates();
    await _persistMetadata();
    notifyListeners();
  }

  Future<void> duplicateRoutine(WorkoutTemplate routine) async {
    final duplicated = WorkoutTemplate(
      id: _uuid.v4(),
      name: '${routine.name} (copia)',
      type: routine.type,
      origin: TemplateOrigin.user,
      activityName: routine.activityName,
      folderId: routine.folderId,
      exercises: routine.exercises
          .map((exercise) => exercise.copyWith(
                id: _uuid.v4(),
                sets: exercise.sets.map((set) => set.copyWith(id: _uuid.v4())).toList(),
              ))
          .toList(),
    );
    _routines = [..._routines, duplicated];
    await _persistTemplates();
    notifyListeners();
  }

  Future<void> renameRoutine(WorkoutTemplate routine, String name) async {
    _routines = _routines
        .map((element) =>
            element.id == routine.id
                ? WorkoutTemplate(
                    id: element.id,
                    name: name,
                    type: element.type,
                    origin: element.origin,
                    activityName: element.activityName,
                    folderId: element.folderId,
                    exercises: element.exercises,
                  )
                : element)
        .toList();
    await _persistTemplates();
    notifyListeners();
  }


  Future<void> createFolder(String name) async {
    final nextSortOrder = _folders.isEmpty
        ? 0
        : _folders.map((folder) => folder.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    _folders = [..._folders, RoutineFolder(id: _uuid.v4(), name: name, sortOrder: nextSortOrder)];
    await _persistFolders();
    notifyListeners();
  }

  Future<void> renameFolder(String folderId, String name) async {
    _folders = _folders
        .map((f) =>
            f.id == folderId
                ? RoutineFolder(
                    id: f.id,
                    name: name,
                    sortOrder: f.sortOrder,
                    color: f.color,
                    icon: f.icon,
                  )
                : f)
        .toList();
    await _persistFolders();
    notifyListeners();
  }

  Future<void> deleteFolder(String folderId) async {
    _folders = _folders.where((f) => f.id != folderId).toList();
    _routines = _routines
        .map((r) => r.folderId == folderId
            ? WorkoutTemplate(
                id: r.id,
                name: r.name,
                type: r.type,
                origin: r.origin,
                activityName: r.activityName,
                folderId: null,
                exercises: r.exercises,
              )
            : r)
        .toList();
    await _persistFolders();
    await _persistTemplates();
    notifyListeners();
  }

  Future<void> moveRoutineToFolder(WorkoutTemplate routine, String? folderId) async {
    _routines = _routines
        .map((r) => r.id == routine.id
            ? WorkoutTemplate(
                id: r.id,
                name: r.name,
                type: r.type,
                origin: r.origin,
                activityName: r.activityName,
                folderId: folderId,
                exercises: r.exercises,
              )
            : r)
        .toList();
    await _persistTemplates();
    notifyListeners();
  }

  List<WorkoutTemplate> routinesForFolder(String? folderId) {
    return routines.where((r) => r.folderId == folderId).toList();
  }
  int estimatedDuration(WorkoutTemplate routine) {
    if (routine.exercises.isEmpty) return 20;
    final sets = routine.exercises.fold<int>(0, (sum, e) => sum + e.sets.length);
    final effectiveSets = sets == 0 ? routine.exercises.length * 3 : sets;
    return (effectiveSets * 2.5).round().clamp(15, 120);
  }

  List<WorkoutTemplate> _sortedRoutines() {
    final items = [..._routines];
    int alpha(WorkoutTemplate a, WorkoutTemplate b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (_sortOption) {
      case RoutineSortOption.alphabetical:
        items.sort(alpha);
        break;
      case RoutineSortOption.recent:
        items.sort((a, b) {
          final aDate = metadataFor(a.id).lastUsedAt;
          final bDate = metadataFor(b.id).lastUsedAt;
          if (aDate == null && bDate == null) return alpha(a, b);
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          final comp = bDate.compareTo(aDate);
          return comp == 0 ? alpha(a, b) : comp;
        });
        break;
      case RoutineSortOption.mostUsed:
        items.sort((a, b) {
          final usageComp = metadataFor(b.id).usageCount.compareTo(metadataFor(a.id).usageCount);
          if (usageComp != 0) return usageComp;
          final aDate = metadataFor(a.id).lastUsedAt;
          final bDate = metadataFor(b.id).lastUsedAt;
          if (aDate != null && bDate != null) {
            final dateComp = bDate.compareTo(aDate);
            if (dateComp != 0) return dateComp;
          }
          return alpha(a, b);
        });
        break;
      case RoutineSortOption.smart:
        items.sort((a, b) {
          final am = metadataFor(a.id);
          final bm = metadataFor(b.id);
          final pinComp = (bm.pinned ? 1 : 0).compareTo(am.pinned ? 1 : 0);
          if (pinComp != 0) return pinComp;
          final usageComp = bm.usageCount.compareTo(am.usageCount);
          if (usageComp != 0) return usageComp;
          final aDate = am.lastUsedAt;
          final bDate = bm.lastUsedAt;
          if (aDate == null && bDate == null) return alpha(a, b);
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          final dateComp = bDate.compareTo(aDate);
          return dateComp == 0 ? alpha(a, b) : dateComp;
        });
        break;
    }
    return items;
  }

  Future<void> _loadTemplates() async {
    _routines = await _routinesRepository.getAllRoutines();
  }

  Future<void> _persistTemplates() async {
    await _routinesRepository.replaceRoutines(_routines);
  }

  Future<void> _loadSessions() async {
    final fromRepo = await _workoutRepository.listSessions();
    final raw = _prefs?.getString(_sessionsKey);
    final legacy = <WorkoutSession>[];
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      legacy.addAll(decoded.map((e) => WorkoutSession.fromJson(e as Map<String, dynamic>)));
    }
    _sessions = [...legacy, ...fromRepo]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _loadMetadata() async {
    final raw = _prefs?.getString(_metadataKey);
    if (raw == null) {
      _metadata = {};
      return;
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _metadata = decoded.map(
      (key, value) => MapEntry(
        key,
        RoutineMetadata.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> _persistMetadata() async {
    final payload = jsonEncode(
      _metadata.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs?.setString(_metadataKey, payload);
  }


  Future<void> _loadFolders() async {
    final raw = _prefs?.getString(_foldersKey);
    if (raw == null) {
      _folders = [];
      return;
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    _folders = decoded.map((e) => RoutineFolder.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _persistFolders() async {
    await _prefs?.setString(_foldersKey, jsonEncode(_folders.map((e) => e.toJson()).toList()));
  }

  Future<void> _loadDraft() async {
    _draftRaw = _prefs?.getString(_draftKey);
  }


  void _onRoutinesChanged() {
    _routines = _routinesRepository.watchRoutines().value;
    notifyListeners();
  }

  @override
  void dispose() {
    _routinesRepository.watchRoutines().removeListener(_onRoutinesChanged);
    super.dispose();
  }

  Future<void> _loadSortOption() async {
    final raw = _prefs?.getString(_sortKey);
    if (raw == null) return;
    _sortOption = RoutineSortOption.values.firstWhere(
      (element) => element.name == raw,
      orElse: () => RoutineSortOption.smart,
    );
  }
}
