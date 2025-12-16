import 'dart:math' as math;

import '../../../core/domain/entities.dart';

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

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

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
  final created = entry.meta.createdAt;
  return dateOnly(created);
}
