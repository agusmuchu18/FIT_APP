import 'package:fit_app/features/workout/data/workout_repository.dart';
import 'package:fit_app/features/workout/domain/session_models.dart';
import 'package:fit_app/features/workout/training_home/workout_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'history detail preserves recorded and unfinished sets in order',
    (tester) async {
      final repository = WorkoutRepository();
      await repository.persistCompletedWorkout(
        const [
          ExerciseInSession(
            id: 'exercise-1',
            exerciseId: 'bench_press',
            name: 'Press banca',
            sets: [
              SetInSession(id: 'set-1', index: 1, kg: 50, reps: 8, done: true),
              SetInSession(id: 'set-2', index: 2, kg: 60, reps: 6),
            ],
          ),
        ],
        sessionId: 'completed-session',
        routineName: 'Fuerza A',
        duration: const Duration(minutes: 24),
      );
      final session = (await repository.listSessions()).single;
      expect(session.exercises.single.sets.first.done, isTrue);
      expect(session.exercises.single.sets.last.done, isFalse);

      await tester.pumpWidget(
        MaterialApp(home: WorkoutHistoryDetailScreen(session: session)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fuerza A'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('24 min 0 s'), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('Serie 2'), 300);
      expect(
        find.textContaining(
          'Serie 1 · 8 repeticiones · 50 kg externos · Completada',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Serie 2 · 6 repeticiones · 60 kg externos · Pendiente',
        ),
        findsOneWidget,
      );
    },
  );
}
