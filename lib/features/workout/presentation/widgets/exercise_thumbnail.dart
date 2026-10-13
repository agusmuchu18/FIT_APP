import 'package:flutter/material.dart';

import '../../domain/workout_analytics.dart';
import '../../pro/models/workout_models.dart';
import 'workout_artwork.dart';

class ExerciseArtRegistry {
  static const specific = {
    'bench_press',
    'pull_up',
    'back_squat',
    'deadlift',
    'military_press',
    'plank',
  };
  static String? asset(String id) =>
      specific.contains(id) ? 'assets/images/workout/exercises/$id.webp' : null;
  static WorkoutArtCategory category(WorkoutExercise exercise) {
    final definition = WorkoutAnalytics.definition(exercise);
    final muscles =
        definition?.primaryMuscles.join(' ') ?? exercise.muscleGroup ?? '';
    if (muscles.contains('pecho')) return WorkoutArtCategory.push;
    if (muscles.contains('espalda')) return WorkoutArtCategory.pull;
    if (muscles.contains('pierna') ||
        muscles.contains('cuádriceps') ||
        muscles.contains('glúteo')) {
      return WorkoutArtCategory.legs;
    }
    if (muscles.contains('bíceps') ||
        muscles.contains('tríceps') ||
        muscles.contains('hombro')) {
      return WorkoutArtCategory.arms;
    }
    if (definition?.isTimed == true) return WorkoutArtCategory.mobility;
    return WorkoutArtCategory.mixed;
  }
}

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({super.key, required this.exercise, this.size = 72});
  final WorkoutExercise exercise;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = ExerciseArtRegistry.asset(exercise.id);
    final cacheWidth = size > 100
        ? 640
        : (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
            160,
            640,
          );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: asset == null
              ? WorkoutArtwork(
                  category: ExerciseArtRegistry.category(exercise),
                  cacheWidth: cacheWidth,
                )
              : Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: const Icon(Icons.fitness_center),
                  ),
                ),
        ),
      ),
    );
  }
}
