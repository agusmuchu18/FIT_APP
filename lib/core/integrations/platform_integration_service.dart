import 'models.dart';

/// Abstraction around platform APIs so that integrations can be swapped or mocked.
abstract class PlatformIntegrationService {
  FitnessSource get source;

  /// Returns true if the application already has permission to read data.
  Future<bool> hasPermissions();

  /// Requests the required permissions from the user.
  Future<bool> requestPermissions();

  /// Starts background delivery or periodic fetches when the platform supports it.
  Future<void> enableBackgroundSync();

  /// Loads the latest samples mapped into [ExternalFitnessSample].
  Future<List<ExternalFitnessSample>> fetchLatestSamples();
}
