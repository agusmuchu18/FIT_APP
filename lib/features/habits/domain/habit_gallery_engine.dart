import '../../../core/domain/entities.dart';
import 'habit_models.dart';

enum HabitSearchScope { currentCategory, allCategories }

enum HabitSortMode { relevance, popularity, alphabetical }

enum GoalType { fatLoss, muscleGain, maintenance, unknown }

class HabitUserContext {
  const HabitUserContext({
    required this.goalType,
    required this.trains,
    this.experienceLevel,
  });

  final GoalType goalType;
  final bool trains;
  final String? experienceLevel;

  factory HabitUserContext.fromPreferences({
    required UserPreferences? preferences,
    required bool inferredTrains,
  }) {
    return HabitUserContext(
      goalType: _goalFromString(preferences?.primaryGoal),
      trains: inferredTrains,
      experienceLevel: preferences?.experienceLevel,
    );
  }
}

GoalType _goalFromString(String? raw) {
  final normalized = (raw ?? '').toLowerCase();
  if (normalized.contains('masa') || normalized.contains('muscle')) {
    return GoalType.muscleGain;
  }
  if (normalized.contains('grasa') || normalized.contains('fat') || normalized.contains('peso')) {
    return GoalType.fatLoss;
  }
  if (normalized.contains('mantenimiento') || normalized.contains('mantener')) {
    return GoalType.maintenance;
  }
  return GoalType.unknown;
}

double habitTemplateScore({
  required HabitTemplate template,
  required HabitUserContext user,
  required int popularityScore,
}) {
  var score = popularityScore * 0.2;
  final tags = template.tags.map((t) => t.toLowerCase()).toSet();

  switch (user.goalType) {
    case GoalType.muscleGain:
      if (_hasAny(tags, {'strength', 'protein', 'nutrition'})) score += 2;
      if (tags.contains('sleep')) score += 1;
      break;
    case GoalType.fatLoss:
      if (_hasAny(tags, {'steps', 'cardio', 'nutrition'})) score += 2;
      if (tags.contains('mindfulness')) score += 1;
      break;
    case GoalType.maintenance:
      if (_hasAny(tags, {'hydration', 'sleep', 'nutrition'})) score += 1;
      break;
    case GoalType.unknown:
      break;
  }

  if (user.trains) {
    if (tags.contains('training')) score += 2;
    if (_hasAny(tags, {'mobility', 'recovery'})) score += 1;
  } else {
    if (_hasAny(tags, {'gym', 'pullups', 'squats', 'strength'})) score -= 1;
    if (_hasAny(tags, {'walking', 'hydration', 'sleep', 'steps'})) score += 1;
  }

  if (template.requiresTraining == true && !user.trains) {
    score -= 1;
  }
  return score;
}

List<HabitTemplate> buildGalleryTemplates({
  required List<HabitTemplate> allTemplates,
  required String currentCategory,
  required HabitSearchScope searchScope,
  required String query,
  required HabitSortMode sortMode,
  required HabitUserContext user,
  required Map<String, int> popularityByTemplate,
  required Set<String> alreadyAddedTemplateIds,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  Iterable<HabitTemplate> templates = allTemplates;

  if (searchScope == HabitSearchScope.currentCategory) {
    templates = templates.where((t) => t.category == currentCategory);
  }

  if (normalizedQuery.isNotEmpty) {
    templates = templates.where((template) {
      final text = <String>[
        template.title,
        template.description,
        ...template.tags,
      ].join(' ').toLowerCase();
      return text.contains(normalizedQuery);
    });
  }

  var result = templates.toList(growable: false);

  if (currentCategory == 'Sugerido') {
    result = result
        .where((template) => !alreadyAddedTemplateIds.contains(template.templateId))
        .toList(growable: false);
  }

  switch (sortMode) {
    case HabitSortMode.relevance:
      result.sort((a, b) {
        final sb = habitTemplateScore(
          template: b,
          user: user,
          popularityScore: popularityByTemplate[b.templateId] ?? b.popularityScore,
        );
        final sa = habitTemplateScore(
          template: a,
          user: user,
          popularityScore: popularityByTemplate[a.templateId] ?? a.popularityScore,
        );
        return sb.compareTo(sa);
      });
      break;
    case HabitSortMode.popularity:
      result.sort((a, b) {
        final pb = popularityByTemplate[b.templateId] ?? b.popularityScore;
        final pa = popularityByTemplate[a.templateId] ?? a.popularityScore;
        return pb.compareTo(pa);
      });
      break;
    case HabitSortMode.alphabetical:
      result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      break;
  }

  if (currentCategory == 'Sugerido' && sortMode == HabitSortMode.relevance) {
    result = result.take(15).toList(growable: false);
  }

  return result;
}

bool _hasAny(Set<String> tags, Set<String> expected) => tags.any(expected.contains);
