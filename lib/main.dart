import 'package:flutter/material.dart';

import 'features/nutrition/data/nutrition_day_repository.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';

import 'app/theme/app_theme.dart';
import 'core/data/local_storage_service.dart';
import 'core/data/remote_sync_service.dart';
import 'core/data/repositories.dart';
import 'core/data/statistics_service.dart';
import 'core/domain/entities.dart';
import 'core/data/hive_sync_queue_store.dart';
import 'core/data/account_storage_scope.dart';
import 'core/data/account_session_gate.dart';

import 'features/analytics/analytics_overview_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/signup_screen.dart';
import 'features/groups/presentation/pages/groups_list_screen.dart';
import 'features/habits/presentation/habits_tracker_screen.dart';
import 'features/navigation/main_shell.dart';
import 'features/nutrition/nutrition_screens.dart';
import 'features/nutrition/presentation/template_editor_screen.dart';
import 'features/nutrition/presentation/templates_screen.dart';
import 'features/nutrition/presentation/quick_add_placeholder_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/sleep/presentation/sleep_regularity_screen.dart';
import 'features/sleep/presentation/sleep_overview_screen.dart';
import 'features/sleep/presentation/sleep_history_screen.dart';
import 'features/sleep/sleep_screens.dart';
import 'features/streak/presentation/streak_screen.dart';
import 'features/profile/profile_social_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/presentation/integrations/integrations_screen.dart';
import 'features/settings/screens/settings_subscreens.dart';
import 'features/modules/presentation/optional_module_placeholders.dart';
import 'features/settings/screens/modules_settings_screen.dart';
import 'features/workout/presentation/workout_in_progress_screen.dart';
import 'features/workout/pro/workout_pro_screen.dart';
import 'features/workout/data/workout_repository.dart';
import 'features/workout/application/legacy_draft_migration.dart';
import 'features/workout/application/workout_completion_recovery.dart';
import 'features/workout/training_home/template_exercise_picker_screen.dart';
import 'features/workout/training_home/routine_search_screen.dart';
import 'features/workout/training_home/workout_history_screen.dart';
import 'features/workout/presentation/workout_summary_screen.dart';
import 'features/workout/training_home/workout_settings_screen.dart';
import 'features/workout/training_home/training_home_screen.dart';
import 'features/workout/workout_in_progress_controller.dart';
import 'features/workout/widgets/workout_mini_bar_host_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'app bootstrap',
        context: ErrorDescription(
          'initializing Firebase; continuing in local-only mode',
        ),
      ),
    );
  }

  // Hive mantiene la aplicación utilizable aun si el backend no está disponible.
  await Hive.initFlutter();

  final accounts = Firebase.apps.isEmpty
      ? Stream<String?>.value(null)
      : FirebaseAuth.instance.authStateChanges().map(
          (user) => user == null || user.isAnonymous ? null : user.uid,
        );
  runApp(
    AccountSessionGate<FitnessRepository>(
      theme: AppTheme.dark,
      accounts: accounts,
      restore: _createAccountRepository,
      builder: (repository) => FitApp(repository: repository),
    ),
  );
}

Future<FitnessRepository> _createAccountRepository(
  String? userId,
  String scope,
) async {
  if (AccountStorageScope.current == scope) {
    WorkoutInProgressController.instance.resetSession();
  }

  // --- Services (local + remote sync) ---
  final local = await LocalStorageService.create(scope: scope);
  await Hive.openBox<String>(
    AccountStorageScope.boxName(WorkoutRepository.richSessionsBoxName, scope),
  );
  final statistics = StatisticsService();
  final syncQueue = await HiveSyncQueueStore.create(scope: scope);

  final remote = RemoteSyncService(
    transport: userId == null
        ? NoopRemoteSyncTransport()
        : FirestoreRemoteSyncTransport(),
    session: StaticSyncSession(userId: userId ?? 'local-only'),
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

  // Capture this scope before any awaits; a previous account can finish a write safely.
  try {
    await NutritionDayRepository(scope: scope, fitness: repository).recover();
  } catch (_, stack) {
    // Nutrition offers retry without preventing access to other modules.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError(
          'Recuperación nutricional pendiente; los originales se conservan.',
        ),
        stack: stack,
        library: 'nutrition recovery',
      ),
    );
  }
  if (AccountStorageScope.current == scope) {
    final sessions = WorkoutRepository();
    await recoverCompletedWorkouts(sessions, repository);
    // Drafts left by the old screen open in the live session screen. This
    // runs only at sign-in, never while the old screen may be editing one.
    await LegacyDraftMigration.run(
      await ScopedPreferences.getInstance(scope: scope),
    ).catchError((Object _) => false);
    if (AccountStorageScope.current == scope) {
      await WorkoutInProgressController.instance.refresh();
    }
  }
  return repository;
}

class FitApp extends StatelessWidget {
  const FitApp({super.key, required this.repository});

  final FitnessRepository repository;
  static final WorkoutMiniBarRouteObserver _workoutMiniBarRouteObserver =
      WorkoutMiniBarRouteObserver();

  @override
  Widget build(BuildContext context) {
    return RepositoryScope(
      repository: repository,
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        navigatorObservers: [_workoutMiniBarRouteObserver],
        title: 'FIT App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: workoutMiniBarAppBuilder,
        routes: {
          '/': (_) {
            final user = Firebase.apps.isEmpty
                ? null
                : FirebaseAuth.instance.currentUser;
            return user != null ? const MainShell() : const LoginScreen();
          },
          '/home': (_) => const MainShell(),
          '/auth/login': (_) => const LoginScreen(),
          '/auth/signup': (_) => const SignupScreen(),
          '/workout': (_) => const TrainingHomeScreen(),
          '/workout/session': (_) =>
              WorkoutInProgressController.instance.isLegacyDraftActive
              ? WorkoutProScreen(fitnessRepository: repository)
              : WorkoutInProgressScreen(fitnessRepository: repository),
          '/workout/history': (_) => const WorkoutHistoryScreen(),
          '/workout/summary': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            return WorkoutSummaryScreen(sessionId: args is String ? args : '');
          },
          '/workout/detail': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            return WorkoutHistoryDetailScreen(
              sessionId: args is String ? args : '',
            );
          },
          '/workout/settings': (_) => const WorkoutSettingsScreen(),
          '/workout/routines/new': (_) => const TemplateExercisePickerScreen(),
          '/workout/routines/search': (_) => const WorkoutRoutineSearchScreen(),
          '/nutrition': (_) => const NutritionProScreen(),
          '/nutrition/home': (_) => const NutritionProScreen(),
          '/nutrition/templates': (_) => const TemplatesScreen(),
          '/nutrition/template_editor': (_) => const TemplateEditorScreen(),
          '/nutrition/quick_add': (_) =>
              const NutritionQuickAddPlaceholderScreen(),
          '/sleep': (_) => const SleepProScreen(),
          '/sleep/overview': (_) => const SleepOverviewScreen(),
          '/sleep/history': (_) => const SleepHistoryScreen(),
          '/sleep/regularity': (_) => const SleepRegularityScreen(),
          '/analytics/overview': (_) => const AnalyticsOverviewScreen(),
          '/groups/list': (_) => const GroupsListScreen(),
          '/streak': (_) => const StreakScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/profile': (_) => const ProfileSocialScreen(),
          '/profile/progress_photos': (_) =>
              const ProgressPhotosGalleryScreen(),
          '/profile/activity': (_) => const ProfileActivityHistoryScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/settings/appearance': (_) => const AppearanceSettingsScreen(),
          '/settings/notifications': (_) => const NotificationsSettingsScreen(),
          '/settings/privacy': (_) => const PrivacySettingsScreen(),
          '/settings/integrations': (_) => const IntegrationsSettingsScreen(),
          '/settings/data': (_) => const DataSettingsScreen(),
          '/settings/accessibility': (_) => const AccessibilitySettingsScreen(),
          '/settings/about': (_) => const AboutSettingsScreen(),
          '/settings/modules': (_) => const ModulesSettingsScreen(),
          '/habits': (_) => const HabitsTrackerScreen(),
          '/psychology': (_) => const PsychologyModuleScreen(),
          '/lab': (_) => const LabModuleScreen(),
          '/menstrual': (_) => const MenstrualModuleScreen(),
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
