import 'package:fit_app/core/data/repositories.dart';
import 'package:fit_app/core/data/statistics_service.dart';
import 'package:fit_app/core/domain/entities.dart';
import 'package:fit_app/features/home/presentation/home_summary_screen.dart';
import 'package:fit_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeTestRepository implements FitnessRepository {
  final entries = <WorkoutEntry>[];
  final meals = <MealEntry>[];
  UserPreferences? preferences;

  @override
  final ValueNotifier<int> workoutsRevision = ValueNotifier<int>(0);
  @override
  final ValueNotifier<int> mealsRevision = ValueNotifier<int>(0);

  @override
  Future<void> saveWorkout(WorkoutEntry entry, {bool sync = false}) async {
    entries.add(entry);
    workoutsRevision.value++;
  }

  @override
  Future<List<WorkoutEntry>> getWorkouts() async => entries;

  @override
  Future<List<MealEntry>> getMeals() async => meals;
  @override
  Future<void> saveMeal(MealEntry meal, {bool sync = false}) async {
    meals.add(meal);
    mealsRevision.value++;
  }

  @override
  Future<List<SleepEntry>> getSleep() async => [];

  @override
  Future<UserPreferences?> getPreferences() async => preferences;

  @override
  Future<NutritionMetrics?> getDailyNutritionStats(DateTime date) async => null;

  @override
  Future<List<NutritionMetrics>> getWeeklyNutritionStats({
    int days = 7,
  }) async => [];

  @override
  Future<Macros> getMacroDistribution({int days = 7}) async =>
      const Macros(carbs: 0, protein: 0, fat: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('Home has no invented nutrition goal and updates after a meal', (
    tester,
  ) async {
    final repository = HomeTestRepository();
    addTearDown(repository.workoutsRevision.dispose);
    addTearDown(repository.mealsRevision.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryScope(
          repository: repository,
          child: const HomeSummaryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Sin macronutrientes registrados'), findsOneWidget);
    await repository.saveMeal(
      MealEntry(
        id: 'meal-uuid',
        consumedAt: DateTime.now(),
        title: 'Test only',
        calories: 100,
        macros: const Macros(carbs: 10, protein: 5, fat: 4),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('100 kcal'), findsOneWidget);
    expect(find.text('Sin meta'), findsOneWidget);
    expect(find.textContaining('% vs objetivo'), findsNothing);
    repository.preferences = UserPreferences(
      id: 'prefs',
      primaryGoal: 'Personal',
      experienceLevel: 'beginner',
      targetSessionsPerWeek: 3,
      modePreference: 'full',
      targetCalories: 1000,
    );
    repository.mealsRevision.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('-90% vs objetivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home refreshes training total after a workout is saved', (
    tester,
  ) async {
    final repository = HomeTestRepository();
    addTearDown(repository.workoutsRevision.dispose);
    addTearDown(repository.mealsRevision.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryScope(
          repository: repository,
          child: const HomeSummaryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('0 min'), findsWidgets);

    await repository.saveWorkout(
      WorkoutEntry(
        id: 'saved-workout',
        name: 'Fuerza',
        durationMinutes: 25,
        intensity: 'No registrada',
        meta: EntityMeta(
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
          deleted: false,
          revision: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('25 min'), findsOneWidget);
  });
}
