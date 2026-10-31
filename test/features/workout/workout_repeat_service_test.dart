import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/application/workout_repeat_service.dart';
import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/pro/models/workout_models.dart';
import 'package:fit_app/features/workout/pro/providers/workout_pro_provider.dart';

void main() {
  setUp(() {
    AccountStorageScope.current = '';
    SharedPreferences.setMockInitialValues({});
  });
  WorkoutSession strength() => WorkoutSession(
    id: 'original',
    type: WorkoutType.strength,
    date: DateTime(2026, 10, 10),
    templateName: 'Mi rutina',
    exercises: [
      WorkoutExercise(
        id: 'bench_press',
        name: 'Press banca',
        restSeconds: 90,
        restEnabled: false,
        sets: [
          SetEntry(id: 'old-set', reps: 8, externalLoadKg: 50, done: true),
          SetEntry(
            id: 'ambiguous',
            reps: 6,
            externalLoadKg: 80,
            loadIsAmbiguous: true,
            done: false,
          ),
        ],
      ),
    ],
  );
  test('repeat creates new IDs, preserves reference/rest and never modifies saved original', () async {
    final repository = WorkoutRepository();
    final original = strength();
    await repository.persistLegacySession(original);
    final before = (await SharedPreferences.getInstance()).getString(
      WorkoutRepository.legacySessionsKey,
    );
    final id = await WorkoutRepeatService().repeat(original);
    expect(id, isNot(original.id));
    final draft = (await repository.loadDraftExercises())!.single;
    expect(draft.id, isNot(original.exercises.single.id));
    expect(draft.sets.every((s) => !s.done), isTrue);
    expect(draft.sets.first.id, isNot('old-set'));
    expect(draft.sets.first.kg, 50);
    expect(draft.sets.last.kg, 80);
    expect(draft.sets.last.loadIsAmbiguous, true);
    expect(draft.sets.last.loadType, isNull);
    expect(draft.restEnabled, isFalse);
    expect(draft.restSeconds, 90);
    expect(
      (await repository.loadDraftIdentity())!.sourceSessionId,
      original.id,
    );
    expect(
      (await SharedPreferences.getInstance()).getString(
        WorkoutRepository.legacySessionsKey,
      ),
      before,
    );
  });
  test('existing draft requires explicit replacement; pending close cannot be replaced', () async {
    final service = WorkoutRepeatService();
    await service.repeat(strength());
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(WorkoutRepository.draftKey);
    await expectLater(service.repeat(strength()), throwsStateError);
    expect(prefs.getString(WorkoutRepository.draftKey), raw);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    json['completionPending'] = true;
    await prefs.setString(WorkoutRepository.draftKey, jsonEncode(json));
    await expectLater(
      service.repeat(strength(), replaceDraft: true),
      throwsStateError,
    );
    expect(
      jsonDecode(
        prefs.getString(WorkoutRepository.draftKey)!,
      )['completionPending'],
      true,
    );
  });
  test('cardio repeat reopens Pro with new identity, no previous duration and reference', () async {
    final original = WorkoutSession(
      id: 'run',
      type: WorkoutType.cardio,
      date: DateTime(2026, 10, 10),
      activityName: 'Correr',
      durationMinutes: 30,
      distanceKm: 5,
    );
    final id = await WorkoutRepeatService().repeat(original);
    final provider = WorkoutProProvider();
    await provider.initialize();
    expect(provider.selectedType, WorkoutType.cardio);
    expect(provider.activityName, 'Correr');
    expect(provider.durationMinutes, isNull);
    provider.setDuration(20);
    expect(await provider.saveSession(), true);
    expect(provider.lastSavedSessionId, id);
    final saved = (await WorkoutRepository().listAllSessions()).single;
    expect(saved.sourceSessionId, 'run');
    expect(saved.id, isNot('run'));
    provider.dispose();
  });
  test(
    'repeat retains captured account ownership during asynchronous work',
    () async {
      AccountStorageScope.current = AccountStorageScope.forUser('alice');
      final service = WorkoutRepeatService();
      AccountStorageScope.current = AccountStorageScope.forUser('bob');
      await service.repeat(strength());
      expect(await WorkoutRepository().loadDraftExercises(), isNull);
      AccountStorageScope.current = AccountStorageScope.forUser('alice');
      expect(await WorkoutRepository().loadDraftExercises(), isNotNull);
    },
  );
}
