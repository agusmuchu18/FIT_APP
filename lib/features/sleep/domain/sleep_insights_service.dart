import 'dart:math' as math;

import '../../../core/domain/entities.dart';
import 'sleep_time_utils.dart';

double averageHours(List<SleepEntry> entries) {
  if (entries.isEmpty) return 0;
  return entries.map((e) => e.hours).reduce((a, b) => a + b) / entries.length;
}

double consistencyBedStd(List<SleepEntry> entries) {
  final mins = entries
      .map((e) => parseHHmmToMinutes(e.bedtime))
      .whereType<int>()
      .toList();
  return circularStdDevMinutes(mins);
}

double consistencyWakeStd(List<SleepEntry> entries) {
  final mins = entries
      .map((e) => parseHHmmToMinutes(e.wakeTime))
      .whereType<int>()
      .toList();
  return circularStdDevMinutes(mins);
}

double socialJetLagHours(List<SleepEntry> entries) {
  if (entries.length < 2) return 0;
  final weekday = entries
      .where((e) => sleepEntryDate(e).weekday < DateTime.saturday)
      .toList();
  final weekend = entries
      .where((e) => sleepEntryDate(e).weekday >= DateTime.saturday)
      .toList();
  if (weekday.isEmpty || weekend.isEmpty) return 0;
  final weekdayMid = circularMeanMinutes(weekday
          .map((e) => computeMidSleepMinutes(
              bedMin: parseHHmmToMinutes(e.bedtime),
              wakeMin: parseHHmmToMinutes(e.wakeTime)))
          .whereType<int>()
          .toList()) ??
      0;
  final weekendMid = circularMeanMinutes(weekend
          .map((e) => computeMidSleepMinutes(
              bedMin: parseHHmmToMinutes(e.bedtime),
              wakeMin: parseHHmmToMinutes(e.wakeTime)))
          .whereType<int>()
          .toList()) ??
      0;
  final diff = (weekendMid - weekdayMid).abs();
  return diff / 60;
}

double sleepDebtHours(List<SleepEntry> entries, double goalHours) {
  if (entries.isEmpty) return 0;
  final total = entries.map((e) => goalHours - e.hours).reduce((a, b) => a + b);
  return total;
}

int bestStreakDays(double targetHours, List<SleepEntry> entries) {
  var best = 0;
  var current = 0;
  final sorted = List<SleepEntry>.from(entries)
    ..sort((a, b) => sleepEntryDate(a).compareTo(sleepEntryDate(b)));
  for (final e in sorted) {
    if (e.hours >= targetHours && !e.deleted) {
      current++;
      best = math.max(best, current);
    } else {
      current = 0;
    }
  }
  return best;
}

Map<String, double> tagsCorrelation(List<SleepEntry> entries) {
  final Map<String, List<SleepEntry>> byTag = {};
  for (final e in entries) {
    for (final tag in e.tags ?? <String>[]) {
      byTag.putIfAbsent(tag, () => []).add(e);
    }
  }
  final result = <String, double>{};
  for (final entry in byTag.entries) {
    final avg = averageHours(entry.value);
    result[entry.key] = avg - averageHours(entries);
  }
  return result;
}

class SleepInsightCard {
  SleepInsightCard({
    required this.title,
    required this.description,
    required this.severity,
    required this.icon,
  });

  final String title;
  final String description;
  final String severity; // info, warning, alert
  final String icon;
}

List<SleepInsightCard> buildInsightCards(List<SleepEntry> entries) {
  final List<SleepInsightCard> cards = [];
  if (entries.isEmpty) return cards;
  final correlations = tagsCorrelation(entries);
  if (correlations.isNotEmpty) {
    final sorted = correlations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.first;
    cards.add(SleepInsightCard(
      title: 'Tag: ${best.key}',
      description:
          'Cuando registras "${best.key}" tu duración cambia ${(best.value).toStringAsFixed(1)} h',
      severity: best.value >= 0 ? 'info' : 'warning',
      icon: '🏷️',
    ));
  }

  final sjl = socialJetLagHours(entries);
  if (sjl > 0) {
    cards.add(SleepInsightCard(
      title: 'Social jet lag',
      description: 'Diferencia fin de semana ${sjl.toStringAsFixed(1)} h',
      severity: sjl > 1.5 ? 'alert' : 'info',
      icon: '⏰',
    ));
  }

  final bedStd = consistencyBedStd(entries);
  if (bedStd > 0) {
    cards.add(SleepInsightCard(
      title: 'Consistencia de acostarse',
      description: 'Variación ${bedStd.toStringAsFixed(0)} min',
      severity: bedStd > 60 ? 'alert' : 'info',
      icon: '🌙',
    ));
  }

  return cards.take(3).toList();
}
