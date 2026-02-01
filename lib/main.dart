import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';

import 'app/theme/app_theme.dart';
import 'core/data/local_storage_service.dart';
import 'core/data/remote_sync_service.dart';
import 'core/data/repositories.dart';
import 'core/data/statistics_service.dart';
import 'core/domain/entities.dart';
import 'core/data/hive_sync_queue_store.dart';

import 'features/analytics/analytics_overview_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/groups/presentation/pages/groups_list_screen.dart';
import 'features/home/presentation/home_summary_screen.dart';
import 'features/nutrition/nutrition_screens.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/sleep/presentation/sleep_regularity_screen.dart';
import 'features/sleep/presentation/sleep_overview_screen.dart';
import 'features/sleep/presentation/sleep_history_screen.dart';
import 'features/sleep/sleep_screens.dart';
import 'features/streak/presentation/streak_screen.dart';
import 'features/workout/pro/workout_pro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase primero
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) Login anónimo (para que Firestore tenga un uid real)
  // Más adelante lo reemplazamos por tu LoginScreen (email/pass, Google, etc).
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  // 3) Hive (storage local)
  await Hive.initFlutter();

  // --- Services (local + remote sync) ---
  final local = await LocalStorageService.create();
  final statistics = StatisticsService();
  final syncQueue = await HiveSyncQueueStore.create();

  // 🔥 REAL: Firestore + sesión FirebaseAuth
  final remote = RemoteSyncService(
    transport: FirestoreRemoteSyncTransport(),
    session: FirebaseAuthSyncSession(FirebaseAuth.instance),
    network: const AlwaysOnlineNetworkStatus(),
    queue: syncQueue,
    policy: const SyncPolicy(),
    workoutAdapter: SyncAdapter<WorkoutEntry>(
      kind: SyncEntityKind.workout,
      idOf: (e) => e.id,
      updatedAtOf: (e) => e.updatedAt,
      deletedOf: (e) => e.deleted,
      toJson: (e) => e.toJson(),
    ),
    mealAdapter: SyncAdapter<MealEntry>(
      kind: SyncEntityKind.meal,
      idOf: (e) => e.id,
      updatedAtOf: (e) => e.updatedAt,
      deletedOf: (e) => e.deleted,
      toJson: (e) => e.toJson(),
    ),
    sleepAdapter: SyncAdapter<SleepEntry>(
      kind: SyncEntityKind.sleep,
      idOf: (e) => e.id,
      updatedAtOf: (e) => e.updatedAt,
      deletedOf: (e) => e.deleted,
      toJson: (e) => e.toJson(),
    ),
    preferencesAdapter: SyncAdapter<UserPreferences>(
      kind: SyncEntityKind.preferences,
      idOf: (e) => e.id,
      updatedAtOf: (e) => e.updatedAt,
      deletedOf: (e) => e.deleted,
      toJson: (e) => e.toJson(),
    ),
  );

  final repository = FitnessRepository(
    local: local,
    remote: remote,
    statistics: statistics,
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
        theme: AppTheme.dark,
        routes: {
          '/': (_) => const LoginScreen(),
          '/home': (_) => const HomeSummaryScreen(),
          '/auth/login': (_) => const LoginScreen(),
          '/auth/signup': (_) => const SignupScreen(),
          '/workout': (_) => const WorkoutProScreen(),
          '/nutrition': (_) => const NutritionProScreen(),
          '/sleep': (_) => const SleepProScreen(),
          '/sleep/overview': (_) => const SleepOverviewScreen(),
          '/sleep/history': (_) => const SleepHistoryScreen(),
          '/sleep/regularity': (_) => const SleepRegularityScreen(),
          '/analytics/overview': (_) => const AnalyticsOverviewScreen(),
          '/groups/list': (_) => const GroupsListScreen(),
          '/streak': (_) => const StreakScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
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
