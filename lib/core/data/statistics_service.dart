import '../domain/entities.dart';

class NutritionMetrics {
  NutritionMetrics({
    required this.date,
    required this.totalCalories,
    required this.macros,
  });

  final DateTime date;
  final int totalCalories;
  final Macros macros;
}

class StatisticsService {
  final Map<String, NutritionMetrics> _nutritionHistory = {};

  Future<void> recordNutritionMetrics(NutritionMetrics metrics) async {
    _nutritionHistory[_dateKey(metrics.date)] = metrics;
  }

  Future<NutritionMetrics?> getNutritionMetrics(DateTime date) async {
    return _nutritionHistory[_dateKey(date)];
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
