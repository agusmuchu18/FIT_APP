# Data model

Este documento registra relaciones y persistencia; el código fuente sigue siendo
la definición exacta de campos y JSON.

## Entidades centrales sincronizables

Definidas en `lib/core/domain/entities.dart`:

| Entidad | Uso | Local | Remoto |
|---|---|---|---|
| `WorkoutEntry` | Entrenamiento consolidado | Hive `fit_workouts` | `users/{uid}/workouts` |
| `MealEntry` + `Macros` | Registro nutricional consolidado | Hive `fit_meals` | `users/{uid}/meals` |
| `SleepEntry` | Registro de sueño | Hive `fit_sleep` | `users/{uid}/sleep` |
| `UserPreferences` | Preferencias sincronizables | Hive `fit_prefs` | `users/{uid}/preferences` |

Implementan `SyncEntity` y usan metadata de identidad, actualización y borrado
lógico para sincronización. Los documentos se serializan a JSON.

## Modelos por feature

### Nutrición

`lib/features/nutrition/domain/models.dart`:

```text
FoodItem + MacroValues
  -> DraftEntry
  -> MealDraft
  -> LoggedMeal

TemplateFolder -> MealTemplate -> TemplateItem
```

`MealType` clasifica desayuno, almuerzo, colación, cena y supper; `FoodUnit`
modela porción, gramos y mililitros. Desde Nutrition 2.0 A (30/10), el diario
canónico `fit_nutrition_journal_v2[_scope]` conserva UUID, fecha/offset,
entradas/snapshots, origen y proyección pendiente; migra preferencias v1 sin
borrarlas. `MealEntry.consumedAt` y `nutritionSnapshot` son extensiones opcionales
de la proyección central, que conserva sus campos/IDs anteriores. Plantillas y
alimentos propios usan preferencias por cuenta. Reglas y compatibilidad:
`nutrition/ARCHITECTURE.md`.

### Entrenamientos

`lib/features/workout/pro/models/workout_models.dart`:

```text
RoutineFolder -> WorkoutTemplate -> WorkoutExercise -> SetEntry
WorkoutSession -> ejercicios/series ejecutados
```

`WorkoutType` distingue fuerza, cardio, funcional, deporte y personalizado. La
sesión activa usa además `ExerciseInSession`, `SetInSession` y `PreviousSet` de
`features/workout/domain/session_models.dart`. Rutinas e historial usan
`RoutinesRepository` y `WorkoutRepository`, con almacenamiento local propio.
Las sesiones ricas v2 se escriben en Hive `fit_workout_sessions`; al abrir la caja,
`WorkoutRepository` copia registros válidos de `workout_in_progress_v2_sessions`
por ID sin borrar la lista antigua. El borrador v2 permanece en preferencias y
guarda identidad, pausa y descanso activo. Al terminar, el mismo ID se proyecta
a `WorkoutEntry` en `fit_workouts` para Home y Rachas. Estas dos escrituras no
forman una transacción; desde 2026-10-01 se reconcilian idempotentemente al
arrancar. `completionPending` identifica el borrador que sólo se puede limpiar
cuando su sesión rica y proyección ya se guardaron. `durationSeconds`,
`targetDurationSeconds`, `assistanceKg`, `isTimed`, `isAssisted` y `workoutType`
son campos opcionales compatibles con formatos anteriores.
`SetEntry.done` distingue series ejecutadas de planificadas en sesiones v2;
en registros legados es nulo y se muestran como series registradas. El descanso
predeterminado para ejercicios nuevos se guarda en `workout_preferences_v1`.

Desde el corte de rutinas del 13/10/2026, la plantilla JSON v2 añade notas y
modalidad opcionales. `WorkoutExercise` distingue instancias, `RoutineSetTarget`,
`SportActivityPlan` y `SportMeasurements` realizado; no se reemplazan los IDs del
catálogo. El borrador único `workout_routine_draft_v2` usa el namespace por cuenta
y un sufijo independiente para edición. Campos/versiones/errores/migración y
recorrido de copia inmutable están documentados en
`plans/ROUTINE_SYSTEM_2026_10_12.md`, sección 4. No se reescribe historial al leer.

#### Registro corporal adaptativo

Registro corporal (25/10): `SetEntry`/`SetInSession` incorporan `loadType?`;
el borrador distingue predeterminado del ejercicio y override por serie.
`RoutineSetTarget.assistanceKg` y `WorkoutExercise.targetAssistanceKg` separan
asistencia de lastre; `loadSchemaVersion` 0 lee la representación antigua y 1
usa campos separados. Masa corporal queda como snapshot; no es carga externa.
No se reescriben sesiones/IDs ni se reinterpretan kg ambiguos. La conversión de
borradores Pro guarda el original en `workout_legacy_draft_sources_v1`, por cuenta.
Detalle y fórmulas: `plans/BODYWEIGHT_ADAPTIVE_REGISTRATION.md`.

### Hábitos

`HabitEntry` contiene la definición y programación; `HabitDailyLog` registra
progreso diario y `HabitStreak` resume rachas. `HabitTemplate` y
`HabitCreationConfig` alimentan la galería y creación. El tracker y la
popularidad guardan estado local.

### Grupos y perfil

`Group` contiene `GroupMember`, que puede exponer `GroupMemberMetrics`. El
servicio actual no constituye todavía un backend colaborativo completo. El
perfil conserva parte de su estado en un controlador singleton.

## Almacenamiento auxiliar

| Almacén | Contenido |
|---|---|
| Hive `sync_queue` | `SyncTask` pendientes de push/reintento. |
| `SharedPreferences` / `AppPreferences` | Apariencia, recordatorios, accesibilidad, privacidad y estado de integraciones. |
| Preferencias de features | Rutinas, sesión activa, hábitos, plantillas y registros nutricionales específicos. |
| Asset `assets/data/usda_foundation_2026_04.json` | 363 alimentos Foundation oficiales válidos, disponibles offline. |
| Memoria | Caché temporal USDA, servicios/grupos y estado efímero de pantallas. |

## Invariantes y riesgos

- Entrenamiento: nombres originales conservados en invitado; cuentas usan
  `account:<namespace>:<clave>` en preferencias y sufijo de namespace en Hive.
  Cada repositorio conserva su dueño aunque termine después de un logout.
- Las cajas centrales y `sync_queue` siguen ese namespace; sus nombres originales
  permanecen como invitado. No se reasignan automáticamente registros/colas
  anteriores cuyo propietario no se conoce.
- El usuario eligió mantener invitado separado. No hay conversión automática.

- Mantener IDs estables y serializadores retrocompatibles al cambiar modelos.
- No eliminar campos persistidos sin una migración y prueba de datos anteriores.
- Distinguir modelos UI/borrador de entidades sincronizables.
- Las preferencias y singletons de otros features requieren auditoría separada;
  no deducir aislamiento global a partir de Entrenamiento.

### Alimentación local

- `nutrition.custom_foods.v1`: lista JSON de `FoodItem` creados por el usuario.
- `nutrition.usda_foods.v1`: hasta 500 detalles USDA consultados, reutilizables sin red.
- `nutrition.day_logs.v1`: comidas por fecha; los registros nuevos incluyen
  macros, tipo, fecha y `DraftEntry` completos para “Copiar último”.
- `FoodItem` y `DraftEntry` tienen JSON retrocompatible; logs antiguos sin entries
  siguen aportando al resumen, pero no pueden reconstruirse para copiar.
- La escritura se confirma antes de vaciar el borrador. Estos nombres siguen bajo
  la contención global de cuenta, no bajo namespaces uid.


### Nutrición B–H · compatibilidad

MacroValues contiene double?; JSON conserva null y cero por separado.
DraftEntry.quantity/gramsOverride y FoodItem.defaultServingGrams son num.
La procedencia del alimento incluye fuente/ID/fecha/método/unidad/notas.
MealTemplate añade raciones, preparación y peso final opcional sin duplicar modelos.
NutritionMetrics.unknownNutrients acompaña enteros legacy. Box v2 acepta schema3,
metadatos `__goal`, `__goalRevision`, `__plan`, `__note`, `__fast`; los planes son
snapshots independientes del consumo. Confirmación: `nutrition-plan:<id>`.
La copia JSON versionada es aditiva y privada; detalles en nutrition/ARCHITECTURE.
