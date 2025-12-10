import '../data/repositories.dart';
import '../domain/entities.dart';
import 'models.dart';
import 'platform_integration_service.dart';

/// Coordinates syncing platform data, mapping it into domain entities and
/// resolving conflicts with manual entries.
class FitnessIntegrationManager {
  FitnessIntegrationManager({
    required FitnessRepository repository,
    required List<PlatformIntegrationService> integrations,
  })  : _repository = repository,
        _integrations = integrations;

  final FitnessRepository _repository;
  final List<PlatformIntegrationService> _integrations;

  /// Requests permissions, enables background sync and persists any new samples.
  Future<void> syncAll({bool syncRemote = false}) async {
    final manualWorkouts = await _repository.getWorkouts();
    final manualMeals = await _repository.getMeals();
    final manualSleep = await _repository.getSleep();

    for (final integration in _integrations) {
      final permitted = await integration.hasPermissions() ||
          await integration.requestPermissions();
      if (!permitted) continue;

      await integration.enableBackgroundSync();
      final samples = await integration.fetchLatestSamples();

      await _persistWorkouts(
        samples.where((sample) =>
            sample.type == FitnessDataType.workout ||
            sample.type == FitnessDataType.steps),
        manualWorkouts,
        syncRemote,
      );

      await _persistMeals(
        samples.where((sample) => sample.type == FitnessDataType.nutrition),
        manualMeals,
        syncRemote,
      );

      await _persistSleep(
        samples.where((sample) => sample.type == FitnessDataType.sleep),
        manualSleep,
        syncRemote,
      );
    }
  }

  Future<void> _persistWorkouts(
    Iterable<ExternalFitnessSample> samples,
    List<WorkoutEntry> manualEntries,
    bool syncRemote,
  ) async {
    final existing = await _repository.getWorkouts();
    for (final sample in samples) {
      final mapped = sample.toWorkout();
      if (_isDuplicateWorkout(mapped, manualEntries, existing)) continue;
      await _repository.saveWorkout(mapped, sync: syncRemote);
      existing.add(mapped);
    }
  }

  Future<void> _persistMeals(
    Iterable<ExternalFitnessSample> samples,
    List<MealEntry> manualEntries,
    bool syncRemote,
  ) async {
    final existing = await _repository.getMeals();
    for (final sample in samples) {
      final mapped = sample.toMeal();
      if (_isDuplicateMeal(mapped, manualEntries, existing)) continue;
      await _repository.saveMeal(mapped, sync: syncRemote);
      existing.add(mapped);
    }
  }

  Future<void> _persistSleep(
    Iterable<ExternalFitnessSample> samples,
    List<SleepEntry> manualEntries,
    bool syncRemote,
  ) async {
    final existing = await _repository.getSleep();
    for (final sample in samples) {
      final mapped = sample.toSleep();
      if (_isDuplicateSleep(mapped, manualEntries, existing)) continue;
      await _repository.saveSleep(mapped, sync: syncRemote);
      existing.add(mapped);
    }
  }

  bool _isDuplicateWorkout(
    WorkoutEntry candidate,
    List<WorkoutEntry> manualEntries,
    List<WorkoutEntry> syncedEntries,
  ) {
    return _matchesWorkout(candidate, manualEntries) ||
        _matchesWorkout(candidate, syncedEntries);
  }

  bool _matchesWorkout(WorkoutEntry candidate, List<WorkoutEntry> entries) {
    return entries.any(
      (entry) =>
          entry.name.toLowerCase() == candidate.name.toLowerCase() &&
          entry.durationMinutes == candidate.durationMinutes &&
          entry.intensity == candidate.intensity,
    );
  }

  bool _isDuplicateMeal(
    MealEntry candidate,
    List<MealEntry> manualEntries,
    List<MealEntry> syncedEntries,
  ) {
    return _matchesMeal(candidate, manualEntries) ||
        _matchesMeal(candidate, syncedEntries);
  }

  bool _matchesMeal(MealEntry candidate, List<MealEntry> entries) {
    return entries.any(
      (entry) =>
          entry.title.toLowerCase() == candidate.title.toLowerCase() &&
          entry.calories == candidate.calories &&
          entry.macros.carbs == candidate.macros.carbs &&
          entry.macros.protein == candidate.macros.protein &&
          entry.macros.fat == candidate.macros.fat,
    );
  }

  bool _isDuplicateSleep(
    SleepEntry candidate,
    List<SleepEntry> manualEntries,
    List<SleepEntry> syncedEntries,
  ) {
    return _matchesSleep(candidate, manualEntries) ||
        _matchesSleep(candidate, syncedEntries);
  }

  bool _matchesSleep(SleepEntry candidate, List<SleepEntry> entries) {
    return entries.any(
      (entry) =>
          entry.hours == candidate.hours &&
          entry.quality.toLowerCase() == candidate.quality.toLowerCase(),
    );
  }
}
