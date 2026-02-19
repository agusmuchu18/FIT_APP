import 'package:fit_app/features/workout/widgets/workout_mini_bar.dart';
import 'package:fit_app/features/workout/workout_in_progress_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WorkoutInProgressDraft buildDraft({
    required DateTime startTime,
    bool isPaused = false,
    DateTime? pausedAt,
    Duration accumulatedPaused = Duration.zero,
  }) {
    return WorkoutInProgressDraft(
      workoutId: 'test-id',
      routineName: 'Rutina test',
      startTime: startTime,
      isPaused: isPaused,
      pausedAt: pausedAt,
      accumulatedPaused: accumulatedPaused,
      lastUpdated: DateTime.now(),
    );
  }

  testWidgets('muestra mini bar con título y timer mm:ss cuando hay draft', (tester) async {
    final notifier = ValueNotifier<WorkoutInProgressDraft?>(
      buildDraft(startTime: DateTime.now().subtract(const Duration(minutes: 2, seconds: 5))),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<WorkoutInProgressDraft?>(
            valueListenable: notifier,
            builder: (_, draft, __) {
              if (draft == null) return const SizedBox.shrink();
              return WorkoutMiniBar(
                draft: draft,
                onContinue: () {},
                onPauseResume: () {},
                onDiscard: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Entrenamiento en curso'), findsOneWidget);
    expect(find.textMatching(RegExp(r'^\d{2}:\d{2}$')), findsOneWidget);
    expect(find.byType(WorkoutMiniBar), findsOneWidget);
  });

  testWidgets('al descartar y confirmar, desaparece la mini bar', (tester) async {
    final notifier = ValueNotifier<WorkoutInProgressDraft?>(
      buildDraft(startTime: DateTime.now().subtract(const Duration(minutes: 1))),
    );

    Future<void> confirmDiscard(BuildContext context) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Descartar entrenamiento'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Descartar')),
          ],
        ),
      );
      if (confirmed == true) {
        notifier.value = null;
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<WorkoutInProgressDraft?>(
            valueListenable: notifier,
            builder: (context, draft, _) {
              if (draft == null) return const SizedBox.shrink();
              return WorkoutMiniBar(
                draft: draft,
                onContinue: () {},
                onPauseResume: () {},
                onDiscard: () => confirmDiscard(context),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(WorkoutMiniBar), findsOneWidget);
    await tester.tap(find.byTooltip('Descartar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar').last);
    await tester.pumpAndSettle();

    expect(find.byType(WorkoutMiniBar), findsNothing);
  });
}
