import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/data/account_storage_scope.dart';
import '../domain/training_program.dart';

/// Durable notes/programs use the existing Hive runtime, never a fake widget
/// store. Each record is versioned independently, and corrupt/unknown records
/// remain intact. This box is local-only; no new remote integration is implied.
class TrainingLibraryRepository {
  TrainingLibraryRepository() : scope = AccountStorageScope.current;
  final String scope;
  String get boxName =>
      AccountStorageScope.boxName('fit_training_library_v1', scope);
  static final _opening = <String, Future<Box<String>>>{};
  static final _writes = <String, Future<void>>{};
  static final _revisions = <String, ValueNotifier<int>>{};
  ValueListenable<int> get revision =>
      _revisions.putIfAbsent(scope, () => ValueNotifier(0));
  int unreadablePrograms = 0;
  Future<Box<String>> get _box async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    final opening = _opening.putIfAbsent(
      boxName,
      () => Hive.openBox<String>(boxName),
    );
    try {
      return await opening;
    } finally {
      if (identical(_opening[boxName], opening)) _opening.remove(boxName);
    }
  }

  Future<T> _serialize<T>(Future<T> Function() action) async {
    final previous = _writes[boxName], gate = Completer<void>();
    _writes[boxName] = gate.future;
    try {
      if (previous != null) await previous;
      return await action();
    } finally {
      if (identical(_writes[boxName], gate.future)) _writes.remove(boxName);
      gate.complete();
    }
  }

  void _changed() =>
      _revisions.putIfAbsent(scope, () => ValueNotifier(0)).value++;
  Map<String, dynamic> _read(String raw) {
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    if (data['schemaVersion'] != 1) {
      throw const FormatException(
        'Versión de datos no soportada. Se conserva el original.',
      );
    }
    return data;
  }

  Future<String> exerciseNote(String exerciseId) async {
    final raw = (await _box).get('note:$exerciseId');
    return raw == null ? '' : _noteRecord(raw, exerciseId)['text'] as String;
  }

  Future<void> saveExerciseNote(String exerciseId, String text) =>
      _serialize(() async {
        if (exerciseId.isEmpty) {
          throw ArgumentError('Ejercicio sin identificador');
        }
        final box = await _box, key = 'note:$exerciseId';
        final existing = box.get(key);
        if (existing != null) {
          _noteRecord(
            existing,
            exerciseId,
          ); // Never overwrite unreadable user data.
        }
        if (text.trim().isEmpty) {
          await box.delete(key);
        } else {
          await box.put(
            key,
            jsonEncode({
              'schemaVersion': 1,
              'exerciseId': exerciseId,
              'text': text,
              'updatedAt': DateTime.now().toUtc().toIso8601String(),
            }),
          );
        }
        _changed();
      });
  Map<String, dynamic> _noteRecord(String raw, String exerciseId) {
    final record = _read(raw);
    if (record['text'] is! String || record['exerciseId'] != exerciseId) {
      throw const FormatException('Nota ilegible. Se conserva el original.');
    }
    return record;
  }

  Future<List<TrainingProgram>> programs() async {
    final box = await _box, programs = <TrainingProgram>[];
    unreadablePrograms = 0;
    for (final key in box.keys.whereType<String>().where(
      (k) => k.startsWith('program:'),
    )) {
      try {
        programs.add(TrainingProgram.fromJson(_read(box.get(key)!)));
      } catch (_) {
        unreadablePrograms++;
      }
    }
    return programs;
  }

  Future<void> saveProgram(TrainingProgram program) => _serialize(() async {
    final error = program.validationError;
    if (error != null) throw ArgumentError(error);
    final box = await _box, key = 'program:${program.id}';
    if (box.get(key) case final raw?) TrainingProgram.fromJson(_read(raw));
    await box.put(key, jsonEncode(program.toJson()));
    _changed();
  });
  Future<void> deleteProgram(String id) => _serialize(() async {
    final box = await _box, key = 'program:$id';
    if (box.get(key) case final raw?) TrainingProgram.fromJson(_read(raw));
    await box.delete(key);
    _changed();
  });
}
