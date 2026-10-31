import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../common/theme/app_layout.dart';
import '../domain/routine_catalog.dart';
import '../domain/routine_labels.dart';
import '../pro/data/exercise_library.dart';
import '../presentation/widgets/exercise_thumbnail.dart';
import '../presentation/widgets/workout_units_host.dart';
import 'routine_draft_controller.dart';
import 'exercise_technical_screen.dart';
import 'routine_review_screen.dart';
import 'routines_repository.dart';

/// One cover recipe for catalog cards and their read-only detail.
/// Text sits on the existing opaque surface, never directly over photography.
class CatalogRoutineCover extends StatelessWidget {
  const CatalogRoutineCover({super.key, required this.routine, this.onTap});
  final CatalogRoutine routine;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppShape.card),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 2,
              child: Image.asset(
                routine.imageAsset,
                width: double.infinity,
                fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                cacheWidth: 1024,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: colors.surfaceContainerHighest,
                  child: Icon(
                    Icons.fitness_center,
                    size: 32,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${routine.level.label.toUpperCase()} · ${routine.goal}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(routine.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${routine.exerciseIds.length} ejercicios · ${routine.totalSets} series',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    routine.equipment.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ver rutina',
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogRoutineDetailScreen extends StatefulWidget {
  const CatalogRoutineDetailScreen({
    super.key,
    required this.routine,
    required this.repository,
  });
  final CatalogRoutine routine;
  final RoutinesRepository repository;
  @override
  State<CatalogRoutineDetailScreen> createState() =>
      _CatalogRoutineDetailScreenState();
}

class _CatalogRoutineDetailScreenState
    extends State<CatalogRoutineDetailScreen> {
  bool _opening = false;
  Future<void> _customize() async {
    if (_opening) return;
    setState(() => _opening = true);
    // A separate temporary namespace protects an unfinished ordinary creator.
    final draft = RoutineDraftController(
      editingRoutineId: 'catalog-${const Uuid().v4()}',
    )..hydrate(widget.routine.template());
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RoutineReviewScreen(
            draftController: draft,
            exercisesById: {for (final d in exerciseLibrary) d.id: d},
            repository: widget.repository,
          ),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context, true);
    } finally {
      try {
        await draft.clearPersisted();
      } catch (_) {
        // Never clear the ordinary draft if temporary cleanup is unavailable.
      }
      draft.dispose();
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Builder(
      builder: (context) {
        final routine = widget.routine;
        return Scaffold(
          appBar: AppBar(title: const Text('Conocé la rutina')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              CatalogRoutineCover(routine: routine),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Para quién es',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(routine.level.description),
              const SizedBox(height: AppSpacing.sm),
              Text(routine.description),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'Una sesión editable, no un programa semanal. Revisá las cargas y los descansos según tu experiencia. Las imágenes son portadas decorativas; la técnica está en la ficha de cada ejercicio.',
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Orden de ejercicios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final (index, e) in routine.plan.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExerciseThumbnail(exercise: e),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${RoutineLabels.exerciseName(e.name)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              RoutineLabels.summary(
                                e,
                                units: WorkoutUnits.of(context),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ExerciseTechnicalScreen(
                                    exercise: e,
                                    definition: exerciseLibrary.firstWhere(
                                      (d) => d.id == e.id,
                                    ),
                                  ),
                                ),
                              ),
                              child: const Text('Ver ficha técnica'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                'La carga queda sin asignar. Podés cambiar ejercicios, series, repeticiones y descansos antes de guardar tu copia. En movimientos unilaterales completá ambos lados por serie.',
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton.icon(
              onPressed: _opening ? null : _customize,
              icon: const Icon(Icons.tune_rounded),
              label: Text(_opening ? 'Abriendo…' : 'Personalizar y guardar'),
            ),
          ),
        );
      },
    ),
  );
}
