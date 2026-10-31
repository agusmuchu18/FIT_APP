import 'dart:convert';
import 'dart:io';

import 'package:fit_app/features/workout/pro/data/exercise_library.dart';
import 'package:fit_app/features/workout/domain/routine_labels.dart';

void main() {
  final sourceFile = File('docs/design/EXERCISE_ART_SOURCES_2026_10_12.json');
  final source =
      jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
  final generated = {
    for (final a in source['assets'] as List) a['id'] as String: a,
  };
  const style =
      'Square stylized 3D exercise illustration. Anonymous realistic athlete wearing fully opaque graphite training shirt and long leggings, turquoise seams, matte materials, soft light, plain midnight navy, full movement and equipment visible. No text, logos or watermark. Accurate recognizable movement, no skin emphasis.';
  final assets = [
    for (final e in exerciseLibrary)
      {
        'exerciseId': e.id,
        'catalogueName': e.name,
        'displayName': RoutineLabels.exerciseName(e.name),
        'coverage': generated.containsKey(e.id) ? 'specific' : 'generic',
        'file': generated.containsKey(e.id) ? generated[e.id]['file'] : null,
        'fallbackRule':
            'ExerciseArtRegistry.category (primary muscles, then timed/mixed)',
        'fallbackCoverage':
            'generic category artwork; identified in the exercise sheet',
        'missingAssetBehavior':
            'local themed placeholder; exercise remains usable',
        'generationStatus': generated.containsKey(e.id)
            ? 'generated'
            : 'pending',
        'targetMaxEdge': 640,
        'prompt':
            '$style Show ${e.name}, with ${RoutineLabels.equipmentName(e.equipment)}. Movement pattern: ${e.movementPattern}. Camera must make the movement easy to recognize. Export a single illustration; review technique before approving.',
      },
  ];
  final output = {
    'schemaVersion': 1,
    'catalogueCount': exerciseLibrary.length,
    'specificCount': generated.length,
    'genericCount': exerciseLibrary.length - generated.length,
    'style': style,
    'policy': 'Generic illustrations must be labeled in the exercise sheet. Missing images never block an exercise. Sources in EXERCISE_ART_SOURCES_2026_10_12.json. AI illustrations need biomechanical review before use as instruction.',
    'assets': assets,
  };
  File('docs/design/EXERCISE_ART_MANIFEST.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  stdout.writeln(
    '${exerciseLibrary.length} exercises; ${generated.length} specific illustrations; ${exerciseLibrary.length - generated.length} pending.',
  );
}
