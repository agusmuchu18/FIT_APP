import '../domain/training_export.dart';
import 'training_export_screen.dart';
import 'widgets/training_record_tile.dart';
import 'widgets/workout_units_host.dart';

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
  late Future<
    (WorkoutReport?, WorkoutComparison?, List<ExercisePersonalRecord>)
  >
  _data;
  @override
  void initState() {
    super.initState();
    _repository.historyRevision.addListener(_refresh);
    _load();
  }

  void _refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    _repository.historyRevision.removeListener(_refresh);
    super.dispose();
  }

  void _load() {
    _data = _repository.performanceIndex().then((index) {
      final matches = index.reports.where(
        (r) => r.session.id == widget.sessionId,
      );
      if (matches.isEmpty) return (null, null, <ExercisePersonalRecord>[]);
      final report = matches.first;
      return (
        report,
        WorkoutAnalytics.compare(report, index.reports),
        index.sessionRecords(widget.sessionId),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body:
          FutureBuilder<
            (WorkoutReport?, WorkoutComparison?, List<ExercisePersonalRecord>)
          >(
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
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TrainingExportScreen(
                          data: TrainingExportData.session(
                            report,
                            snapshot.data!.$3,
                            units: WorkoutUnits.of(context),
                          ),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_outlined),
                    label: const Text('Crear tarjeta de la sesión'),
                  ),
                  if (snapshot.data!.$3.isNotEmpty)
                    ExpansionTile(
                      title: Text(
                        '${snapshot.data!.$3.length} marcas logradas en esta sesión',
                      ),
                      children: [
                        for (final mark in snapshot.data!.$3)
                          TrainingRecordTile(
                            record: mark,
                            repository: _repository,
                          ),
                      ],
                    ),
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
                            '${WorkoutUnits.of(context).valueWithUnit('kg', highlight.$2.externalLoadKg!)} externos × ${highlight.$2.reps} repeticiones',
                          ),
                          const Text(
                            'Serie con mayor volumen externo registrado.',
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Ejercicios',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst),
                    child: const Text('Volver al inicio'),
                  ),
                ],
              );
            },
          ),
    ),
  );
}
