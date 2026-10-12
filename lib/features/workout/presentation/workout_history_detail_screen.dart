import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../common/theme/app_layout.dart';
import '../application/workout_repeat_service.dart';
import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
import 'widgets/workout_report_widgets.dart';

class WorkoutHistoryDetailScreen extends StatefulWidget {
  const WorkoutHistoryDetailScreen({
    super.key,
    this.session,
    this.sessionId,
    this.repository,
  }) : assert(session != null || sessionId != null);
  final WorkoutSession? session;
  final String? sessionId;
  final WorkoutRepository? repository;
  @override
  State<WorkoutHistoryDetailScreen> createState() =>
      _WorkoutHistoryDetailScreenState();
}

class _WorkoutHistoryDetailScreenState
    extends State<WorkoutHistoryDetailScreen> {
  late final WorkoutRepository _repository =
      widget.repository ?? WorkoutRepository();
  late Future<(WorkoutReport?, WorkoutComparison?)> _data;
  bool _repeating = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = _repository.listAllSessions().then((history) {
      final found = history.where(
        (s) => s.id == (widget.sessionId ?? widget.session?.id),
      );
      final session = found.isEmpty ? widget.session : found.first;
      if (session == null) return (null, null);
      final report = WorkoutReport(session);
      return (
        report,
        WorkoutAnalytics.compare(
          report,
          history.map(WorkoutReport.new).toList(),
        ),
      );
    });
  }

  Future<void> _repeat(WorkoutSession original) async {
    if (_repeating) return;
    setState(() => _repeating = true);
    try {
      final service = WorkoutRepeatService();
      final hasDraft = await service.hasDraft();
      if (!mounted) return;
      var replace = false;
      if (hasDraft) {
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ya tenés una sesión en curso'),
            content: const Text(
              'Podés continuarla o descartarla para iniciar una nueva desde este entrenamiento. El historial guardado se conserva.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'continue'),
                child: const Text('Continuar sesión actual'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'replace'),
                child: const Text('Descartar e iniciar nueva'),
              ),
            ],
          ),
        );
        if (!mounted || choice == null) return;
        if (choice == 'continue') {
          await Navigator.of(context).pushNamed('/workout/session');
          return;
        }
        replace = true;
      }
      await service.repeat(original, replaceDraft: replace);
      if (mounted) await Navigator.of(context).pushNamed('/workout/session');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo iniciar la sesión. $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _repeating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workout,
    child: Scaffold(
      appBar: AppBar(title: const Text('Detalle')),
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
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              WorkoutReportHero(report: report),
              const SizedBox(height: AppSpacing.xl),
              WorkoutReportStatistics(report: report),
              const SizedBox(height: AppSpacing.xl),
              WorkoutComparisonPanel(comparison: snapshot.data?.$2),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Ejercicios y series',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final e in report.exercises)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: WorkoutExerciseReportCard(report: e, expanded: true),
                ),
              if (report.session.distanceKm != null)
                Text(
                  'Distancia: ${workoutNumber(report.session.distanceKm!)} km',
                ),
              if (report.session.pace?.trim().isNotEmpty == true)
                Text('Ritmo registrado: ${report.session.pace}'),
              if (report.session.notes?.trim().isNotEmpty == true)
                ReportPanel(child: Text('Notas: ${report.session.notes}')),
              if (report.session.finalNotes?.trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: ReportPanel(
                    child: Text(
                      'Notas de cierre: ${report.session.finalNotes}',
                    ),
                  ),
                ),
              if (report.session.sourceSessionId != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => WorkoutHistoryDetailScreen(
                          sessionId: report.session.sourceSessionId!,
                          repository: _repository,
                        ),
                      ),
                    ),
                    child: const Text('Ver entrenamiento de referencia'),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _repeating ? null : () => _repeat(report.session),
                child: Text(
                  _repeating ? 'Preparando sesión…' : 'Repetir entrenamiento',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Se crea una sesión nueva con objetivos sin completar. Las cargas antiguas sin clasificación no se reutilizan automáticamente.',
              ),
            ],
          );
        },
      ),
    ),
  );
}
