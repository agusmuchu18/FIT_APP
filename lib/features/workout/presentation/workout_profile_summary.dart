import '../domain/workout_analytics.dart';

/// A presentation snapshot from the same canonical index as training and PRs.
/// No profile fixtures, biometric inference or additional metric engine.
class WorkoutProfileSummary {
  WorkoutProfileSummary.fromIndex(
    TrainingPerformanceIndex index, {
    DateTime? now,
  }) {
    final today = (now ?? DateTime.now()).toLocal();
    final end = DateTime(today.year, today.month, today.day + 1);
    allSessions = index.reports
        .where((r) => r.session.date.toLocal().isBefore(end))
        .length;
    recent = TrainingStatistics(
      index: index,
      range: TrainingDateRange.forPeriod(TrainingPeriod.month, today),
      now: today,
    );
    final records =
        index.records.where((r) => r.date.toLocal().isBefore(end)).toList()
          ..sort((a, b) {
            final date = b.date.compareTo(a.date);
            if (date != 0) return date;
            final exercise = a.exerciseId.compareTo(b.exerciseId);
            if (exercise != 0) return exercise;
            final kind = a.kind.index.compareTo(b.kind.index);
            return kind != 0 ? kind : a.loadKey.compareTo(b.loadKey);
          });
    latestRecord = records.firstOrNull;
  }
  late final TrainingStatistics recent;
  late final int allSessions;
  late final ExercisePersonalRecord? latestRecord;
}
