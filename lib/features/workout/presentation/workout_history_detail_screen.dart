import 'widgets/workout_units_host.dart';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../main.dart' show RepositoryScope;
import '../../../core/data/repositories.dart';
import '../../common/theme/app_layout.dart';
import '../application/workout_repeat_service.dart';
import '../data/workout_repository.dart';
import '../domain/workout_analytics.dart';
import '../pro/models/workout_models.dart';
import 'widgets/workout_report_widgets.dart';
import 'workout_history_editor_screen.dart';
import '../application/workout_history_mutation_service.dart';

class WorkoutHistoryDetailScreen extends StatefulWidget {
  const WorkoutHistoryDetailScreen({
    super.key,
    this.session,
    this.sessionId,
    this.repository,
    this.fitnessRepository,
  }) : assert(session != null || sessionId != null);
  final WorkoutSession? session;
  final String? sessionId;
  final WorkoutRepository? repository;
  final FitnessRepository? fitnessRepository;
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
  bool _changing = false, _deletionPending = false;
  FitnessRepository? get _fitness =>
      widget.fitnessRepository ??
      context.getInheritedWidgetOfExactType<RepositoryScope>()?.repository;

  Future<void> _change(String action) async {
    final fitness = _fitness;
    if (_changing || fitness == null || !_repository.isCurrentScope) return;
    setState(() => _changing = true);
    try {
      final service = WorkoutHistoryMutationService(_repository, fitness);
      if (_deletionPending) {
        await service.recover();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      final snapshot = await _repository.editableSessionSnapshot(
            widget.sessionId ?? widget.session!.id,
          ),
          session = snapshot.$1;
      if (!mounted || session == null) return;
      if (action == 'edit') {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => WorkoutHistoryEditorScreen(
              session: session,
              repository: _repository,
              fitness: fitness,
              initialRevision: snapshot.$2,
            ),
          ),
        );
        if (mounted) setState(_load);
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Eliminar sesión'),
            content: const Text(
              'Se quitará del historial, calendario, informes y récords. Las rutinas y los programas se conservan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Eliminar sesión'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await service.delete(session.id, expectedRevision: snapshot.$2);
        if (mounted) Navigator.pop(context, true);
      }
    } on HistoryProjectionPending {
      if (mounted) setState(() => _deletionPending = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo completar el cambio. Volvé a abrir la sesión y reintentá.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _data = _repository.listAllSessions().then((history) async {
      final found = history.where(
        (s) => s.id == (widget.sessionId ?? widget.session?.id),
      );
      final deleted =
          found.isEmpty &&
          (await _repository.historyChanges())[widget.sessionId ??
                      widget.session?.id]
                  ?.deleted ==
              true;
      final session = found.isEmpty
          ? (deleted ? null : widget.session)
          : found.first;
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
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          if (_fitness != null)
            PopupMenuButton<String>(
              tooltip: 'Opciones del historial',
              enabled: !_changing,
              onSelected: _change,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Corregir sesión')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar sesión')),
              ],
            ),
        ],
      ),
      body: FutureBuilder<(WorkoutReport?, WorkoutComparison?)>(
        future: _data,
        builder: (context, snapshot) {
          if (_deletionPending) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'La sesión quedó eliminada del historial. Falta actualizar el resumen general.',
                    ),
                    FilledButton(
                      onPressed: _changing ? null : () => _change('delete'),
                      child: const Text('Reintentar cierre'),
                    ),
                  ],
                ),
              ),
            );
          }
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
                  'Distancia: ${WorkoutUnits.of(context).valueWithUnit('km', report.session.distanceKm!)}',
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
