# Auditoría de integraciones
23/10/2026. Catálogo real: IntegrationId (18), integrations_screen.dart.

| Fuente | Estado comprobado en código | Dependencia |
|---|---|---|
| Apple Health | Parcial: MethodChannel Dart; sin handler iOS | HealthKit capability, tipos/permisos, Mac/Xcode/dispositivo |
| Google Fit | Parcial: stub MethodChannel; sin handler Android | Diseñar migración Health Connect; no equivalencia entre APIs |
| Fitbit | Parcial: MethodChannel sin implementación nativa/OAuth | API oficial, permisos, credenciales/registro y revocación |
| Strava, TrainingPeaks, Garmin, Suunto, Polar, Catapult Sports | No implementada | Acceso/credenciales/aprobación oficial según proveedor |
| Whoop, Apple Watch, banda FC, anillo genérico, Oura, Sleep Cycle | No implementada | Plataforma, SDK/API oficial y hardware según fuente |
| Open Food Facts, MyFitnessPal, Cronometer | No implementada como conexión | Cliente/contrato y autenticación cuando corresponda |

Ninguna conexión de este catálogo está verificada en dispositivo o con un token
válido. Un bool conectado guardado o un permiso local no certifica sincronización.
lastSync solo se actualiza después de importar/escribir correctamente, nunca al
tocar Conectar. Desconectar no equivale a revocar al proveedor sin API de revocación.
USDA es un servicio de catálogo aparte que ya funciona; no se modifica aquí.

Contrato común existente: core/integrations/platform_integration_service.dart.
Manager actual mapea muestras/evita duplicados parcialmente; ampliar procedencia,
cursor por conector, IDs externos, permisos por dato y política de conflictos. No
habilitar background/health data con handlers ausentes ni meter secretos en Flutter.

Fuentes oficiales consultadas: [Google Fit/migración](https://developer.android.com/health-and-fitness/health-connect/migration/fit),
[autorización HealthKit](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).
Pendiente consultar contrato y elegibilidad actual de cada API antes de implementarla.
