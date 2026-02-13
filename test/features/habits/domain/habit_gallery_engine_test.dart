import 'package:fit_app/features/habits/domain/habit_gallery_engine.dart';
import 'package:fit_app/features/habits/domain/habit_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scoring prioriza strength para objetivo ganar masa', () {
    const template = HabitTemplate(
      templateId: 'x',
      category: 'Sugerido',
      title: 'Fuerza',
      description: 'Trabajo de fuerza',
      iconKey: 'workout',
      defaultColor: 0,
      defaultFrequency: HabitFrequency.daily,
      isCountable: false,
      tags: ['strength', 'training'],
    );

    final score = habitTemplateScore(
      template: template,
      user: const HabitUserContext(goalType: GoalType.muscleGain, trains: true),
      popularityScore: 0,
    );
    expect(score, greaterThanOrEqualTo(4));
  });

  test('scoring penaliza gym cuando no entrena', () {
    const template = HabitTemplate(
      templateId: 'x',
      category: 'Sugerido',
      title: 'Dominadas',
      description: 'Gym',
      iconKey: 'workout',
      defaultColor: 0,
      defaultFrequency: HabitFrequency.daily,
      isCountable: false,
      tags: ['gym', 'pullups', 'strength'],
      requiresTraining: true,
    );

    final score = habitTemplateScore(
      template: template,
      user: const HabitUserContext(goalType: GoalType.maintenance, trains: false),
      popularityScore: 0,
    );
    expect(score, lessThan(0));
  });

  test('search filtra por categoria actual', () {
    final results = buildGalleryTemplates(
      allTemplates: kHabitTemplates,
      currentCategory: 'Salud',
      searchScope: HabitSearchScope.currentCategory,
      query: 'agua',
      sortMode: HabitSortMode.alphabetical,
      user: const HabitUserContext(goalType: GoalType.unknown, trains: false),
      popularityByTemplate: const {},
      alreadyAddedTemplateIds: const {},
    );

    expect(results, everyElement(predicate<HabitTemplate>((t) => t.category == 'Salud')));
  });
}
