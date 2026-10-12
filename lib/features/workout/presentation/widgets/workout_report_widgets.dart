import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/theme/app_layout.dart';
import '../../domain/workout_analytics.dart';
import '../../pro/models/workout_models.dart';

String workoutNumber(num v) => NumberFormat('#,##0.#', 'es').format(v);
String workoutDuration(Duration? d) => d == null
    ? 'Sin registro'
    : d.inSeconds >= 3600
    ? '${d.inHours} h ${d.inMinutes % 60} min'
    : '${d.inMinutes} min ${d.inSeconds % 60} s';
String workoutDate(DateTime d) {
  final date = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

String workoutMonth(DateTime d) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final date = d.toLocal();
  return '${months[date.month - 1]} ${date.year}';
}

String workoutDominantValue(WorkoutReport report) => report.externalVolume > 0
    ? '${workoutNumber(report.externalVolume)} kg'
    : (report.session.distanceKm ?? 0) > 0
    ? '${workoutNumber(report.session.distanceKm!)} km'
    : report.duration != null
    ? workoutDuration(report.duration)
    : report.reps > 0
    ? '${report.reps} reps'
    : '${report.performedSets} series';
String workoutDominantLabel(WorkoutReport report) => report.externalVolume > 0
    ? 'Volumen externo · kg × repeticiones'
    : (report.session.distanceKm ?? 0) > 0
    ? 'Distancia registrada'
    : report.duration != null
    ? report.durationLabel
    : report.reps > 0
    ? 'Repeticiones registradas'
    : report.setsLabel;

class WorkoutArtwork extends StatelessWidget {
  const WorkoutArtwork({
    super.key,
    this.category,
    this.hero = false,
    this.empty = false,
  });
  final WorkoutArtCategory? category;
  final bool hero, empty;
  static String asset({
    WorkoutArtCategory? category,
    bool hero = false,
    bool empty = false,
  }) =>
      'assets/images/workout/${hero
          ? 'summary_hero'
          : empty
          ? 'history_empty'
          : 'history_${category?.name ?? 'mixed'}'}.webp';
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      asset(category: category, hero: hero, empty: empty),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            empty ? Icons.history : Icons.fitness_center,
            color: Theme.of(context).colorScheme.primary,
            size: hero ? 72 : 32,
          ),
        ),
      ),
    ),
  );
}

class ReportPanel extends StatelessWidget {
  const ReportPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppShape.card),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class WorkoutMetricGrid extends StatelessWidget {
  const WorkoutMetricGrid({super.key, required this.metrics});
  final List<(String, String)> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final columns = constraints.maxWidth >= 640
          ? (enlarged ? 2 : 4)
          : (enlarged ? 1 : 2);
      final width =
          (constraints.maxWidth - AppSpacing.md * (columns - 1)) / columns;
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [
          for (final m in metrics)
            SizedBox(
              width: width,
              child: ReportPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.$2, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(m.$1, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class WorkoutReportHero extends StatelessWidget {
  const WorkoutReportHero({
    super.key,
    required this.report,
    this.saved = false,
  });
  final WorkoutReport report;
  final bool saved;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppShape.card),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const WorkoutArtwork(hero: true),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Theme.of(context).colorScheme.surface
                          .withValues(alpha: AppVisual.scrimOpacity),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(1) <= 1.3)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workoutDominantValue(report),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(workoutDominantLabel(report)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      if (MediaQuery.textScalerOf(context).scale(1) > 1.3) ...[
        Text(
          workoutDominantValue(report),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(workoutDominantLabel(report)),
        const SizedBox(height: AppSpacing.lg),
      ],
      if (saved)
        Text(
          'Entrenamiento completado',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      Text(report.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(workoutDate(report.session.date)),
    ],
  );
}

class WorkoutReportStatistics extends StatelessWidget {
  const WorkoutReportStatistics({super.key, required this.report});
  final WorkoutReport report;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      WorkoutMetricGrid(
        metrics: [
          (report.durationLabel, workoutDuration(report.duration)),
          (
            report.setsLabel,
            '${report.performedSets}/${report.programmedSets}',
          ),
          ('Ejercicios registrados', '${report.recordedExercises}'),
          ('Repeticiones', workoutNumber(report.reps)),
        ],
      ),
      if (report.session.durationIsActive == true)
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'El tiempo sin pausas incluye los descansos. No mide tiempo efectivo de ejercicio.',
          ),
        ),
      if (report.ambiguousLoad)
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'Hay cargas antiguas sin clasificación. Se conservan en el detalle y se excluyen del volumen externo.',
          ),
        ),
      if (report.legacyCompletionUnknown)
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'Este registro no identifica qué series se marcaron como completadas.',
          ),
        ),
    ],
  );
}

class WorkoutMuscleReport extends StatelessWidget {
  const WorkoutMuscleReport({super.key, required this.report});
  final WorkoutReport report;
  @override
  Widget build(BuildContext context) {
    final values = WorkoutAnalytics.muscles
        .map((m) => report.muscleDistribution[m] ?? 0)
        .toList();
    final color = Theme.of(context).colorScheme.primary;
    return ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución muscular',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (report.mainMuscles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('Sin ejercicios con grupo muscular conocido.'),
            )
          else ...[
            SizedBox(
              height: 200,
              child: ExcludeSemantics(
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    isMinValueAtCenter: true,
                    tickCount: 4,
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    radarBorderData: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    gridBorderData: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    tickBorderData: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    getTitle: (index, angle) => RadarChartTitle(text: ''),
                    dataSets: [
                      RadarDataSet(
                        fillColor: Colors.transparent,
                        borderColor: Colors.transparent,
                        entryRadius: 0,
                        // Invisible axis calibration fixes the scale at 0–100.
                        // fl_chart otherwise gives zero a nonzero radius.
                        dataEntries: List.generate(
                          6,
                          (index) => RadarEntry(value: index == 0 ? 0 : 100),
                        ),
                      ),
                      RadarDataSet(
                        fillColor: color.withValues(
                          alpha: AppVisual.chartAreaOpacity,
                        ),
                        borderColor: color,
                        entryRadius: 3,
                        dataEntries: values
                            .map((v) => RadarEntry(value: v * 100))
                            .toList(),
                      ),
                    ],
                  ),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : AppVisual.motionNormal,
                ),
              ),
            ),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                for (var i = 0; i < values.length; i++)
                  if (values[i] > 0)
                    Text(
                      '${WorkoutAnalytics.muscles[i]} ${workoutNumber(values[i] * 100)} %',
                    ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Estimación por series válidas y grupos principales del catálogo. Cada serie se reparte entre sus grupos conocidos; no mide activación ni estímulo fisiológico.',
          ),
        ],
      ),
    );
  }
}

class WorkoutComparisonPanel extends StatelessWidget {
  const WorkoutComparisonPanel({super.key, required this.comparison});
  final WorkoutComparison? comparison;
  @override
  Widget build(BuildContext context) {
    final v = comparison;
    String signed(num d) => '${d > 0 ? '+' : ''}${workoutNumber(d)}';
    return ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comparación anterior',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (v == null)
            const Text(
              'Sin una sesión anterior comparable. Se necesita la misma modalidad y estructura de ejercicios y medidas.',
            )
          else ...[
            Text(
              '${v.previous.name} · ${workoutDate(v.previous.session.date)}',
            ),
            const SizedBox(height: AppSpacing.md),
            if (v.current.externalVolume > 0 || v.previous.externalVolume > 0)
              Text(
                'Volumen externo: ${signed(v.volumeDelta)} kg${v.volumePercent == null ? '' : ' (${signed(v.volumePercent!)} %)'}',
              ),
            Text(
              'Series: ${signed(v.setsDelta)} · Repeticiones: ${signed(v.repsDelta)}',
            ),
            if (v.durationDelta != null)
              Text(
                'Duración: ${v.durationDelta!.isNegative ? '−' : '+'}${workoutDuration(v.durationDelta!.abs())}',
              ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'La diferencia describe el registro; por sí sola no indica una mejora de rendimiento.',
            ),
          ],
        ],
      ),
    );
  }
}

String workoutSetLabel(int index, WorkoutExercise e, SetEntry s) {
  final parts = <String>['Serie $index'];
  if (s.reps != null) parts.add('${s.reps} repeticiones');
  if (s.externalLoadKg != null) {
    parts.add(
      '${workoutNumber(s.externalLoadKg!)} kg${s.loadIsAmbiguous ? ' (carga antigua sin clasificar)' : ' externos'}',
    );
  }
  if (s.durationSeconds != null) parts.add('${s.durationSeconds} s');
  if (s.assistanceKg != null) {
    parts.add('${workoutNumber(s.assistanceKg!)} kg de asistencia');
  }
  if (s.bodyweightKg != null) {
    parts.add('Peso corporal registrado: ${workoutNumber(s.bodyweightKg!)} kg');
  }
  if (s.externalLoadKg == null &&
      s.assistanceKg == null &&
      e.targetLoadType == RoutineExerciseLoadType.bodyweight) {
    parts.add('Peso corporal');
  }
  if (s.rir != null) parts.add('RIR ${s.rir}');
  if (s.restSeconds != null) {
    parts.add('${s.restSeconds} s de descanso registrado');
  }
  final valid = WorkoutAnalytics.isRecordedSet(e, s);
  parts.add(
    s.done == false
        ? 'Pendiente'
        : !valid
        ? 'Datos incompletos'
        : s.done == true
        ? 'Completada'
        : 'Registrada (estado no disponible)',
  );
  return parts.join(' · ');
}

class WorkoutExerciseReportCard extends StatelessWidget {
  const WorkoutExerciseReportCard({
    super.key,
    required this.report,
    this.expanded = false,
  });
  final ExerciseReport report;
  final bool expanded;
  @override
  Widget build(BuildContext context) => ReportPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          report.exercise.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${report.performed.length}/${report.exercise.sets.length} series · ${workoutNumber(report.externalVolume)} kg externos',
        ),
        Text(
          WorkoutAnalytics.isTimed(report.exercise)
              ? '${report.performed.fold<int>(0, (total, set) => total + (set.durationSeconds ?? 0))} s registrados'
              : '${report.reps} repeticiones registradas',
        ),
        if (expanded) ...[
          if (report.exercise.restEnabled != null ||
              report.exercise.restSeconds != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                report.exercise.restEnabled == false
                    ? 'Descanso automático desactivado'
                    : 'Descanso configurado: ${report.exercise.restSeconds ?? 0} s',
              ),
            ),
          for (var i = 0; i < report.exercise.sets.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                workoutSetLabel(
                  i + 1,
                  report.exercise,
                  report.exercise.sets[i],
                ),
              ),
            ),
          if (report.exercise.sets.isEmpty)
            const Text('Sin series registradas'),
          if (report.exercise.notes?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text('Notas: ${report.exercise.notes}'),
            ),
        ],
      ],
    ),
  );
}
