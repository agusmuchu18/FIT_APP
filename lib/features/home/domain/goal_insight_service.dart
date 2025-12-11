import '../../../core/domain/entities.dart';

class GoalInsightData {
  GoalInsightData({
    required this.title,
    required this.subtitle,
    required this.metricPills,
    required this.insightText,
  });

  final String title;
  final String subtitle;
  final List<String> metricPills;
  final String insightText;
}

class GoalInsightService {
  GoalInsightData buildInsight({
    required UserPreferences? preferences,
    required int weeklyTrainingMinutes,
    required int trainingDays,
    required int targetSessions,
    required double averageSleepHours,
    required double sleepRegularityMinutes,
    required double averageCalories,
    required Macros averageDailyMacros,
  }) {
    final goal = preferences?.primaryGoal ?? 'Mejorar salud general';
    switch (goal) {
      case 'Ganar masa muscular':
        return _muscleGain(
          trainingDays: trainingDays,
          targetSessions: targetSessions,
          averageCalories: averageCalories,
          targetCalories: preferences?.targetCalories,
          averageProtein: averageDailyMacros.protein,
        );
      case 'Mejorar rendimiento deportivo':
        return _performance(
          trainingMinutes: weeklyTrainingMinutes,
          averageSleepHours: averageSleepHours,
          averageCarbs: averageDailyMacros.carbs,
        );
      case 'Bajar estrés':
        return _stressRelief(
          trainingDays: trainingDays,
          averageSleepHours: averageSleepHours,
          sleepRegularityMinutes: sleepRegularityMinutes,
        );
      default:
        return _generalHealth(
          trainingDays: trainingDays,
          targetSessions: targetSessions,
          averageSleepHours: averageSleepHours,
          averageCalories: averageCalories,
          targetCalories: preferences?.targetCalories,
        );
    }
  }

  GoalInsightData _generalHealth({
    required int trainingDays,
    required int targetSessions,
    required double averageSleepHours,
    required double averageCalories,
    required int? targetCalories,
  }) {
    final caloriesLabel = _calorieLabel(averageCalories, targetCalories);
    return GoalInsightData(
      title: 'Salud general',
      subtitle: 'Balance de la última semana',
      metricPills: [
        'Entrenamiento · $trainingDays/$targetSessions días',
        'Sueño · ${averageSleepHours.toStringAsFixed(1)} h',
        'Calorías · $caloriesLabel',
      ],
      insightText: 'Mantén la constancia y prioriza comidas completas.',
    );
  }

  GoalInsightData _muscleGain({
    required int trainingDays,
    required int targetSessions,
    required double averageCalories,
    required int? targetCalories,
    required int averageProtein,
  }) {
    final caloriesLabel = _calorieLabel(
      averageCalories,
      targetCalories,
      emphasizeSurplus: true,
    );
    return GoalInsightData(
      title: 'Masa muscular',
      subtitle: 'Enfoque de volumen y proteína',
      metricPills: [
        'Entrenamiento · $trainingDays/$targetSessions días',
        'Proteína · ${averageProtein}g/día',
        'Calorías · $caloriesLabel',
      ],
      insightText: 'Añade 1–2 series pesadas en tus compuestos clave.',
    );
  }

  GoalInsightData _performance({
    required int trainingMinutes,
    required double averageSleepHours,
    required int averageCarbs,
  }) {
    final trainingHours = (trainingMinutes / 60).toStringAsFixed(1);
    return GoalInsightData(
      title: 'Rendimiento deportivo',
      subtitle: 'Carga + recuperación',
      metricPills: [
        'Volumen · $trainingHours h/sem',
        'Sueño · ${averageSleepHours.toStringAsFixed(1)} h',
        'Carbs · ${averageCarbs}g/día',
      ],
      insightText: 'Agenda un día de técnica y movilidad para afinar tu forma.',
    );
  }

  GoalInsightData _stressRelief({
    required int trainingDays,
    required double averageSleepHours,
    required double sleepRegularityMinutes,
  }) {
    return GoalInsightData(
      title: 'Bajar estrés',
      subtitle: 'Rutina suave y sueño estable',
      metricPills: [
        'Entrenamiento · $trainingDays días suaves',
        'Sueño · ${averageSleepHours.toStringAsFixed(1)} h',
        'Regularidad · ${sleepRegularityMinutes.round()} min',
      ],
      insightText: 'Prioriza caminatas y acostarte a la misma hora diario.',
    );
  }

  String _calorieLabel(
    double averageCalories,
    int? targetCalories, {
    bool emphasizeSurplus = false,
  }) {
    if (targetCalories == null || targetCalories == 0) {
      return 'sin objetivo';
    }

    final delta = averageCalories - targetCalories;
    final threshold = targetCalories * 0.05;

    if (delta.abs() <= threshold) return 'en rango';
    if (delta > 0) return emphasizeSurplus ? 'superávit' : 'ligero superávit';
    return 'déficit controlado';
  }
}
