import 'dart:convert';

import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/training_home/training_home_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('damaged folder and metadata entries do not block valid data', () async {
    SharedPreferences.setMockInitialValues({
      'pro_workout_folders': jsonEncode([
        {'id': 'folder-1', 'name': 'Fuerza', 'sortOrder': 0},
        'damaged',
      ]),
      'pro_workout_template_metadata': jsonEncode({
        'routine-1': {'pinned': true, 'usageCount': 2},
        'damaged': 'invalid',
      }),
    });

    final controller = TrainingHomeController();
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(controller.folders, hasLength(1));
    expect(controller.folders.single.name, 'Fuerza');
    expect(controller.metadataFor('routine-1').pinned, isTrue);
    expect(controller.metadataFor('damaged').pinned, isFalse);
  });

  test('damaged legacy history does not hide current sessions', () async {
    SharedPreferences.setMockInitialValues({
      'pro_workout_sessions': '{invalid',
      WorkoutRepository.sessionsKey: [
        jsonEncode({
          'id': 'session-current',
          'date': '2026-09-28T10:00:00',
          'exercises': <Object>[],
        }),
      ],
    });

    final controller = TrainingHomeController();
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(controller.sessions, hasLength(1));
    expect(controller.sessions.single.id, 'session-current');
  });

  test(
    'duplicating a routine preserves catalog IDs and renews set IDs',
    () async {
      final original = WorkoutTemplate(
        id: 'routine-1',
        name: 'Fuerza A',
        type: WorkoutType.strength,
        origin: TemplateOrigin.user,
        exercises: [
          WorkoutExercise(
            id: 'bench_press',
            name: 'Press banca',
            sets: [SetEntry(id: 'set-1', reps: 8, externalLoadKg: 50)],
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'pro_workout_templates': jsonEncode([original.toJson()]),
      });

      final controller = TrainingHomeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.duplicateRoutine(original);

      final duplicated = controller.routines.singleWhere(
        (routine) => routine.id != original.id,
      );
      expect(duplicated.exercises.single.id, 'bench_press');
      expect(duplicated.exercises.single.sets.single.id, isNot('set-1'));
    },
  );
}
