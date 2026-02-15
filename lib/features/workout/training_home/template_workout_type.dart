import '../pro/models/workout_models.dart';

enum TemplateWorkoutType { gym, sport, other }

WorkoutType toWorkoutType(TemplateWorkoutType type) {
  switch (type) {
    case TemplateWorkoutType.gym:
      return WorkoutType.strength;
    case TemplateWorkoutType.sport:
      return WorkoutType.sport;
    case TemplateWorkoutType.other:
      return WorkoutType.custom;
  }
}

String typeLabel(TemplateWorkoutType type) {
  switch (type) {
    case TemplateWorkoutType.gym:
      return 'Gym';
    case TemplateWorkoutType.sport:
      return 'Deporte';
    case TemplateWorkoutType.other:
      return 'Otros';
  }
}
