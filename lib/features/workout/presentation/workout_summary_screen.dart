import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../common/theme/app_layout.dart';
import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import '../training_home/workout_history_screen.dart';
import 'widgets/workout_report_widgets.dart';

/// Reads saved data by ID; no transient, uncommitted payload is presented.
class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({
    super.key,
    required this.sessionId,
    this.repository,
  });
  final String sessionId;
  final WorkoutRepository? repository;
  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  late final WorkoutRepository _repository =
      widget.repository ?? WorkoutRepository();
  late Future<(WorkoutReport?, WorkoutComparison?)> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = _repository.listAllSessions().then((sessions) {
      final matches = sessions.where((s) => s.id == widget.sessionId);
      if (matches.isEmpty) return (null, null);
      final report = WorkoutReport(matches.first);
      return (
        report,
        WorkoutAnalytics.compare(
          report,
          sessions.map(WorkoutReport.new).toList(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workout,
    child: Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: FutureBuilder<(WorkoutReport?, WorkoutComparison?)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: () => setState(_load),
                child: const Text(
                  'No se pudo leer el entrenamiento. Reintentar',
                ),
              ),
            );
          }
          final report = snapshot.data?.$1;
          if (report == null) {
            return const Center(
              child: Text(
                'Este entrenamiento no está disponible en esta cuenta.',
              ),
            );
          }
          final highlight = WorkoutAnalytics.highlightedSet(report);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WorkoutReportHero(report: report, saved: true),
              const SizedBox(height: AppSpacing.xl),
              WorkoutReportStatistics(report: report),
              const SizedBox(height: AppSpacing.xl),
              WorkoutMuscleReport(report: report),
              const SizedBox(height: AppSpacing.xl),
              WorkoutComparisonPanel(comparison: snapshot.data?.$2),
              if (highlight != null) ...[
                const SizedBox(height: AppSpacing.xl),
                ReportPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Serie destacada',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(highlight.$1),
                      Text(
                        '${workoutNumber(highlight.$2.externalLoadKg!)} kg externos × ${highlight.$2.reps} repeticiones',
                      ),
                      const Text('Serie con mayor volumen externo registrado.'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('Ejercicios', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              for (final exercise in report.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: WorkoutExerciseReportCard(report: exercise),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: RouteSettings(
                      name: '/workout/detail',
                      arguments: report.session.id,
                    ),
                    builder: (_) => WorkoutHistoryDetailScreen(
                      sessionId: report.session.id,
                      repository: _repository,
                    ),
                  ),
                ),
                child: const Text('Ver entrenamiento completo'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Volver al inicio'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
