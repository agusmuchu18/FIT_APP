import 'dart:convert';
import 'dart:io';

import 'package:fit_app/core/data/account_storage_scope.dart';
import 'package:fit_app/features/workout/data/training_library_repository.dart';
import 'package:fit_app/features/workout/domain/training_program.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory temporary;
  late String previousScope;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('fit-training-library-');
    Hive.init(temporary.path);
    previousScope = AccountStorageScope.current;
    AccountStorageScope.current = AccountStorageScope.forUser(
      'training-library-test',
    );
  });
  tearDown(() async {
    await Hive.close();
    AccountStorageScope.current = previousScope;
    if (!temporary.absolute.path.startsWith(
          Directory.systemTemp.absolute.path,
        ) ||
        !temporary.path.contains('fit-training-library-')) {
      throw StateError('Ruta temporal de prueba inesperada; no se elimina');
    }
    await temporary.delete(recursive: true);
  });
  TrainingProgram program() => TrainingProgram(
    id: 'program',
    name: 'Mi programa',
    weeks: 2,
    startDate: DateTime(2026, 10, 19),
    active: true,
    days: const [
      ProgramDay(id: 'monday', week: 0, weekday: 1, routineId: 'routine-a'),
      ProgramDay(id: 'rest', week: 0, weekday: 2, rest: true),
    ],
  );
  test('permanent notes persist across repository reopen and support explicit deletion', () async {
    final repository = TrainingLibraryRepository();
    await repository.saveExerciseNote('bench_press', 'Nota privada permanente');
    await Hive.close();
    expect(
      await TrainingLibraryRepository().exerciseNote('bench_press'),
      'Nota privada permanente',
    );
    await TrainingLibraryRepository().saveExerciseNote('bench_press', '');
    expect(await TrainingLibraryRepository().exerciseNote('bench_press'), '');
  });
  test('account and guest notes remain separate even when an old repository finishes later', () async {
    final first = TrainingLibraryRepository();
    await first.saveExerciseNote('bench_press', 'Cuenta A');
    AccountStorageScope.current = AccountStorageScope.forUser('another-user');
    final second = TrainingLibraryRepository();
    expect(await second.exerciseNote('bench_press'), '');
    await second.saveExerciseNote('bench_press', 'Cuenta B');
    await first.saveExerciseNote('bench_press', 'Cuenta A editada');
    expect(await second.exerciseNote('bench_press'), 'Cuenta B');
    AccountStorageScope.current = AccountStorageScope.forUser(null);
    expect(await TrainingLibraryRepository().exerciseNote('bench_press'), '');
  });
  test(
    'corrupt and unknown-version notes are preserved and cannot be overwritten',
    () async {
      final repository = TrainingLibraryRepository();
      final box = await Hive.openBox<String>(repository.boxName);
      await box.put('note:bench_press', '{corrupt');
      await expectLater(
        repository.exerciseNote('bench_press'),
        throwsFormatException,
      );
      await expectLater(
        repository.saveExerciseNote('bench_press', 'replacement'),
        throwsFormatException,
      );
      expect(box.get('note:bench_press'), '{corrupt');
      await box.put(
        'note:bench_press',
        jsonEncode({'schemaVersion': 99, 'text': 'Future data'}),
      );
      await expectLater(
        repository.saveExerciseNote('bench_press', ''),
        throwsFormatException,
      );
      expect(jsonDecode(box.get('note:bench_press')!)['text'], 'Future data');
    },
  );
  test(
    'serialized concurrent note updates keep the newest requested value',
    () async {
      final repository = TrainingLibraryRepository();
      await Future.wait([
        for (var i = 0; i < 20; i++)
          repository.saveExerciseNote('bench_press', 'Version $i'),
      ]);
      expect(await repository.exerciseNote('bench_press'), 'Version 19');
    },
  );
  test('programs round-trip, duplicate weeks with fresh IDs and never mutate referenced routines', () async {
    final repository = TrainingLibraryRepository(), original = program();
    final duplicate = original.duplicateWeek(0);
    expect(original.weeks, 2);
    expect(original.days, hasLength(2));
    expect(duplicate.weeks, 3);
    expect(duplicate.days.map((d) => d.id).toSet(), hasLength(4));
    expect(duplicate.days.last.rest, isTrue);
    await repository.saveProgram(duplicate);
    await Hive.close();
    final restored = (await TrainingLibraryRepository().programs()).single;
    expect(restored.days.map((d) => d.routineId).whereType<String>().toSet(), {
      'routine-a',
    });
    expect(
      restored.executionFor(restored.days.first)!.date,
      DateTime(2026, 10, 19),
    );
    expect(restored.executionFor(restored.days[1]), isNull);
  });
  test('invalid programs and conflicting rest days are rejected; corrupt other records survive edits', () async {
    final repository = TrainingLibraryRepository();
    final invalid = program().copyWith(
      days: [
        ...program().days,
        const ProgramDay(
          id: 'conflict',
          week: 0,
          weekday: 2,
          routineId: 'routine-b',
        ),
      ],
    );
    await expectLater(repository.saveProgram(invalid), throwsArgumentError);
    final box = await Hive.openBox<String>(repository.boxName);
    await box.put('program:corrupt', '{invalid');
    await repository.saveProgram(program());
    expect(await repository.programs(), hasLength(1));
    expect(repository.unreadablePrograms, 1);
    await repository.deleteProgram('program');
    expect(box.get('program:corrupt'), '{invalid');
  });
}
