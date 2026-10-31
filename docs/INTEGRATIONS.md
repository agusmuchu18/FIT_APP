# Integrations

## Firebase

| Área | Implementación | Estado |
|---|---|---|
| Configuración Dart | `lib/firebase_options.dart` | Presente. Las claves cliente no sustituyen Rules/App Check. |
| Arranque | `lib/main.dart` | Firebase con fallback local controlado. |
| Auth | `features/auth/data/auth_service.dart` | Email/password, anónimo y sign-out reales. |
| Firestore | `core/data/remote_sync_service.dart` | Transporte para cuatro tipos sincronizables. |
| Reglas | `firebase.json`, `firestore.rules` | Versionadas; falta desplegar y probar con Emulator Suite. |

Faltan `android/app/google-services.json` y los
`GoogleService-Info.plist` de Apple. Antes de producción: registrar package IDs
definitivos, habilitar proveedores, configurar App Check y separar proyectos de
desarrollo/staging/producción.

## USDA FoodData Central

| Ruta | Responsabilidad |
|---|---|
| `features/nutrition/data/nutrition_api_config.dart` | Proxy por defecto en web; `USDA_API_KEY` sólo en plataformas no web. |
| `features/nutrition/data/fdc_client.dart` | Search/details HTTP por proxy o acceso nativo, sin enviar el secreto desde web. |
| `features/nutrition/data/fdc_mapper.dart` | Convierte respuesta FDC a modelos internos. |
| `features/nutrition/data/food_repository.dart` | Combina catálogo local, remoto y caché. |
| `features/nutrition/data/food_cache.dart` | TTL y límites de búsqueda/detalle. |
| `features/nutrition/data/offline_food_catalog.dart` | Catálogo Foundation 04/2026, aliases españoles y caché de carga. |
| `worker/` | Cloudflare Worker gratuito: CORS, validación, caché, rate limit y secreto cifrado. |

El proxy está desplegado en
`fit-app-usda-proxy.agusmuchu18-fit-app.workers.dev`, con `USDA_API_KEY` cifrada
en Cloudflare. La prueba pública de búsqueda y detalle devuelve datos, CORS sólo
a orígenes permitidos y la búsqueda reintenta sin el filtro opcional si USDA falla.
No guardar la clave en Dart, CI ni archivos. El modo offline incluye 363 alimentos
oficiales y conserva hasta 500 alimentos USDA consultados anteriormente.

## Salud y actividad de plataforma

Contrato común: `core/integrations/platform_integration_service.dart`.
`FitnessIntegrationManager` solicita permisos, obtiene muestras, evita
duplicados y las transforma en entidades guardadas por `FitnessRepository`.

| Fuente | Archivo Dart | Canal |
|---|---|---|
| HealthKit | `healthkit_service.dart` | `fit_app/integrations/healthkit` |
| Google Fit | `google_fit_service.dart` | `fit_app/integrations/google_fit` |
| Fitbit | `fitbit_service.dart` | `fit_app/integrations/fitbit` |

Los tres adaptadores usan `MethodChannel`, pero actualmente no existen handlers
en Android, iOS, macOS, Windows ni Linux. La UI debe tratarlos como no
disponibles/“Próximamente” hasta implementar permisos, OAuth cuando corresponda,
revocación, background sync y pruebas en dispositivo. Para Android, revisar la
migración de Google Fit hacia Health Connect al implementar el backend real.

## Configuración de distribución relacionada

- Firestore: push transaccional e idempotente; pull paginado (500 por página),
  orden `updatedAt` + ID, borde temporal inclusivo. Validado con dobles de
  contrato, no emulador. Migrar a cursor de servidor para escrituras tardías.
- Figma: archivo `YPwZfXA2Lw46DfPFCTBmpX`, Foundations creada; última operación
  de componentes rechazada por cupo MCP Starter. Ver `DESIGN_SYSTEM.md`.

- GitHub Pages construye la web con la URL del Worker, nunca con la clave USDA.
- Android SDK 36 compiló y verificó los APK debug/release de la etapa anterior;
  no incorporan cambios posteriores. Prueba física aplazada por el usuario.
- Android release todavía firma con el certificado de debug.
- Los identificadores nativos siguen usando `com.example`.
- No guardar secretos de backend, tokens OAuth ni keystores en el repositorio.
