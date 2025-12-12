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

  static String formatShortDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> recordNutritionMetrics(NutritionMetrics metrics) async {
    _nutritionHistory[_dateKey(metrics.date)] = metrics;
  }

  Future<NutritionMetrics?> getNutritionMetrics(DateTime date) async {
    return _nutritionHistory[_dateKey(date)];
  }

  Future<List<NutritionMetrics>> getNutritionHistory({int days = 7}) async {
    final now = DateTime.now();
    final startDate = _dateOnly(now.subtract(Duration(days: days - 1)));
    final endDate = _dateOnly(now);

    final entries = _nutritionHistory.values.where((metrics) {
      final dateOnly = _dateOnly(metrics.date);
      return !dateOnly.isBefore(startDate) && !dateOnly.isAfter(endDate);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return entries;
  }

  Future<Macros> getMacroDistribution({int days = 7}) async {
    final history = await getNutritionHistory(days: days);
    var carbs = 0;
    var protein = 0;
    var fat = 0;

    for (final metrics in history) {
      carbs += metrics.macros.carbs;
      protein += metrics.macros.protein;
      fat += metrics.macros.fat;
    }

    return Macros(carbs: carbs, protein: protein, fat: fat);
  }

  Future<void> recordSleepInsights(SleepEntry entry) async {
    // Placeholder for analytics module: persist enriched sleep samples so a
    // future pipeline can aggregate bedtime consistency, screen use and energy.
    _sleepSamples.add(entry);
  }

  Future<List<SleepEntry>> getSleepEntries({int days = 7}) async {
    final now = DateTime.now();
    final startDate = _dateOnly(now.subtract(Duration(days: days - 1)));
    final endDate = _dateOnly(now);

    final entries = _sleepSamples.where((entry) {
      final entryDate = _dateOnly(_safeParseDate(entry.id));
      return !entryDate.isBefore(startDate) && !entryDate.isAfter(endDate);
    }).toList()
      ..sort((a, b) =>
          _safeParseDate(a.id).compareTo(_safeParseDate(b.id)));

    return entries;
  }

  String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  DateTime _safeParseDate(String raw) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}
