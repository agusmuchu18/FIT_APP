# Entrenamiento · auditoría funcional local

Fecha: 2026-10-17. Fuente de verdad: archivos locales en
`D:\Datos User\Escritorio\fitness\fit_app`, por indicación expresa del usuario.
No se sustituye la carpeta por GitHub. Base: `1f0340c` sobre
`codex/routine-inline-ux-20261014`; rama de ejecución:
`codex/training-expansion-20261017`. Commits anteriores: `e72d38f`, `2e274a3`,
`aa8a729`. Hay cambios previos ajenos en Perfil, nutrición y otros módulos que
deben preservarse. Línea base ejecutada: **195/195 tests, análisis estricto sin
problemas**; logs en `build/training_expansion_baseline_*.log`.

## Evidencia y límites

Se siguieron pantallas, controladores, modelos, repositorios y tests. “COMPLETA Y
FUNCIONAL” describe un recorrido existente comprobado en host; no certifica Android
ni iPhone. El usuario no dispone actualmente de Android ni Mac con Xcode.

La grabación recibida dura 222,17 s, 496×936, y muestra FIT_APP: Inicio, actividad
diaria, módulos, Perfil y apariencia. No demuestra interacciones de Hevy ni del
entrenamiento nuevo. Los fotogramas de inspección permanecen fuera del repositorio.
El prompt termina en `18.3 … No implementar componentes`; no se inventa el resto.

## Matriz a la entrada de la fase

Esta matriz conserva la auditoría previa, no es una lista de defectos aún abiertos.
El corte de implementación, las pruebas y los pendientes del 21/10 están en
`../plans/TRAINING_EXPANSION_2026_10_17.md`. No se cambia retrospectivamente la
evidencia inicial ni se confunde host/navegador con una ejecución móvil nativa.

Rutas respecto a `lib/features/workout/`; P/= `lib/features/profile/`.
P0=integridad/base; P1=recorrido principal; P2=ampliación.

| Funcionalidad | Estado actual | Archivos | Datos utilizados | Trabajo pendiente | Prioridad |
|---|---|---|---|---|---|
| Crear rutina/buscar/filtros/agregar inline | COMPLETA Y FUNCIONAL | `training_home/template_exercise_picker_screen.dart`, `exercise_configuration_sheet.dart` | 297 IDs verificados por test; valores por cuenta | Conservar estado e interacciones | P0 |
| Revisar/guardar/recuperar borrador | COMPLETA Y FUNCIONAL | `routine_draft_controller.dart`, `routine_review_screen.dart`, `routines_repository.dart` | Objetivos, instancias y propietario persistidos | Regresión al ampliar modelos | P0 |
| Biblioteca/carpetas/editar/duplicar/ordenar | COMPLETA Y FUNCIONAL | `training_home_controller.dart`, `routine_library_actions.dart` | Plantillas y metadata locales | Añadir programas sin alterar rutinas | P1 |
| Plantillas por objetivo/nivel/equipo | PARCIALMENTE IMPLEMENTADA | `routine_search_screen.dart` | Busca rutinas existentes, sin biblioteca editorial verificada | Plantillas explícitas y filtros | P2 |
| Programas/división semanal/progreso | NO IMPLEMENTADA | No existe entidad | Sin datos | Modelo, CRUD, semanas, calendario, ejecución | P2 |
| Iniciar rutina/entrenamiento libre | COMPLETA Y FUNCIONAL | `start_routine_flow.dart`, `workout_session_controller.dart` | Objetivos copiados, IDs nuevos, resultados no realizados | Respetar prioridad de sugerencias | P0 |
| Cronómetro/pausa/recuperación | COMPLETA Y FUNCIONAL | `workout_session_controller.dart`, `workout_in_progress_controller.dart` | Inicio, pausas e identidad persistidos | Mantener foco; móvil pendiente | P0 |
| Series compactas/expansión única | PARCIALMENTE IMPLEMENTADA | `presentation/widgets/set_row.dart`, `exercise_card.dart` | Campos completos siempre visibles | Compactar y controlar expansión | P1 |
| Heredar serie anterior | NO IMPLEMENTADA | `workout_session_controller.dart:addSet` | Serie nueva vacía | Copiar valores válidos, no realizado/ID/RPE/notas | P1 |
| Valores anteriores/autocompletar | PARCIALMENTE IMPLEMENTADA | `getPreviousSetsForExercise`, `_ensurePreviousForExercise` | Referencia previa por ID | Prioridad plan/sesión/historial y compatibilidad | P1 |
| Carga externa/corporal/lastre/asistencia/máquina | PARCIALMENTE IMPLEMENTADA | `session_models.dart`, `pro/models/workout_models.dart` | Campos separados; legado ambiguo marcado | Convención explícita de mancuernas/unilateralidad | P0 |
| Kg/lb/distancia | PARCIALMENTE IMPLEMENTADA | Modelos/preferencias/SetRow | Kg y tiempo; catálogo contiene distance | Presentación sin convertir datos originales | P1 |
| Volumen vivo e histórico | COMPLETA Y FUNCIONAL | `domain/workout_analytics.dart`, `workout_live_metrics.dart` | Misma fórmula de carga externa × reps | Extender convención sin duplicar cálculo | P0 |
| Duración total/sin pausas | COMPLETA Y FUNCIONAL | Controlador, repositorio, `WorkoutReport` | Segundos exactos o minutos legados; total opcional | No inferir tiempo trabajado ni restar estimaciones | P0 |
| Descansos acumulados históricos | NO IMPLEMENTADA | Sólo descanso activo | No hay traza final de cada descanso | Registrar sólo datos futuros si se añade esa métrica | P2 |
| Descanso contextual/+30/saltar | COMPLETA Y FUNCIONAL | Controlador, `rest_timer_banner.dart` | Un temporizador persistido con serie de origen | Regresión de pausa/recuperación | P0 |
| Editar descanso con teclado inline | PARCIALMENTE IMPLEMENTADA | `workout_rest_selector.dart` | ±15; valor abre modal | Sustituir modal por campo directo | P1 |
| Check/deshacer/persistir/progreso | COMPLETA Y FUNCIONAL | `updateSet`, borrador serializado | Valida resultados y guarda al completar | Facilitar próxima serie y detectar PR | P0 |
| Teclados/foco/incrementos/acción Listo | PARCIALMENTE IMPLEMENTADA | `set_row.dart` | Foco estable y teclado numérico | Seleccionar valor, siguiente campo e incrementos configurables | P1 |
| Notas de sesión | COMPLETA Y FUNCIONAL | `ExerciseInSession.notes`, `ExerciseCard` | Nota de esa sesión | Presentación compacta; separar niveles | P1 |
| Notas permanentes | NO IMPLEMENTADA | Sin almacenamiento dedicado | Sin datos | CRUD por cuenta/ID; mostrar al registrar | P1 |
| Agregar/eliminar serie/reordenar ejercicio | COMPLETA Y FUNCIONAL | Controlador y tarjetas | Borrador real | Duplicar/reemplazar/configurar y proteger resultados | P1 |
| Minimizar/overlay global | PARCIALMENTE IMPLEMENTADA | `widgets/workout_mini_bar_host_overlay.dart` | Overlay sobre Navigator | Auditar modales sin nombre y jerarquía | P0 |
| Finalizar/guardar/resumen/repetir | COMPLETA Y FUNCIONAL | `workout_completion_recovery.dart`, resumen/detalle/repeat | ID estable; proyección idempotente | Récords reales y exportación opt-in | P0 |
| Historial general/comparaciones | COMPLETA Y FUNCIONAL | `workout_history_screen.dart`, `WorkoutHistoryReport` | Ricos y legados; filtros locales | Año, calendario e informe mensual | P1 |
| Ficha desde nombre | PARCIALMENTE IMPLEMENTADA | `exercise_technical_screen.dart`, `exercise_technique.dart` | Seis notas orientativas y catálogo | Resumen/Historial/Técnica; no inventar técnica faltante | P1 |
| Imágenes/fallback/manifiesto | PARCIALMENTE IMPLEMENTADA | `exercise_thumbnail.dart`, manifiesto | Seis específicos, resto genérico explícito | Mantener cobertura honesta | P2 |
| Demostraciones animadas revisadas | NO IMPLEMENTADA | Sin recurso validado | Ilustración estática | Soporte de recurso futuro; no inventar biomecánica | P2 |
| Historial por ejercicio/comparar sesiones | NO IMPLEMENTADA | Sólo referencias previas/detalle general | Historial con IDs estables | Índice, paginación y enlace al detalle existente | P1 |
| Gráficos individuales/tabla/períodos | NO IMPLEMENTADA | `fl_chart` ya disponible | Registros reales sin agregar por ejercicio | Métricas aplicables y selección exacta | P1 |
| Motor de PRs/1RM/récords por reps | NO IMPLEMENTADA | No existe motor | Series reales disponibles | Derivar marcas con procedencia y semántica comparable | P0 |
| PRs existentes en Perfil | SOLO VISUAL | `P/profile_social_screen.dart:_prs`, `_PRsTab`; `P/widgets/profile_social_widgets.dart:ProfilePRCard` | Tres marcas constantes de 140/105/180 kg | Reusar pestaña/tarjeta con motor real, preservando otros cambios | P0 |
| Radar/distribución muscular | PARCIALMENTE IMPLEMENTADA | `WorkoutAnalytics.muscleDistribution`, `WorkoutMuscleReport`, radar vivo | Series válidas repartidas entre seis grupos primarios | Directas/secundarias, períodos, comparación y detalle | P1 |
| Mapa anatómico anterior/posterior | NO IMPLEMENTADA | Las ilustraciones de filtro no son mapa interactivo | Clasificación del catálogo | Regiones vectoriales y selección con datos reales | P1 |
| Dashboard/tendencias/ejercicios frecuentes | PARCIALMENTE IMPLEMENTADA | Historial/widgets de informes | Sesiones, tiempo, volumen y barras semanales | Ampliar historial, métricas, comparación y tabla | P1 |
| Informe mensual/detalles/exportación | NO IMPLEMENTADA | Agregados parcialmente reutilizables | Registros por fecha | Mes calendario y comparación válida; datos elegidos | P1 |
| Calendario específico de entrenamiento | NO IMPLEMENTADA | Home usa `ActivityCalendarSheet` / `TableCalendar` | Calendario global existente | Reusar biblioteca/vocabulario; sesiones del día y planes distintos | P1 |
| Compartir resumen/PR/progreso | NO IMPLEMENTADA | Sin flujo específico | Datos locales | Preview, consentimiento y archivo; sin publicación automática | P2 |
| Editar/borrar historia e invalidar | PARCIALMENTE IMPLEMENTADA | Repositorio hace upsert; detalle sólo consulta | Filas ricas/legadas | Revisión de caché y coherencia con proyección | P0 |
| Offline/separación de cuentas | COMPLETA Y FUNCIONAL | `AccountStorageScope`, `ScopedPreferences`, Hive | Dueño capturado; invitado separado | Extender a notas/programas/cachés | P0 |
| Temas reales de entrenamiento | PARCIALMENTE IMPLEMENTADA | `AppTheme.workout`, wrappers | Fuerza oscuro; app ofrece claro/clásico/rosa | Respetar tema disponible, sin colores nuevos arbitrarios | P1 |
| Accesibilidad/320/200%/reduced motion | PARCIALMENTE IMPLEMENTADA | Tests inline, informes/goldens | Fixtures host | Ampliar matriz; lectores nativos NO VERIFICADOS | P1 |
| 1/50/500 sesiones, miles de series | NO VERIFICADA | Listas lazy; caché incompleta | Sólo ensayo actual de 500 rutinas | Medir escenarios e invalidación; no inventar benchmarks | P1 |
| Android/iPhone/tienda | NO VERIFICADA | Plataformas existentes | APK anterior; sin dispositivo/Mac | Ejecución, release/signing, perfilado | P2 |

## Referencia y decisiones

Las fuentes oficiales describen historial, gráficos, récords, distribución
muscular y estadísticas; no prueban cada gesto del inventario. Los gestos no
verificados se diseñarán como decisiones FIT_APP de mínima fricción. No se copian
pantallas ni imágenes ni se construye red social o suscripciones.

- [Rendimiento por ejercicio](https://www.hevyapp.com/features/exercise-performance/).
- [Estadísticas](https://www.hevyapp.com/features/gym-performance/).
- [Explicación de 1RM estimada](https://help.hevyapp.com/hc/en-us/articles/36954464726167-Understanding-Your-Estimated-One-Rep-Max-1RM-in-Hevy).
- [Estudio primario de predicción desde 5/10/20 repeticiones](https://pubmed.ncbi.nlm.nih.gov/16937972/).
- [Estudio primario que contrasta ecuaciones](https://pmc.ncbi.nlm.nih.gov/articles/PMC11435939/).

## Ejecución acordada

1. Extender `WorkoutAnalytics`, sin otro motor de volumen: observaciones, PRs y
   grupos de carga compatibles; separar objetivos/resultados y duración medida.
2. Revisión por cuenta en `WorkoutRepository` para invalidar ficha, historial,
   Perfil y resumen; no recalcular todo en cada rebuild.
3. JSON versionado por cuenta para notas y programas; no alterar rutinas al editar
   programas ni completar automáticamente lo planificado.
4. Consolidar registro/descanso; luego ficha/PRs/análisis, dashboard/calendario/
   informes, programas/biblioteca y exportación local con privacidad.
5. Pruebas por entrega, suite/análisis/build al cierre y evidencia visual. Las
   limitaciones nativas permanecen explícitas, sin declarar 100% de tienda.
