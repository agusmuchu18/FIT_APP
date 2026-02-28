import 'package:intl/intl.dart';

class NutritionFormatters {
  static final NumberFormat _thousandFormat = NumberFormat.decimalPattern('es_AR');

  static String formatNumberCompact(int value) {
    final abs = value.abs();
    if (abs >= 1000000) {
      final millions = value / 1000000;
      return '${millions.toStringAsFixed(1).replaceAll('.', ',')}M';
    }
    if (abs >= 10000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(1).replaceAll('.', ',')}k';
    }
    return _thousandFormat.format(value);
  }

  static String formatKcal(int value) => '${formatNumberCompact(value)} kcal';
}
