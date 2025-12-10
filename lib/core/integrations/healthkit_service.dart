import 'package:flutter/services.dart';

import 'models.dart';
import 'platform_integration_service.dart';

/// HealthKit implementation using a [MethodChannel].
class HealthKitService implements PlatformIntegrationService {
  HealthKitService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('fit_app/integrations/healthkit');

  final MethodChannel _channel;

  @override
  FitnessSource get source => FitnessSource.healthKit;

  @override
  Future<bool> hasPermissions() async {
    final result = await _channel.invokeMethod<bool>('hasPermissions');
    return result ?? false;
  }

  @override
  Future<bool> requestPermissions() async {
    final result = await _channel.invokeMethod<bool>('requestPermissions');
    return result ?? false;
  }

  @override
  Future<void> enableBackgroundSync() async {
    await _channel.invokeMethod<void>('enableBackgroundDelivery');
  }

  @override
  Future<List<ExternalFitnessSample>> fetchLatestSamples() async {
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('fetchSamples');
    final samples = raw ?? [];
    return samples.map(_mapSample).toList();
  }

  ExternalFitnessSample _mapSample(Map<dynamic, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'workout':
        return ExternalFitnessSample.workout(
          externalId: json['id'] as String,
          title: (json['title'] ?? 'Workout') as String,
          durationMinutes: (json['duration'] as num?)?.toInt() ?? 0,
          intensity: (json['intensity'] ?? 'auto') as String,
          source: source,
          notes: json['notes'] as String?,
          startTime: _parseDate(json['start']),
          endTime: _parseDate(json['end']),
        );
      case 'sleep':
        return ExternalFitnessSample.sleep(
          externalId: json['id'] as String,
          hours: (json['hours'] as num?)?.toDouble() ?? 0,
          quality: (json['quality'] ?? 'auto') as String,
          source: source,
          notes: json['notes'] as String?,
          startTime: _parseDate(json['start']),
          endTime: _parseDate(json['end']),
        );
      case 'nutrition':
        return ExternalFitnessSample.nutrition(
          externalId: json['id'] as String,
          title: (json['title'] ?? 'Meal') as String,
          calories: (json['calories'] as num?)?.toInt() ?? 0,
          macros: _parseMacros(json['macros'] as Map<dynamic, dynamic>?),
          source: source,
          notes: json['notes'] as String?,
          startTime: _parseDate(json['start']),
          endTime: _parseDate(json['end']),
        );
      case 'steps':
      default:
        return ExternalFitnessSample.steps(
          externalId: json['id'] as String,
          durationMinutes: (json['minutes'] as num?)?.toInt() ?? 0,
          source: source,
          notes: json['notes'] as String?,
          startTime: _parseDate(json['start']),
          endTime: _parseDate(json['end']),
        );
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Macros _parseMacros(Map<dynamic, dynamic>? raw) {
    return Macros(
      carbs: (raw?['carbs'] as num?)?.toInt() ?? 0,
      protein: (raw?['protein'] as num?)?.toInt() ?? 0,
      fat: (raw?['fat'] as num?)?.toInt() ?? 0,
    );
  }
}
