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
| `groups` | `domain/entities/group.dart`, `groups_service.dart`: contactos locales durables por dueño, sin métricas implícitas; lista/detalle y `group_entry_form.dart`. No son membresías remotas. |
| `habits` | `domain/habit_models.dart`, `habit_progress_models.dart`, `habit_gallery_engine.dart`; creación, galería y tracker en `presentation/`. |
| `home` | `home_screen.dart`, `presentation/home_summary_screen.dart`, utilidades y detalles de actividad. |
| `modules` | Pantallas placeholder de psicología, laboratorio y ciclo menstrual. |
| `nutrition` | `domain/models.dart`; `data/offline_food_catalog.dart` carga el catálogo USDA empaquetado; `fdc_client.dart` usa proxy web o clave nativa; `food_repository.dart` combina catálogo, aprendidos, personalizados y caché; controladores/UI en `application/` y `presentation/`. |
| `onboarding` | Flujo inicial y páginas de onboarding. |
| `profile` | `profile_controller.dart`: identidad privada por cuenta; Fotos/Estadísticas/PRs conservadas. `data/social_identity_client.dart`, `social_attestation.dart`, `application/profile_discovery_controller.dart`, `social_profile_editor.dart`, `public_profile_screen.dart`: identidad pública autorizada, sin datos de salud. `body_measurement.dart`, `data/body_measurement_repository.dart`, `body_measurements_screen.dart`, `body_measurement_form.dart`: medidas manuales privadas en Hive por dueño, historial/gráfico/comparación. Galería durable pendiente. |
| `settings` | Pantalla raíz, subpantallas, módulos e integraciones; `integration_readiness.dart` evita conexiones ficticias. Preferencias en `core/data/app_preferences.dart`. |
| `sleep` | Servicios de insights/horarios y pantallas de resumen, historial y regularidad. |
| `streak` | Pantalla de racha. |
| `workout` | Sesión y descanso en `application/` y `presentation/`; sesiones ricas y preferencias en `data/`; rutinas, búsqueda, historial y ajustes en `training_home/`; modelos, biblioteca y UI previa en `pro/`. |
| `common` | Colores y widgets reutilizables entre features. |

## Relaciones importantes

Nutrition 2.0, cortes A y B–H incrementales: `docs/nutrition/MASTER_PLAN.md` y `NUTRITION_AUDIT.md`.
`NutritionDayRepository` es el diario rico Hive v2 por cuenta; proyecta por ID
a `MealEntry` para Inicio/Analytics. `nutrition_writes.dart` ordena escrituras
por dueño. Snapshot decimal y fecha explícita evitan reconstrucciones por título.
Ver migración, recuperación y límites de sync en `docs/nutrition/ARCHITECTURE.md`.

Expansión complementaria: `docs/expansion/MASTER_PLAN.md`, `FEATURE_AUDIT.md`,
`IMPLEMENTATION_STATUS.md`, `PRIVACY_MODEL.md` y `TEST_REPORT.md`.
API social: `backend/social/src/social_identity.js`, callable `src/index.js`;
emuladores `firebase.social.json`, reglas `firestore.rules`. Descubrir vive en
`groups/presentation/pages/discover_profiles_panel.dart`, sin pestaña principal.

```text
main.dart -> RepositoryScope(FitnessRepository)
FitnessRepository -> LocalStorageService + RemoteSyncService + StatisticsService
RemoteSyncService -> HiveSyncQueueStore + FirestoreRemoteSyncTransport
AccountSessionGate -> namespace local + StaticSyncSession con uid capturado
FitnessIntegrationManager -> servicios externos -> FitnessRepository
Nutrition UI -> controladores -> FoodRepository -> catálogo offline + FdcClient/proxy
Workout UI -> controladores -> WorkoutRepository/RoutinesRepository -> Hive + preferencias
WorkoutSessionController -> FitnessRepository.saveWorkout -> Home/Rachas
Explorador/ficha/revisión/edición -> RoutineDraftController -> borrador por cuenta
RoutinesRepository -> WorkoutTemplate con planes por serie/fútbol -> sesión con resultados separados
workout_completion_recovery.dart -> repara proyección de sesión rica al arrancar
```

El estado no está unificado: conviven `Provider`/`ChangeNotifier`,
`InheritedWidget`, controladores singleton y estado local de widgets. Ver límites
en `ARCHITECTURE.md`.

Para rutinas: `training_home/template_exercise_picker_screen.dart`,
`exercise_configuration_sheet.dart`, `routine_review_screen.dart` y
`routine_draft_controller.dart`. Fútbol/validación: `domain/sport_activity.dart`
y `routine_plan_validation.dart`. Evidencia e inventario:
`docs/plans/ROUTINE_SYSTEM_2026_10_12.md`; cobertura de imágenes:
`docs/design/EXERCISE_ART_MANIFEST.json`. Buscar el símbolo relevante antes de
leer el catálogo completo de 297 ejercicios.

Ajuste inline del explorador: `exercise_configuration_sheet.dart` comparte formulario
con la edición; `exercise_technical_screen.dart` abre sólo desde el nombre.
Filtros: `routine_filter_sheet.dart`, `presentation/widgets/routine_filter_artwork.dart`
y traducciones en `domain/routine_labels.dart`. Evidencia del comportamiento y
taxonomía heredada: `docs/plans/ROUTINE_INLINE_UX_2026_10_14.md`.

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

- Peso corporal adaptativo (25/10): `domain/exercise_load_policy.dart` clasifica
  metadatos; `presentation/widgets/bodyweight_mode_selector.dart` reutiliza la
  expansión inline en rutinas/sesión/series. Modalidad por serie en modelos
  existentes, sin segundo motor. Contratos, fórmulas y aceptación:
  `docs/plans/BODYWEIGHT_ADAPTIVE_REGISTRATION.md`.

- Expansión 17–21/10: auditoría `docs/auditorias/ENTRENAMIENTO_AUDITORIA_FUNCIONAL.md`
  y aceptación/evidencia `docs/plans/TRAINING_EXPANSION_2026_10_17.md`.
- `workout_analytics.dart` conserva el motor único; sus partes
  `exercise_performance.dart` y `training_statistics.dart` derivan PRs, series
  comparables, períodos, rankings, calendario y grupos musculares.
- `WorkoutRepository.performanceIndex`: caché por cuenta/día/revisión.
  `workout_history_changes.dart` + `WorkoutHistoryMutationService`: correcciones,
  tombstones y recuperación de la proyección Home. No leer filas crudas para UI.
- `TrainingLibraryRepository`: notas permanentes/programas versionados en Hive
  por cuenta. `training_program.dart` conserva ocurrencias históricas; los programas
  referencian rutinas existentes. `training_examples.dart` usa IDs reales.
- `exercise_progress_panel.dart`, `workout_insights_screen.dart`,
  `training_programs_screen.dart`, `workout_history_editor_screen.dart` y
  `training_export_screen.dart`: entradas de la ampliación. Perfil reutiliza
  `WorkoutRecordsPanel` en su pestaña PRs existente.
- Unidades: `WorkoutPreferences` + `WorkoutUnitsHost` + `training_units.dart`.
  Guardar kg/metros; convertir sólo presentación y entrada. Compartir: snapshot
  `TrainingExportData` → PNG/preview → share_plus, sin envío automático.

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
- Buscar rutinas: `domain/routine_catalog.dart` define 12 propuestas offline por
  nivel; `training_home/routine_search_screen.dart` explora o busca las guardadas.
  `catalog_routine_detail_screen.dart` reutiliza el editor con borrador separado.
  Aceptación: `docs/plans/ROUTINE_CATALOG_2026_10_23.md`.
- Entrenamiento en Perfil: `presentation/workout_profile_summary.dart` consume el
  índice único. `MainShell` comunica la activación de Perfil; lecturas diferidas y
  PRs con filtros conservados. Evidencia: `TRAINING_PROFILE_REAL_DATA_2026_10_22.md`
  en `docs/plans/`, prueba `workout_profile_summary_test.dart` y goldens propios.
- Barra global/rutas: `features/workout/widgets/workout_mini_bar_host_overlay.dart`.
- Diseño: `docs/design/DESIGN_SYSTEM.md`; evidencia y defectos visuales: `docs/UX_AUDIT.md`.

## Plataforma y automatización

- Plataformas: `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- Dependencias: `pubspec.yaml` y `pubspec.lock`.
- Calidad: `.github/workflows/ci.yml`.
- GitHub Pages: `.github/workflows/pages.yml`.
- Actualizaciones: `.github/dependabot.yml`.
- Firebase: `firebase.json`, `.firebaserc` y `firestore.rules`; proxy USDA gratuito en `worker/`.


Nutrición B–H: `nutrition_workspace.dart` es un part del diario canónico
(metas/planes/notas/ayuno/edición/backup), no un import independiente.
`NutritionBackupService` coordina almacenes existentes. Nuevas rutas internas
reutilizan selector y editores; `nutrition_compare_screen`, `nutrition_text_screen`,
`nutrition_barcode_screen`, `nutrition_fasting_screen`. Fuente offline activa:
`assets/data/usda_foundation_2026_10.json`, generada por
`tools/build_verified_usda_catalog.py`. Estado y QA: `docs/nutrition/`.
