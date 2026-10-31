import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/account_storage_scope.dart';
import '../body_measurement.dart';

/// Local source of truth, separate from social projections and sync queues.
/// Existing boxes/IDs are never migrated, reset or attributed to another user.
class BodyMeasurementRepository {
  BodyMeasurementRepository({String? owner, this.openBox})
    : owner = owner ?? AccountStorageScope.current;
  static const boxBase = 'fit_body_measurements_v1';
  final String owner;
  final Future<Box<String>> Function(String name)? openBox;
  static final Map<String, Future<void>> _writes = {};
  String get boxName => AccountStorageScope.boxName(boxBase, owner);
  void _checkOwner() {
    if (owner != AccountStorageScope.current) {
      throw StateError('La cuenta cambió. Volvé a abrir tus medidas.');
    }
  }

  Future<Box<String>> _box() async {
    _checkOwner();
    final box = await (openBox?.call(boxName) ?? Hive.openBox<String>(boxName));
    _checkOwner();
    final version = box.get('schema');
    if (version != null && version != '1' ||
        version == null && box.isNotEmpty) {
      throw const FormatException('Base de medidas no compatible.');
    }
    return box;
  }

  List<BodyMeasurement> _read(Box<String> box) {
    final result = <BodyMeasurement>[];
    for (final key in box.keys.where((key) => key != 'schema')) {
      final item = BodyMeasurement.fromJson(
        jsonDecode(box.get(key)!) as Map<String, dynamic>,
      );
      if (key != 'record:${item.id}') {
        throw const FormatException('Identificador de medida inválido.');
      }
      result.add(item);
    }
    result.sort((a, b) {
      final date = b.date.compareTo(a.date);
      if (date != 0) return date;
      final created = b.createdAt.compareTo(a.createdAt);
      return created != 0 ? created : a.id.compareTo(b.id);
    });
    return result;
  }

  Future<List<BodyMeasurement>> records() async {
    final box = await _box();
    _checkOwner();
    return List.unmodifiable(_read(box));
  }

  Future<void> _write(Future<void> Function(Box<String>) mutation) {
    final operation = (_writes[boxName] ?? Future<void>.value()).then((
      _,
    ) async {
      final box = await _box();
      _read(
        box,
      ); // Corrupt/future records must never be discarded or overwritten.
      _checkOwner();
      if (box.isEmpty) await box.put('schema', '1');
      _checkOwner();
      await mutation(box);
      _checkOwner();
    });
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _writes[boxName] = tail;
    tail.then((_) {
      if (identical(_writes[boxName], tail)) _writes.remove(boxName);
    });
    return operation;
  }

  Future<void> save({
    String? editingId,
    int? expectedRevision,
    required DateTime date,
    required Map<BodyMetric, BodyValue> values,
    String notes = '',
  }) {
    final snapshot = Map<BodyMetric, BodyValue>.of(values);
    final id = editingId ?? const Uuid().v4();
    return _write((box) async {
      final old = editingId == null ? null : box.get('record:$editingId');
      if (editingId != null && old == null) {
        throw StateError('El registro ya no está disponible.');
      }
      final previous = old == null
          ? null
          : BodyMeasurement.fromJson(jsonDecode(old) as Map<String, dynamic>);
      if (previous != null && previous.revision != expectedRevision) {
        throw StateError(
          'El registro cambió. Volvé a abrirlo antes de editar.',
        );
      }
      final now = DateTime.now();
      if (date.isAfter(DateTime(now.year, now.month, now.day))) {
        throw const FormatException('La fecha no puede ser futura.');
      }
      final item = BodyMeasurement(
        id: id,
        date: date,
        values: snapshot,
        notes: notes.trim(),
        createdAt: previous?.createdAt ?? now,
        revision: (previous?.revision ?? 0) + 1,
      );
      await box.put('record:$id', jsonEncode(item.toJson()));
    });
  }

  Future<void> delete(String id, {required int expectedRevision}) =>
      _write((box) async {
        final raw = box.get('record:$id');
        if (raw == null) return; // Repeated deletion is safe.
        final previous = BodyMeasurement.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (previous.revision != expectedRevision) {
          throw StateError(
            'El registro cambió. Volvé a abrirlo antes de eliminar.',
          );
        }
        await box.delete('record:$id');
      });
}
