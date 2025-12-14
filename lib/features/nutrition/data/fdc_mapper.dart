double _getAmountByNutrientNumber(Map<String, dynamic> food, int nutrientNumber) {
  final list = (food['foodNutrients'] as List?) ?? const [];
  for (final it in list) {
    final m = it as Map<String, dynamic>;
    final nutrient = m['nutrient'] as Map<String, dynamic>?;
    final numberStr = nutrient?['number']?.toString(); // suele ser "203"
    if (numberStr == nutrientNumber.toString()) {
      final amount = m['amount'];
      if (amount is num) return amount.toDouble();
      return double.tryParse(amount?.toString() ?? '') ?? 0.0;
    }
  }
  return 0.0;
}

