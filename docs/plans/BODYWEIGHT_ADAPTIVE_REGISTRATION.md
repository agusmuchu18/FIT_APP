# Registro adaptativo de peso corporal

Fecha: 2026-10-24; cierre verificado el 2026-10-25.
Repositorio local: `D:\Datos User\Escritorio\fitness\fit_app`.
Estado: implementado y probado en host/navegador; validación móvil real pendiente.

## Alcance y auditoría previa

Se amplió Entrenamiento, conservando navegación, repositorios, IDs, preferencias
por cuenta, registro compacto, expansión inline y motor estadístico existentes.
No se agregaron dependencias ni sistemas paralelos.

| Área inspeccionada | Hallazgo | Corrección |
|---|---|---|
| Catálogo `ExerciseDefinition` | `bodyweightPlusExternal` expresa capacidad de lastre; no prueba que se haya usado | Clasificación por metadatos, sin inferir por nombre o número de kg |
| `RoutineExerciseLoadType` | Ya representa corporal, externa, lastre y asistencia | Se reutiliza el enum existente |
| Borrador `SetInSession` | Modalidad global; kg podía aparecer en todas las series | Modalidad explícita opcional por serie y predeterminado del ejercicio |
| `SetEntry` histórico | Kg antiguos ambiguos, asistencia y masa corporal coexistían | Conservación del valor; modalidad desconocida excluida de cálculos de carga |
| Sesión | Cambiar tipo podía vaciar cargas o afectar todas las series | Cachés independientes; series completadas y overrides no se modifican por el predeterminado |
| Rutinas | Campo genérico para asistencia y eliminación de carga al elegir corporal | Campos separados, compatibilidad versionada y edición inline |
| Historial/autocompletado | Comparación por modalidad global | Selección compatible por modalidad; aplicación del anterior voluntaria |
| Estadísticas/PR | Faltaba contexto del ejercicio/serie en parte de los cálculos | Motor existente con clasificación por serie y asistencia cuantificada |
| Borrador Pro antiguo | Conversión podía omitir kg ambiguos | Preserva el número, metadatos corporales y copia exacta del JSON de origen |
| Catálogo | No tenía una sentadilla corporal básica explícita | Se agrega `bodyweight_squat`; ningún ID previo se cambia (298 ejercicios) |

## Comportamiento

- Dominadas, flexiones, fondos y sentadilla corporal: repeticiones, sin kg por
  defecto. Plancha: tiempo, sin kg por defecto.
- «Añadir lastre o asistencia» despliega opciones en la misma tarjeta. No abre
  un modal. Las opciones también existen en los detalles inline de cada serie.
- Las modalidades son «Solo peso corporal», «Con lastre» y «Con asistencia».
- Cada serie conserva su modalidad. El predeterminado solo cambia series
  pendientes que no tienen una elección individual. No cambia series terminadas.
- Cambiar modalidad conserva los borradores numéricos de lastre y asistencia;
  el valor inactivo no se muestra ni se contabiliza como carga activa.
- En tablas mixtas, `+` identifica lastre y `−` asistencia; el segundo es una
  marca de modalidad, no volumen negativo. Las etiquetas semánticas y los detalles
  inline nombran explícitamente cada modalidad.
- Lastre y asistencia requieren su valor activo para completar la serie.
- Añadir serie hereda reps/tiempo y solo la carga compatible con el predeterminado.
- El último resultado se muestra con su modalidad. Una sesión libre nueva no
  activa lastre porque exista en el historial. Tocar «Anterior» permite aplicarlo
  voluntariamente a esa serie. Un resultado antiguo ambiguo solo aporta reps/tiempo.
- Los objetivos de rutina pueden definir modalidades distintas por serie.
- Se conserva completar con un toque, autocompletado y descanso automático.
  Si una edición explícita invalida una serie terminada, se desmarca y se cancela
  el descanso originado por ella.
- Repetir una sesión es una acción explícita: conserva las modalidades conocidas,
  crea nuevos IDs para la nueva sesión y no modifica el original.

## Datos y compatibilidad

No hay migración masiva de sesiones o rutinas guardadas, borrado de bases ni
renumeración de IDs. Los campos nuevos son compatibles con JSON anterior:

| Modelo existente | Extensión |
|---|---|
| `RoutineSetTarget` | `loadType?`, `assistanceKg?`; `weightKg` sigue almacenando externa/lastre |
| `WorkoutExercise` | `targetAssistanceKg?`, `loadSchemaVersion` |
| `SetEntry` | `loadType?`; conserva `externalLoadKg`, `assistanceKg`, `bodyweightKg`, `bodyweightFactor` y `loadIsAmbiguous` |
| `SetInSession` | `loadType?`, `loadTypeOverride`, `loadIsAmbiguous`, snapshots corporales opcionales |
| `ExerciseInSession` | `isBodyweight`, `defaultLoadType?` |
| `PreviousSet` | Modalidad y marca de ambigüedad |

`loadSchemaVersion=0` identifica los planes anteriores, donde una asistencia
explícita podía guardarse en `targetWeightKg`. El lector conserva esa
compatibilidad. Las nuevas ediciones escriben versión 1 con asistencia separada;
un lastre inactivo jamás se interpreta como asistencia en esta versión.
Los objetivos antiguos sin modalidad pueden utilizar su tipo global explícito.

La mera capacidad de lastre del catálogo no transforma pesos históricos en lastre.
En un ejercicio corporal, kg positivos sin evidencia de modalidad permanecen
«Carga antigua sin clasificar». Se muestran y se conservan; no generan récords
de carga, estimaciones ni volumen externo.

La conversión ya existente de borradores Pro conserva además el JSON exacto
antes de retirar la clave antigua, en `workout_legacy_draft_sources_v1`, dentro
del ámbito de la cuenta/invitado. Es idempotente y las escrituras se verifican
mediante `ScopedPreferences`. No es un duplicado editable del historial.

## Fórmulas y comparabilidad

Se contabilizan series registradas válidas; calentamientos quedan excluidos de
volumen, récords y atribución muscular según las reglas existentes.

| Modalidad | Volumen externo por serie | Récords |
|---|---|---|
| Solo peso corporal | 0 kg·rep | Repeticiones o duración |
| Con lastre | kg adicionales × reps | Carga adicional, reps, volumen; sin 1RM corporal |
| Con asistencia | 0 kg·rep | Reps/tiempo, separados por cantidad de asistencia |
| Externa/máquina | kg externos × reps | Motor existente de carga/reps/volumen/1RM elegible |
| Ambigua | 0 kg·rep | No genera PRs de modalidad desconocida |

`bodyweightKg` y `bodyweightFactor` son snapshots preservados, no cargas externas.
No se estima masa corporal desde kg, ni fuerza efectiva desde asistencia.
No se suma el peso de la persona a dominadas o flexiones. No se considera
asistencia como peso levantado ni se resta para inventar una carga efectiva.
Las isometrías no producen volumen kg·rep por su duración.

Se multiplica por implementos únicamente con convención explícita
`perImplement` y cantidad válida; las convenciones antiguas registradas no se
reinterpretan. El índice separa modalidad, equipo, convención y cantidad de
asistencia. La etiqueta visible identifica esta última para evitar gráficos
indistinguibles. Epley sigue limitado al alcance previo de resistencia externa
elegible; no se aplica a corporal, lastre ni asistencia.

## Archivos de implementación

Las rutas siguientes son relativas a la raíz verificada del repositorio.

- Nuevos: `lib/features/workout/domain/exercise_load_policy.dart` y
  `lib/features/workout/presentation/widgets/bodyweight_mode_selector.dart`.
- Modelos: `pro/models/workout_models.dart`, `domain/session_models.dart`.
- Aplicación: `application/workout_session_controller.dart`,
  `legacy_draft_migration.dart`, `workout_repeat_service.dart`,
  `routine_update_from_session.dart`.
- Datos: `data/workout_repository.dart`, `pro/data/exercise_library.dart`.
- Cálculos: `domain/workout_analytics.dart`, `exercise_performance.dart`,
  `routine_labels.dart`, `routine_plan_validation.dart`.
- Sesión: `presentation/workout_in_progress_screen.dart`,
  `widgets/exercise_card.dart`, `set_row.dart`, `workout_report_widgets.dart`.
- Edición histórica: `presentation/workout_history_editor_screen.dart` usa la
  modalidad de cada serie, conserva cargas inactivas y exige confirmación
  explícita para clasificar una carga marcada como ambigua.
- Rutinas/ficha: `training_home/exercise_configuration_sheet.dart`,
  `routine_preview_screen.dart`, `exercise_technical_screen.dart`,
  `exercise_progress_panel.dart`.

Todas las rutas cortas de esta lista pertenecen a `lib/features/workout/`.
`exercise_performance.dart` sigue siendo `part` de `workout_analytics.dart`;
los consumidores importan la biblioteca principal, corrigiendo el error de
compilación comunicado previamente sin eliminar su declaración `part of`.

## Pruebas de aceptación

`test/features/workout/bodyweight_adaptive_test.dart`: 19 casos de modelo,
controlador, persistencia, compatibilidad, cálculos y PRs.
`test/goldens/bodyweight_registration_golden_test.dart`: 7 casos de pantalla
real con preferencias de prueba, 4 capturas golden (sin conexión de producción).
Los tests de catálogo y repetición existentes comprueban ahora los 298 IDs y
la conservación explícita del peso ambiguo, en lugar de exigir su omisión.
`test/features/workout/workout_history_editor_ui_test.dart` añade un caso de
edición mixta con persistencia real del repositorio y proyección simulada: cambiar
asistencia 20→30 kg conserva cargas externas inactivas, modalidades, IDs y 80 kg·rep.

| Requisito solicitado | Comprobación |
|---|---|
| 1/2 Dominadas y flexiones normales | Tests de cada catálogo, UI sin campo de carga |
| 3 Plancha | Tiempo + captura tema claro |
| 4 Lastre | Kg adicionales obligatorios, volumen 10×8=80, descanso |
| 5 Asistencia | Campo independiente; volumen 0 |
| 6 Series mixtas | Persistencia/IDs + UI inline con serie completada intacta |
| 7 Herencia compatible | Carga solo de modalidad compatible al añadir serie |
| 8 Completar con un toque | Resultado actual/anterior/objetivos; duración y reps |
| 9 Último resultado | No activa lastre en sesión libre; aplicación voluntaria |
| 10 Objetivos de rutina | Targets mixtos y ronda de serialización |
| 11 Cambiar sin pérdida | Conservación separada de lastre y asistencia; UI del creador |
| 12 Series completadas | Cambio global conserva JSON; cambio individual inválido cancela descanso |
| 13 Rutinas antiguas | Asistencia v0, cachés v1 y regresiones del creador |
| 14 Historial ambiguo | Valor visible/intacto, backup del borrador, sin PR/volumen |
| 15 Volumen/PRs | Masa corporal excluida, modalidades separadas, niveles de asistencia y calentamientos |
| 16 Temas/tamaños | Oscuro, claro, 390 px y 320 px con texto 200 % y movimiento reducido |

## Validación final

| Control ejecutado sobre el código final | Resultado |
|---|---|
| Formato del cambio | 29 archivos Dart comprobados, 0 cambios pendientes |
| `flutter analyze --fatal-infos` | Sin incidencias |
| `flutter test --no-pub --reporter expanded` | 372 aprobadas + 1 omitida |
| Nuevas regresiones específicas | 19 de dominio/controlador + 8 de UI; todas aprobadas |
| Goldens | 4 capturas nuevas revisadas; suite completa ejecutada sin `--update-goldens` |
| `flutter build web --release --no-pub` | Aprobado, incluido dry run Wasm |
| `flutter build apk --debug --no-pub` | Aprobado; APK debug, no preparado para publicación |
| Navegador integrado, 390×844, invitado | Registro, mezcla, restauración, finalización e historial verificados |

La prueba omitida pertenece al contrato social que requiere emuladores Firebase,
ajeno a este cambio; no es una omisión de peso corporal. No se presenta como
ejecutada en esta etapa. Logs de suite/análisis: `build/bodyweight_final_tests.log`
y `build/bodyweight_analyze.log`.

Datos del recorrido: origen local aislado `http://127.0.0.1:61248`, preferencias/Hive
reales de invitado, valores de prueba introducidos exclusivamente desde la UI.
Dominadas: serie corporal de 10 reps, lastre 10 kg × 8 reps, asistencia 20 kg ×
12 reps. Resultado: 3/3 series, 30 repeticiones, 80 kg·rep. Tras recargar el build
y reanudar, las modalidades/valores siguieron intactos. Se guardó la sesión y
el detalle histórico mostró «Peso corporal», «10 kg de lastre» y «20 kg de
asistencia». No se utilizaron cuentas, datos privados ni servicios de producción.
El recorrido no demuestra funcionamiento en dispositivo físico.

Evidencia conservada: [detalle histórico en navegador](../evidence/bodyweight-2026-10-25/history.png).
Las cuatro referencias de pantalla controlada están en
`test/goldens/bodyweight_{default,mixed_inline,timed_light,accessible}.png`.

La revisión posterior encontró y corrigió: descanso de una serie invalidada;
asistencia moderna sin valor que podía heredar un lastre inactivo al reabrir
objetivos individuales; sugerencias de reps mezcladas entre niveles de asistencia;
consulta sin series y recorte de chips con texto 200 %. Se añadieron regresiones
y se repitieron los checks finales. No se desactivaron diagnósticos ni tests.
También se corrigió el editor de historial, que aún utilizaba el tipo global
para elegir entre carga y asistencia. Ahora usa el modo individual y oculta kg
en las series corporales normales, sin sustituir el flujo de corrección existente.

## Límites y continuidad

- No hay Android conectado ni Mac/Xcode/iPhone disponibles en esta sesión.
  Una compilación APK no sustituye una prueba en dispositivo ni una validación
  de App Store. iOS requiere compilación y recorrido en su entorno real.
- Android compila con avisos previos de mantenimiento: Gradle 8.14.0, AGP 8.12.1,
  Kotlin 2.2.20 y versiones de herramientas SDK. No impiden este build; su
  actualización coordinada queda fuera del cambio funcional corporal.
- No se afirma mejora de rendimiento medida en profile; no se añadió dependencia,
  motor duplicado ni carga masiva de historial por cada render.
- Los kg históricos ambiguos siguen sin clasificarse automáticamente. Cualquier
  clasificación futura debe ser una decisión explícita y conservar el original.
- El árbol local ya contenía cambios de otros trabajos. Se conserva una copia
  previa de los 135 archivos Dart de Entrenamiento/pruebas en el workspace de
  Codex para delimitar este cambio. No se hizo push ni despliegue.
- No se creó un commit de este corte: sus archivos comparten cambios previos
  del usuario. La comparación contra la copia previa delimita esta implementación;
  no se preparó un commit mezclando todo el árbol local.
