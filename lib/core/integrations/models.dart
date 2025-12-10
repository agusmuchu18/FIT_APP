import '../domain/entities.dart';

/// Supported platforms.
enum FitnessSource {
  healthKit,
  googleFit,
  fitbit,
}

/// Standardized data types retrieved from platform APIs.
enum FitnessDataType {
  workout,
  nutrition,
  sleep,
  steps,
}

/// Representation of an item fetched from a health platform.
class ExternalFitnessSample {
  ExternalFitnessSample.workout({
    required this.externalId,
    required this.title,
    required this.durationMinutes,
    required this.intensity,
    required this.source,
    this.notes,
    this.startTime,
    this.endTime,
  })  : type = FitnessDataType.workout,
        calories = null,
        macros = null,
        hours = null;

  ExternalFitnessSample.nutrition({
    required this.externalId,
    required this.title,
    required this.calories,
    required this.macros,
    required this.source,
    this.notes,
    this.startTime,
    this.endTime,
  })  : type = FitnessDataType.nutrition,
        durationMinutes = null,
        intensity = null,
        hours = null;

  ExternalFitnessSample.sleep({
    required this.externalId,
    required this.hours,
    required this.quality,
    required this.source,
    this.notes,
    this.startTime,
    this.endTime,
  })  : type = FitnessDataType.sleep,
        title = null,
        durationMinutes = null,
        intensity = null,
        calories = null,
        macros = null;

  ExternalFitnessSample.steps({
    required this.externalId,
    required this.durationMinutes,
    required this.source,
    this.startTime,
    this.endTime,
    this.notes,
  })  : type = FitnessDataType.steps,
        title = 'Steps',
        intensity = 'light',
        calories = null,
        macros = null,
        hours = null,
        quality = 'auto';

  final String externalId;
  final FitnessDataType type;
  final FitnessSource source;

  final String? title;
  final int? durationMinutes;
  final String? intensity;
  final int? calories;
  final Macros? macros;
  final double? hours;
  final String? quality;
  final String? notes;
  final DateTime? startTime;
  final DateTime? endTime;

  WorkoutEntry toWorkout() {
    if (type != FitnessDataType.workout && type != FitnessDataType.steps) {
      throw StateError('Sample is not a workout');
    }
    return WorkoutEntry(
      id: _deriveId(),
      name: title ?? 'Workout',
      durationMinutes: durationMinutes ?? 0,
      intensity: intensity ?? 'auto',
      notes: notes,
      template: source.name,
    );
  }

  MealEntry toMeal() {
    if (type != FitnessDataType.nutrition) {
      throw StateError('Sample is not nutrition');
    }
    return MealEntry(
      id: _deriveId(),
      title: title ?? 'Meal',
      calories: calories ?? 0,
      macros: macros ?? Macros(carbs: 0, protein: 0, fat: 0),
      template: source.name,
      notes: notes,
    );
  }

  SleepEntry toSleep() {
    if (type != FitnessDataType.sleep) {
      throw StateError('Sample is not sleep');
    }
    return SleepEntry(
      id: _deriveId(),
      hours: hours ?? 0,
      quality: quality ?? 'auto',
      notes: notes,
      template: source.name,
    );
  }

  String _deriveId() {
    final timeFragment = startTime?.millisecondsSinceEpoch ?? 0;
    return '${source.name}-$externalId-$timeFragment';
  }
}
