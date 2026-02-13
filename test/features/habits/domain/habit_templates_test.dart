import 'package:fit_app/features/habits/domain/habit_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cada categoría tiene al menos 10 templates', () {
    for (final category in habitCategories) {
      final count = kHabitTemplates.where((template) => template.category == category).length;
      expect(count, greaterThanOrEqualTo(10), reason: 'Categoría $category tiene $count templates');
    }
  });

  test('todos los templateId son únicos', () {
    final ids = kHabitTemplates.map((template) => template.templateId).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('los templates construyen hábitos con sourceTemplateId y configuración consistente', () {
    for (final template in kHabitTemplates) {
      final built = template.buildHabit();
      expect(built.sourceTemplateId, template.templateId);
      expect(built.category, template.category);
      expect(built.frequency, template.defaultFrequency);
      expect(built.isCountable, template.isCountable);
    }
  });
}
