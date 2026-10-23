import 'integration_models.dart';

/// Audited capabilities, not preferences or successful OAuth/synchronization.
/// No current connector has a native handler or verified provider connection.
abstract final class IntegrationReadiness {
  static bool canConnect(IntegrationId id) => false;
  static String label(IntegrationId id) => switch (id) {
    IntegrationId.appleHealth ||
    IntegrationId.googleFit => 'Adaptador pendiente',
    IntegrationId.fitbit => 'Autorización pendiente',
    _ => 'Sin implementar',
  };
  static String reason(IntegrationId id) => switch (id) {
    IntegrationId.appleHealth => 'Requiere iPhone, permisos de HealthKit y el adaptador nativo. Todavía no hay una conexión verificada ni se importan datos.',
    IntegrationId.googleFit => 'La conexión Android está pendiente. La integración debe usar una API de salud compatible y permisos específicos; el acceso anterior de Google Fit no verifica Health Connect.',
    IntegrationId.fitbit => 'Requiere autorización oficial del proveedor y completar la integración. No hay una conexión verificada ni se importan datos.',
    _ => 'Esta conexión todavía no está implementada. No se solicitan permisos ni se importan datos del servicio.',
  };
  // Keep old preferences intact, but never use an old bool as proof of access.
  static IntegrationStatus verifiedStatus(
    IntegrationId id,
    IntegrationStatus stored,
  ) => const IntegrationStatus();
}
