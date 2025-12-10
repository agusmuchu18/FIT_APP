import 'package:flutter/material.dart';

import 'app/theme/app_theme.dart';
import 'core/data/local_storage_service.dart';
import 'core/data/remote_sync_service.dart';
import 'core/data/repositories.dart';
import 'core/data/statistics_service.dart';
import 'features/analytics/analytics_overview_screen.dart';
import 'features/nutrition/nutrition_screens.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/sleep/sleep_screens.dart';
import 'features/workout/workout_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = FitnessRepository(
    local: LocalStorageService(),
    remote: const RemoteSyncService(),
    statistics: StatisticsService(),
  );

  runApp(FitApp(repository: repository));
}

class FitApp extends StatelessWidget {
  const FitApp({
    super.key,
    required this.repository,
  });

  final FitnessRepository repository;

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repository: repository,
      child: MaterialApp(
        title: 'FIT App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routes: {
          '/': (_) => const OnboardingScreen(),
          '/workout/lite': (_) => const WorkoutLiteScreen(),
          '/workout/pro': (_) => const WorkoutProScreen(),
          '/nutrition/lite': (_) => const NutritionLiteScreen(),
          '/nutrition/pro': (_) => const NutritionProScreen(),
          '/sleep/lite': (_) => const SleepLiteScreen(),
          '/sleep/pro': (_) => const SleepProScreen(),
          '/analytics/overview': (_) => const AnalyticsOverviewScreen(),
        },
      ),
    );
  }
}

class RepositoryScope extends InheritedWidget {
  const RepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });

  final FitnessRepository repository;

  static FitnessRepository of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RepositoryScope>();
    assert(scope != null, 'RepositoryScope not found in context');
    return scope!.repository;
  }

  @override
  bool updateShouldNotify(covariant RepositoryScope oldWidget) {
    return repository != oldWidget.repository;
  }
}
