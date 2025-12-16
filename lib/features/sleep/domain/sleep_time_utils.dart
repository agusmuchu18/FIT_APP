import 'dart:math' as math;

import '../../../core/domain/entities.dart';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int? parseHHmmToMinutes(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return hour * 60 + minute;
}

String formatMinutesToHHmm(int minutes) {
  final normalized = minutes % 1440;
  final h = (normalized ~/ 60).toString().padLeft(2, '0');
  final m = (normalized % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

int? computeDurationMinutes({required int bedMin, required int wakeMin}) {
  var wake = wakeMin;
  var bed = bedMin;
  if (wake < bed) {
    wake += 1440;
  }
  final duration = wake - bed;
  if (duration < 120 || duration > 16 * 60) return null;
  return duration;
}

int? computeMidSleepMinutes({int? bedMin, int? wakeMin}) {
  if (bedMin == null || wakeMin == null) return null;
  final duration = computeDurationMinutes(bedMin: bedMin, wakeMin: wakeMin);
  if (duration == null) return null;
  return (bedMin + duration ~/ 2) % 1440;
}

double? circularMeanMinutes(List<int> minutesList) {
  if (minutesList.isEmpty) return null;
  final angles = minutesList.map((m) => 2 * math.pi * (m % 1440) / 1440);
  final sumSin = angles.fold<double>(0, (sum, a) => sum + math.sin(a));
  final sumCos = angles.fold<double>(0, (sum, a) => sum + math.cos(a));
  if (sumSin == 0 && sumCos == 0) return null;
  final meanAngle = math.atan2(sumSin, sumCos);
  final normalized = (meanAngle * 1440 / (2 * math.pi)).round() % 1440;
  return normalized.toDouble();
}

double circularStdDevMinutes(List<int> minutesList) {
  if (minutesList.length < 2) return 0;
  final n = minutesList.length;
  final angles = minutesList
      .map((m) => 2 * math.pi * (m % 1440) / 1440)
      .toList(growable: false);
  final sumSin = angles.fold<double>(0, (sum, a) => sum + math.sin(a));
  final sumCos = angles.fold<double>(0, (sum, a) => sum + math.cos(a));
  final r = math.sqrt(sumSin * sumSin + sumCos * sumCos) / n;
  if (r <= 0) return 0;
  final circularStd = math.sqrt(-2 * math.log(r));
  return circularStd * (1440 / (2 * math.pi));
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime sleepEntryDate(SleepEntry entry) {
  if (entry.sleepDate != null && entry.sleepDate!.isNotEmpty) {
    final parsed = DateTime.tryParse(entry.sleepDate!);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  final fromId = DateTime.tryParse(entry.id);
  if (fromId != null) {
    return dateOnly(fromId);
  }
  final updated = entry.meta.updatedAt;
  return dateOnly(updated);
}

double? computeDurationHours(SleepEntry entry) {
  final bed = parseHHmmToMinutes(entry.bedtime);
  final wake = parseHHmmToMinutes(entry.wakeTime);
  final minutes =
      bed != null && wake != null ? computeDurationMinutes(bedMin: bed, wakeMin: wake) : null;
  return minutes != null ? minutes / 60 : null;
}

int computeSleepScore(SleepEntry entry, double goalHours) {
  final durationHours = computeDurationHours(entry) ?? entry.hours;
  final durationScore = () {
    if (goalHours <= 0) return 0.0;
    final diff = (durationHours - goalHours).abs();
    if (diff >= 3) return 10.0;
    if (diff >= 1.5) return 30.0;
    if (diff >= 0.75) return 45.0;
    return 60.0;
  }();

  final quality = entry.qualityScore ?? _qualityFromText(entry.quality);
  final qualityScore = (quality / 5.0) * 30.0;

  final bedtimeMinutes = parseHHmmToMinutes(entry.bedtime);
  final wakeMinutes = parseHHmmToMinutes(entry.wakeTime);
  final mid = computeMidSleepMinutes(bedMin: bedtimeMinutes, wakeMin: wakeMinutes);
  final consistencyPenalty = mid == null ? 0.0 : 10.0;

  final score = (durationScore + qualityScore + consistencyPenalty).clamp(0.0, 100.0);
  return score.round();
}

int _qualityFromText(String quality) {
  final normalized = quality.toLowerCase();
  if (normalized.contains('excel')) return 5;
  if (normalized.contains('muy') || normalized.contains('buena')) return 4;
  if (normalized.contains('ok') || normalized.contains('normal')) return 3;
  if (normalized.contains('lig')) return 2;
  if (normalized.contains('mala')) return 1;
  return 3;
}
