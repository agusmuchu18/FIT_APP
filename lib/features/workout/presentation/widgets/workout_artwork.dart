import 'package:flutter/material.dart';

import '../../domain/workout_analytics.dart';

class WorkoutArtwork extends StatelessWidget {
  const WorkoutArtwork({
    super.key,
    this.category,
    this.hero = false,
    this.empty = false,
    this.cacheWidth,
  });
  final WorkoutArtCategory? category;
  final bool hero, empty;
  final int? cacheWidth;
  static String asset({
    WorkoutArtCategory? category,
    bool hero = false,
    bool empty = false,
  }) =>
      'assets/images/workout/${hero
          ? 'summary_hero'
          : empty
          ? 'history_empty'
          : 'history_${category?.name ?? 'mixed'}'}.webp';
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      asset(category: category, hero: hero, empty: empty),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            empty ? Icons.history : Icons.fitness_center,
            color: Theme.of(context).colorScheme.primary,
            size: hero ? 72 : 32,
          ),
        ),
      ),
    ),
  );
}
