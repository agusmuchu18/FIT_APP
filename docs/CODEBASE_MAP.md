# Codebase map

Índice para localizar código sin redescubrir el repositorio. Confirmar siempre
la implementación relevante con una búsqueda puntual antes de editar.

## Arranque y composición

| Ruta | Responsabilidad |
|---|---|
| `lib/main.dart` | Inicializa fechas, Firebase con fallback local, Hive, sincronización, `FitnessRepository`, rutas y `MaterialApp`. |
| `lib/firebase_options.dart` | Opciones cliente generadas por FlutterFire. |
| `lib/app/theme/app_theme.dart` | Tema global. |
| `lib/features/navigation/main_shell.dart` | Navegación principal y secciones raíz. |
| `lib/core/presentation/state/app_state.dart` | Estado transversal compartido. |

## Núcleo

| Ruta | Responsabilidad / relaciones |
|---|---|
| `lib/core/domain/entities.dart` | Entidades sincronizables: entrenamiento, comida, sueño y preferencias. |
| `lib/core/data/local_storage_service.dart` | Cajas Hive para esas cuatro entidades. |
| `lib/core/data/account_session_gate.dart` | Restablece la navegación/repositorio al cambiar cuenta; descarta restauraciones tardías. |
| `lib/core/data/account_storage_scope.dart` | Propiedad capturada, nombres Hive y preferencias de Entrenamiento por cuenta/invitado. |
| `lib/core/data/repositories.dart` | `FitnessRepository`: fachada local + sincronización remota. |
| `lib/core/data/remote_sync_service.dart` | Adaptadores, políticas, cola, pull/push y transporte Firestore. |
| `lib/core/data/hive_sync_queue_store.dart` | Persistencia Hive de operaciones pendientes. |
| `lib/core/data/statistics_service.dart` | Agregaciones de métricas. |
| `lib/core/data/app_preferences.dart` | Apariencia, avisos, accesibilidad, privacidad e integraciones en `SharedPreferences`. |
| `lib/core/data/home_modules_controller.dart` | Visibilidad de módulos opcionales. |
| `lib/core/integrations/` | Contrato y adaptadores HealthKit, Google Fit y Fitbit. Ver `INTEGRATIONS.md`. |

## Features

| Feature | Puntos de entrada y archivos clave |
|---|---|
| `analytics` | `analytics_overview_screen.dart`; consume métricas agregadas. |
| `auth` | `data/auth_service.dart`, `presentation/login_screen.dart`, `signup_screen.dart`; Firebase Auth. |
| `groups` | `domain/entities/group.dart`, `groups_service.dart`, páginas de lista/detalle. |
| `habits` | `domain/habit_models.dart`, `habit_progress_models.dart`, `habit_gallery_engine.dart`; creación, galería y tracker en `presentation/`. |
| `home` | `home_screen.dart`, `presentation/home_summary_screen.dart`, utilidades y detalles de actividad. |
| `modules` | Pantallas placeholder de psicología, laboratorio y ciclo menstrual. |
| `nutrition` | `domain/models.dart`; `data/offline_food_catalog.dart` carga el catálogo USDA empaquetado; `fdc_client.dart` usa proxy web o clave nativa; `food_repository.dart` combina catálogo, aprendidos, personalizados y caché; controladores/UI en `application/` y `presentation/`. |
| `onboarding` | Flujo inicial y páginas de onboarding. |
| `profile` | `profile_controller.dart`, perfil social, ajustes, avatar y fotos. |
| `settings` | Pantalla raíz, subpantallas, módulos e interfaz de integraciones; preferencias reales viven en `core/data/app_preferences.dart`. |
| `sleep` | Servicios de insights/horarios y pantallas de resumen, historial y regularidad. |
| `streak` | Pantalla de racha. |
| `workout` | Sesión y descanso en `application/` y `presentation/`; sesiones ricas y preferencias en `data/`; rutinas, búsqueda, historial y ajustes en `training_home/`; modelos, biblioteca y UI previa en `pro/`. |
| `common` | Colores y widgets reutilizables entre features. |

## Relaciones importantes

```text
main.dart -> RepositoryScope(FitnessRepository)
FitnessRepository -> LocalStorageService + RemoteSyncService + StatisticsService
RemoteSyncService -> HiveSyncQueueStore + FirestoreRemoteSyncTransport
AccountSessionGate -> namespace local + StaticSyncSession con uid capturado
FitnessIntegrationManager -> servicios externos -> FitnessRepository
Nutrition UI -> controladores -> FoodRepository -> catálogo offline + FdcClient/proxy
Workout UI -> controladores -> WorkoutRepository/RoutinesRepository -> Hive + preferencias
WorkoutSessionController -> FitnessRepository.saveWorkout -> Home/Rachas
workout_completion_recovery.dart -> repara proyección de sesión rica al arrancar
```

El estado no está unificado: conviven `Provider`/`ChangeNotifier`,
`InheritedWidget`, controladores singleton y estado local de widgets. Ver límites
en `ARCHITECTURE.md`.

## Pruebas

| Ruta | Cobertura principal |
|---|---|
| `test/features/habits/domain/` | Reglas de frecuencia, galería, templates y popularidad. |
| `test/features/home/domain/` | Normalización y agregación por día. |
| `test/features/nutrition/` | Cliente/proxy USDA, catálogo offline, persistencia y selector de cantidades. |
| `test/features/workout/` | Rutinas, sesión, migración, descanso, guardado, búsqueda y mini barra. |
| `integration_test/workout_local_journey_test.dart` | Recorrido móvil local preparado; comparte acciones con el ensayo host en `test/support/workout_device_journey.dart`. No ejecutado en Android/iPhone. |
| `test/training_home_screen_test.dart` | Estados principales del home de entrenamiento. |
| `test/goldens/` | Perfil, Entrenamiento, Crear rutina, sesión y edición de series; generadas en Windows. |

Ejecutar primero el archivo de prueba asociado al feature.

### Continuidad de Entrenamiento

- Rediseño 12/10: `docs/plans/WORKOUT_REDESIGN_2026_10_12.md` contiene aceptación,
  evidencia y límites. Leer antes de ampliar el módulo.
- Cálculos únicos: `features/workout/domain/workout_analytics.dart`; período,
  volumen externo, series válidas, distribución y comparación conservadora.
- Resumen persistido por ID: `presentation/workout_summary_screen.dart`.
- Historial filtrado/agregado una vez: `training_home/workout_history_screen.dart`.
- Detalle y repetición: `presentation/workout_history_detail_screen.dart` y
  `application/workout_repeat_service.dart`; nueva identidad y referencia al original.
- Presentación compartida: `presentation/widgets/workout_report_widgets.dart`.
- Media local: inventario/prompts en `docs/design/WORKOUT_ASSETS_2026_10_12.json`.

- `docs/plans/WORKOUT_READINESS_2026_10_01.md`: cambios, pruebas y pendientes de cierre.
- `test/features/workout/workout_account_isolation_test.dart`: invitado/cuentas,
  escrituras tardías, reapertura Hive y restauración de navegación.
- `test/features/workout/workout_session_functional_test.dart`: recorridos de sesión,
  tiempo, asistencia, borrado, corrupción, configuración y texto ampliado.
- Perfil visible: `lib/features/profile/profile_social_screen.dart`; el golden
  previo de otra pantalla de perfil no valida esta vista.
- Barra global/rutas: `features/workout/widgets/workout_mini_bar_host_overlay.dart`.
- Diseño: `docs/design/DESIGN_SYSTEM.md`; evidencia y defectos visuales: `docs/UX_AUDIT.md`.

## Plataforma y automatización

- Plataformas: `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- Dependencias: `pubspec.yaml` y `pubspec.lock`.
- Calidad: `.github/workflows/ci.yml`.
- GitHub Pages: `.github/workflows/pages.yml`.
- Actualizaciones: `.github/dependabot.yml`.
- Firebase: `firebase.json`, `.firebaserc` y `firestore.rules`; proxy USDA gratuito en `worker/`.
