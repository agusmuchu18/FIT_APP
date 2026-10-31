import '../domain/training_export.dart';
import 'training_export_screen.dart';
import 'widgets/training_record_tile.dart';
import 'widgets/workout_units_host.dart';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../common/theme/app_layout.dart';
import '../application/routine_update_from_session.dart';
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
    this.routineUpdate,
  });
  final String sessionId;
  final WorkoutRepository? repository;

  /// Offered once after finishing a routine whose values changed today.
  final RoutineUpdateProposal? routineUpdate;
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
  _RoutineUpdateState _routineUpdate = _RoutineUpdateState.offered;
  bool _showAllRecords = false;
  static const _recordsPreview = 3;

  Future<void> _applyRoutineUpdate() async {
    final proposal = widget.routineUpdate;
    if (proposal == null || _routineUpdate == _RoutineUpdateState.saving) {
      return;
    }
    setState(() => _routineUpdate = _RoutineUpdateState.saving);
    try {
      await proposal.apply();
      if (!mounted) return;
      setState(() => _routineUpdate = _RoutineUpdateState.saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _routineUpdate = _RoutineUpdateState.offered);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la rutina. Reintentá.'),
        ),
      );
    }
  }

  Widget _routineUpdatePanel(BuildContext context) {
    final proposal = widget.routineUpdate!;
    final theme = Theme.of(context);
    if (_routineUpdate == _RoutineUpdateState.saved) {
      return ReportPanel(
        child: Row(
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '«${proposal.routine.name}» quedó actualizada para la próxima vez.',
              ),
            ),
          ],
        ),
      );
    }
    return ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Actualizar «${proposal.routine.name}»?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Guardamos las series, pesos y repeticiones que hiciste hoy como objetivos de la rutina. Los ejercicios que no hiciste no cambian.',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: _routineUpdate == _RoutineUpdateState.saving
                    ? null
                    : _applyRoutineUpdate,
                child: const Text('Actualizar rutina'),
              ),
              TextButton(
                onPressed: _routineUpdate == _RoutineUpdateState.saving
                    ? null
                    : () => setState(
                        () => _routineUpdate = _RoutineUpdateState.dismissed,
                      ),
                child: const Text('Mantener como está'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Marks that beat an earlier one. A first session sets every mark, which
  /// would make the celebration meaningless.
  static List<ExercisePersonalRecord> _improvedRecords(
    TrainingPerformanceIndex index,
    WorkoutReport report,
  ) {
    final sessionId = report.session.id;
    String key(ExercisePersonalRecord r) =>
        '${r.exerciseId}|${r.loadKey}|${r.kind.name}|${r.reps ?? ''}';
    final earlier = {
      for (final r in index.recordHistory)
        if (r.sessionId != sessionId && !r.date.isAfter(report.session.date))
          key(r),
    };
    return index
        .sessionRecords(sessionId)
        .where((r) => earlier.contains(key(r)))
        .toList(growable: false);
  }

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
        _improvedRecords(index, report),
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
                  if (snapshot.data!.$3.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    ReportPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  snapshot.data!.$3.length == 1
                                      ? '¡1 récord nuevo!'
                                      : '¡${snapshot.data!.$3.length} récords nuevos!',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          for (final mark in snapshot.data!.$3.take(
                            _showAllRecords
                                ? snapshot.data!.$3.length
                                : _recordsPreview,
                          ))
                            TrainingRecordTile(
                              record: mark,
                              repository: _repository,
                            ),
                          if (snapshot.data!.$3.length > _recordsPreview)
                            TextButton(
                              onPressed: () => setState(
                                () => _showAllRecords = !_showAllRecords,
                              ),
                              child: Text(
                                _showAllRecords
                                    ? 'Ver menos'
                                    : 'Ver los ${snapshot.data!.$3.length} récords',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.routineUpdate != null &&
                      _routineUpdate != _RoutineUpdateState.dismissed) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _routineUpdatePanel(context),
                  ],
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

enum _RoutineUpdateState { offered, saving, saved, dismissed }
