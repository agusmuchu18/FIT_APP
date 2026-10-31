import 'package:intl/intl.dart';

enum WeightUnit {
  kg('kg', 1),
  lb('lb', 2.2046226218487757);

  const WeightUnit(this.label, this.factor);
  final String label;
  final double factor;
  double fromKg(num kg) => kg * factor;
  double toKg(num value) => value / factor;
}

enum DistanceUnit {
  meters('m', 1),
  kilometers('km', 1000),
  miles('mi', 1609.344);

  const DistanceUnit(this.label, this.metersPerUnit);
  final String label;
  final double metersPerUnit;
  double fromMeters(num value) => value / metersPerUnit;
  double toMeters(num value) => value * metersPerUnit;
}

class TrainingUnits {
  const TrainingUnits({
    this.weight = WeightUnit.kg,
    this.distance = DistanceUnit.meters,
  });
  final WeightUnit weight;
  final DistanceUnit distance;
  static String number(num n) => NumberFormat(
    n != 0 && n.abs() < .01 ? '0.######' : '0.##',
    'es',
  ).format(n);
  double metricValue(String canonicalUnit, num value) =>
      switch (canonicalUnit) {
        'kg' || 'kg·rep' => weight.fromKg(value),
        'm' => distance.fromMeters(value),
        'km' => distance.fromMeters(value * 1000),
        _ => value.toDouble(),
      };
  String metricUnit(String canonicalUnit) => switch (canonicalUnit) {
    'kg' => weight.label,
    'kg·rep' => '${weight.label}·rep',
    'm' || 'km' => distance.label,
    _ => canonicalUnit,
  };
  String valueWithUnit(String canonicalUnit, num value) =>
      '${number(metricValue(canonicalUnit, value))} ${metricUnit(canonicalUnit)}';
}
