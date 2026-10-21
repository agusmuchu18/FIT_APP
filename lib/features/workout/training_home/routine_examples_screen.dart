import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/app_theme.dart';
import '../../common/widgets/fit_glyph.dart';
import '../domain/training_examples.dart';
import '../pro/data/exercise_library.dart';
import 'routine_draft_controller.dart';
import 'routine_review_screen.dart';
import 'routines_repository.dart';
import 'training_home_widgets.dart';

class RoutineExamplesScreen extends StatefulWidget {
  const RoutineExamplesScreen({super.key, this.repository});
  final RoutinesRepository? repository;
  @override
  State<RoutineExamplesScreen> createState() => _RoutineExamplesScreenState();
}

class _RoutineExamplesScreenState extends State<RoutineExamplesScreen> {
  late final _repository = widget.repository ?? RoutinesRepository();
  bool _opening = false;
  Future<void> _use(RoutineExample example) async {
    if (_opening) return;
    setState(() => _opening = true);
    // A dedicated, temporary draft leaves the user's normal creator draft intact.
    final draft =
        RoutineDraftController(
            editingRoutineId: 'example-${const Uuid().v4()}',
            initialSelectedExerciseIds: example.exerciseIds,
          )
          ..name = example.name
          ..notes =
              'Ejemplo editable: ${example.description} Ajustá series, repeticiones, descansos y cargas antes de entrenar.';
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RoutineReviewScreen(
            draftController: draft,
            exercisesById: {for (final d in exerciseLibrary) d.id: d},
            repository: _repository,
          ),
        ),
      );
      if (saved == true && mounted) Navigator.pop(context, true);
    } finally {
      try {
        await draft.clearPersisted();
      } catch (_) {
        /* An abandoned example must never erase the ordinary creator draft. */
      }
      draft.dispose();
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(title: const Text('Ejemplos editables')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Un punto de partida',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Text(
            'Estas estructuras usan ejercicios reales del catálogo. No contienen pesos personales ni resultados. Abrí una, ajustala y guardá tu propia copia.',
          ),
          const SizedBox(height: 24),
          for (final example in TrainingExamples.routines) ...[
            RoutineActionTile(
              title: example.name,
              subtitle: example.equipment.join(' · '),
              glyph: FitGlyphKind.routine,
              imageAsset: example.imageAsset,
              onTap: () {
                if (!_opening) _use(example);
              },
            ),
            const SizedBox(height: 8),
            Text(example.description),
            Text(example.plan.map((e) => e.name).join(' · ')),
            const SizedBox(height: 24),
          ],
        ],
      ),
    ),
  );
}
