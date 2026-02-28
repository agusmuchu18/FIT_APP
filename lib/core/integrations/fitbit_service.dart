import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/services.dart';

import '../domain/entities.dart';
import 'models.dart';
import 'platform_integration_service.dart';

/// High-quality integration result for UI/analytics.
/// Use the `...Result()` methods for fine-grained error handling.
///
/// Keeps PlatformIntegrationService compatibility by delegating the required
/// methods to the pro methods and returning safe fallbacks.
enum IntegrationErrorCode {
  missingPlugin,
  platformError,
  timeout,
  invalidPayload,
  unauthorized,
  forbidden,
  cancelled,
  unknown,
}

class IntegrationFailure {
  const IntegrationFailure({
    required this.code,
    required this.message,
    this.platformCode,
    this.details,
    this.stackTrace,
  });

  final IntegrationErrorCode code;
  final String message;

  /// Optional: raw PlatformException.code or custom native error code.
  final String? platformCode;

  /// Optional: any extra details (native message, payload snapshot, etc).
  final Object? details;

  final StackTrace? stackTrace;

  @override
  String toString() =>
      'IntegrationFailure(code: $code, message: $message, platformCode: $platformCode, details: $details)';
}

class IntegrationResult<T> {
  const IntegrationResult._({this.data, this.failure});

  final T? data;
  final IntegrationFailure? failure;

  bool get isOk => failure == null;
  bool get isErr => failure != null;

  static IntegrationResult<T> ok<T>(T data) => IntegrationResult<T>._(data: data);
  static IntegrationResult<T> err<T>(IntegrationFailure failure) =>
      IntegrationResult<T>._(failure: failure);

  /// Convenience for UI: returns data when ok, otherwise fallback.
  T unwrapOr(T fallback) => data ?? fallback;
}

/// Fitbit implementation backed by a MethodChannel.
/// - Safe fallbacks for interface methods.
/// - Pro `IntegrationResult` variants for UI decision-making.
/// - Validates payload to avoid crashes.
/// - Adds timeout + observability.
class FitbitService implements PlatformIntegrationService {
  FitbitService({
    MethodChannel? channel,
    Duration timeout = const Duration(seconds: 8),
    void Function(String message, Object error, StackTrace st)? onError,
  })  : _channel = channel ?? const MethodChannel('fit_app/integrations/fitbit'),
        _timeout = timeout,
        _onError = onError;

  final MethodChannel _channel;
  final Duration _timeout;
  final void Function(String message, Object error, StackTrace st)? _onError;

  @override
  FitnessSource get source => FitnessSource.fitbit;

  // ---------------------------------------------------------------------------
  // PlatformIntegrationService (compatible, safe fallbacks)
  // ---------------------------------------------------------------------------

  @override
  Future<bool> hasPermissions() async =>
      (await hasPermissionsResult()).unwrapOr(false);

  @override
  Future<bool> requestPermissions() async =>
      (await requestPermissionsResult()).unwrapOr(false);

  @override
  Future<void> enableBackgroundSync() async {
    await enableBackgroundSyncResult();
  }

  @override
  Future<List<ExternalFitnessSample>> fetchLatestSamples() async =>
      (await fetchLatestSamplesResult()).unwrapOr(const <ExternalFitnessSample>[]);

  // ---------------------------------------------------------------------------
  // PRO API (use these in UI to differentiate errors)
  // ---------------------------------------------------------------------------

  Future<IntegrationResult<bool>> hasPermissionsResult() async {
    return _guard<bool>(
      op: 'hasPermissions',
      call: () async {
        final result = await _channel.invokeMethod<bool>('hasPermissions');
        return result ?? false;
      },
    );
  }

  Future<IntegrationResult<bool>> requestPermissionsResult() async {
    return _guard<bool>(
      op: 'requestPermissions',
      call: () async {
        final result = await _channel.invokeMethod<bool>('requestPermissions');
        return result ?? false;
      },
    );
  }

  Future<IntegrationResult<void>> enableBackgroundSyncResult() async {
    return _guard<void>(
      op: 'enableBackgroundSync',
      call: () async {
        await _channel.invokeMethod<void>('enableBackgroundSync');
        return null;
      },
    );
  }

  Future<IntegrationResult<List<ExternalFitnessSample>>> fetchLatestSamplesResult() async {
    return _guard<List<ExternalFitnessSample>>(
      op: 'fetchSamples',
      call: () async {
        final raw = await _channel.invokeMethod<List<dynamic>>('fetchSamples');
        final list = raw ?? const <dynamic>[];

        final out = <ExternalFitnessSample>[];
        for (final item in list) {
          final map = _asStringKeyedMap(item);
          if (map == null) continue;
          out.add(_mapSample(map));
        }
        return out;
      },
      mapPlatformException: _mapFetchSamplesPlatformException,
    );
  }

  // ---------------------------------------------------------------------------
  // Error mapping (customize per operation if needed)
  // ---------------------------------------------------------------------------

  IntegrationFailure _mapFetchSamplesPlatformException(PlatformException e, StackTrace st) {
    // If your native side uses consistent codes, map them here.
    // Examples (adjust to your implementation):
    // - "UNAUTHORIZED" (token expired)
    // - "FORBIDDEN" (user denied)
    // - "CANCELLED" (user cancelled login)
    // - "INVALID_PAYLOAD" (native bug)
    final code = (e.code).toUpperCase();

    if (code.contains('UNAUTH')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.unauthorized,
        message: 'Fitbit: sesión expirada o no autenticado.',
        platformCode: e.code,
        details: e.message,
        stackTrace: st,
      );
    }
    if (code.contains('FORBID') || code.contains('DENIED')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.forbidden,
        message: 'Fitbit: permisos denegados.',
        platformCode: e.code,
        details: e.message,
        stackTrace: st,
      );
    }
    if (code.contains('CANCEL')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.cancelled,
        message: 'Fitbit: el usuario canceló la operación.',
        platformCode: e.code,
        details: e.message,
        stackTrace: st,
      );
    }
    if (code.contains('INVALID_PAYLOAD')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.invalidPayload,
        message: 'Fitbit: respuesta inválida desde la capa nativa.',
        platformCode: e.code,
        details: e.details ?? e.message,
        stackTrace: st,
      );
    }

    return IntegrationFailure(
      code: IntegrationErrorCode.platformError,
      message: 'Fitbit: error de plataforma.',
      platformCode: e.code,
      details: e.details ?? e.message,
      stackTrace: st,
    );
  }

  // ---------------------------------------------------------------------------
  // Guard wrapper (timeout + categorized failures)
  // ---------------------------------------------------------------------------

  Future<IntegrationResult<T>> _guard<T>({
    required String op,
    required Future<T> Function() call,
    IntegrationFailure Function(PlatformException e, StackTrace st)? mapPlatformException,
  }) async {
    try {
      final value = await call().timeout(_timeout);
      return IntegrationResult.ok<T>(value);
    } on MissingPluginException catch (e, st) {
      _report('Fitbit $op missing plugin', e, st);
      return IntegrationResult.err<T>(
        IntegrationFailure(
          code: IntegrationErrorCode.missingPlugin,
          message: 'Fitbit no está disponible en esta plataforma/build.',
          details: e.toString(),
          stackTrace: st,
        ),
      );
    } on PlatformException catch (e, st) {
      _report('Fitbit $op platform error', e, st);
      final failure = (mapPlatformException ?? _defaultPlatformExceptionMapper)(e, st);
      return IntegrationResult.err<T>(failure);
    } on TimeoutException catch (e, st) {
      _report('Fitbit $op timeout', e, st);
      return IntegrationResult.err<T>(
        IntegrationFailure(
          code: IntegrationErrorCode.timeout,
          message: 'Fitbit tardó demasiado en responder.',
          details: e.toString(),
          stackTrace: st,
        ),
      );
    } catch (e, st) {
      _report('Fitbit $op unexpected error', e, st);
      return IntegrationResult.err<T>(
        IntegrationFailure(
          code: IntegrationErrorCode.unknown,
          message: 'Error inesperado en Fitbit.',
          details: e,
          stackTrace: st,
        ),
      );
    }
  }

  IntegrationFailure _defaultPlatformExceptionMapper(PlatformException e, StackTrace st) {
    final code = (e.code).toUpperCase();

    if (code.contains('UNAUTH')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.unauthorized,
        message: 'Sesión expirada o no autenticado.',
        platformCode: e.code,
        details: e.details ?? e.message,
        stackTrace: st,
      );
    }
    if (code.contains('FORBID') || code.contains('DENIED')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.forbidden,
        message: 'Permisos denegados.',
        platformCode: e.code,
        details: e.details ?? e.message,
        stackTrace: st,
      );
    }
    if (code.contains('CANCEL')) {
      return IntegrationFailure(
        code: IntegrationErrorCode.cancelled,
        message: 'Operación cancelada por el usuario.',
        platformCode: e.code,
        details: e.details ?? e.message,
        stackTrace: st,
      );
    }

    return IntegrationFailure(
      code: IntegrationErrorCode.platformError,
      message: 'Error de plataforma.',
      platformCode: e.code,
      details: e.details ?? e.message,
      stackTrace: st,
    );
  }

  // ---------------------------------------------------------------------------
  // Mapping (robust)
  // ---------------------------------------------------------------------------

  ExternalFitnessSample _mapSample(Map<String, dynamic> json) {
    final type = _asString(json['type'])?.toLowerCase();

    final externalId =
        _asString(json['id']) ?? _asString(json['externalId']) ?? 'unknown';
    final notes = _asString(json['notes']);
    final startTime = _parseDate(json['start'] ?? json['startTime']);
    final endTime = _parseDate(json['end'] ?? json['endTime']);

    switch (type) {
      case 'sleep':
        return ExternalFitnessSample.sleep(
          externalId: externalId,
          hours: _asDouble(json['hours'], fallback: 0),
          quality: _asString(json['quality']) ?? 'auto',
          source: source,
          notes: notes,
          startTime: startTime,
          endTime: endTime,
        );

      case 'nutrition':
        return ExternalFitnessSample.nutrition(
          externalId: externalId,
          title: _asString(json['title']) ?? 'Meal',
          calories: _asInt(json['calories'], fallback: 0),
          macros: _parseMacros(_asStringKeyedMap(json['macros'])),
          source: source,
          notes: notes,
          startTime: startTime,
          endTime: endTime,
        );

      case 'steps':
        return ExternalFitnessSample.steps(
          externalId: externalId,
          durationMinutes: _asInt(json['minutes'] ?? json['duration'], fallback: 0),
          source: source,
          notes: notes,
          startTime: startTime,
          endTime: endTime,
        );

      case 'workout':
      default:
        return ExternalFitnessSample.workout(
          externalId: externalId,
          title: _asString(json['title']) ?? 'Workout',
          durationMinutes: _asInt(json['duration'] ?? json['minutes'], fallback: 0),
          intensity: _asString(json['intensity']) ?? 'auto',
          source: source,
          notes: notes,
          startTime: startTime,
          endTime: endTime,
        );
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is int) {
      final ms = value < 1000000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
    }

    if (value is num) {
      final v = value.toInt();
      final ms = v < 1000000000000 ? v * 1000 : v;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: false);
    }

    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt;
    }

    return null;
  }

  Macros _parseMacros(Map<String, dynamic>? raw) {
    return Macros(
      carbs: _asInt(raw?['carbs'], fallback: 0),
      protein: _asInt(raw?['protein'], fallback: 0),
      fat: _asInt(raw?['fat'], fallback: 0),
    );
  }

  // ---------------------------------------------------------------------------
  // Safe parsing helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _asDouble(dynamic value, {required double fallback}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  void _report(String message, Object error, StackTrace st) {
    if (_onError != null) {
      _onError!(message, error, st);
      return;
    }
    dev.log(message, name: 'FitbitService', error: error, stackTrace: st);
  }
}
