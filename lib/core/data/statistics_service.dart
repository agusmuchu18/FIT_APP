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
  final List<SleepEntry> _sleepSamples = [];

  Future<void> recordNutritionMetrics(NutritionMetrics metrics) async {
    _nutritionHistory[_dateKey(metrics.date)] = metrics;
  }

  Future<NutritionMetrics?> getNutritionMetrics(DateTime date) async {
    return _nutritionHistory[_dateKey(date)];
  }

  Future<void> recordSleepInsights(SleepEntry entry) async {
    // Placeholder for analytics module: persist enriched sleep samples so a
    // future pipeline can aggregate bedtime consistency, screen use and energy.
    _sleepSamples.add(entry);
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
