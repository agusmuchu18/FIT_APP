# Expansión profesional de Entrenamiento · ejecución

Fuente de verdad: archivos locales; GitHub no refleja este estado. Rama:
`codex/training-expansion-20261017`, base `1f0340c` con trabajo ajeno pendiente.
Auditoría inicial y contratos: `../auditorias/ENTRENAMIENTO_AUDITORIA_FUNCIONAL.md`.
No hacer push, publicar ni cambiar la navegación principal.

## Entregas y aceptación

- [x] 0. Auditoría previa: código, persistencia, referencia, Git; baseline 195/195 y análisis limpio.
- [x] 1. Extender el motor existente de métricas: convenciones de carga explícitas,
  observaciones/indexación, récords con procedencia y e1RM acotada. Aceptar sólo si
  vivo/guardado coinciden, legado no se duplica y asistencia/corporal/lastre no compiten.
- [x] 2. Series compactas y expansión única, herencia válida, sugerencias con prioridad,
  descanso inline, foco/incrementos/unidades, duplicar/reemplazar y overlay protegido.
  Comprobar guardado, pausa, retorno y cierre idempotente desde UI.
- [x] 3–6. Ficha Resumen/Historial/Técnica con gráficos/tabla exacta, períodos,
  comparaciones, PRs/reps y notas permanentes; integrar pestaña PRs existente en Perfil.
  Probar CRUD por cuenta, ausencia de historial y enlace a sesión. Sin técnica ficticia.
- [x] 7. Series directas/secundarias, períodos/comparación, radar reutilizado y mapa
  vectorial anterior/posterior con detalle por región. No inferir hipertrofia/recuperación.
- [x] 8–10. Dashboard, informes mensuales y calendario dentro de Entrenamiento;
  reutilizar fl_chart/TableCalendar. Distinguir ausencias, descanso planificado y realizado.
  Cada valor debe tener fórmula y acceso a registros; comparación sin división por cero.
- [x] 11–13. Programas por semanas/días, edición, copia, rutinas referenciadas,
  descanso explícito, calendario y progreso derivado; plantillas de ejemplo identificadas.
  No alterar rutinas al modificar programas ni completar objetivos como resultados.
- [x] 14–15. Resumen con récords reales y exportación visual opcional de sesión,
  informe, PR y evolución. Preview con campos elegidos, notas privadas excluidas por defecto.
- [x] 16. Persistencia versionada, revisión/invalidación y recuperación; separación
  de cuentas y legado preservado. Cambios de historial deben invalidar todo lo derivado.
- [x] 17. Ensayos de 1/50/500 sesiones y miles de series; listas lazy y cache por
  dueño/revisión. Informar mediciones host como tales, nunca como benchmarks de teléfono.
- [ ] 18. Español, unidades sin reescribir originales, temas disponibles, 320/200%,
  teclado, semántica y reducción de movimiento. Capturar/revisar fixtures antes de cerrar.
- [x] Cierre: revisión acotada, suite, análisis estricto, builds pertinentes y commits
  locales sólo del alcance; documentar lo no verificado en Android/iPhone.

## Evidencia durante la ejecución

Primer bloque de dominio (evidencia intermedia): 18 pruebas focalizadas aprobadas (9 nuevas + regresiones
de métricas, volumen vivo y migración). Ensayo ejecutado: 500 sesiones / 10.000 series,
63.707 microsegundos en host en esa ejecución; no se establece garantía temporal.
`build/training_expansion_metrics_tests.log`. No se certifica todavía la entrega
completa ni se sustituyen los resultados finales por esta prueba parcial.

Modelo: `LoadConvention.recorded` mantiene la carga histórica literal. Sólo
`perImplement` más cantidad explícita habilita multiplicación en volumen.
Los PRs estrictos requieren series válidas con `done=true`; los registros legados
sin esa marca siguen visibles como registrados, pero no certifican récords.
1RM estimada usa Epley, 1–10 reps, resistencia externa aplicable, sin reserva conocida,
sin extrapolar lastre/asistencia/corporal/tiempo/distancia. Se diferencia de carga real.


## Corte de entrega local · 21/10/2026

El cierre anterior corresponde al código y a las comprobaciones locales. No
equivale a certificación de tienda ni a ejecución en Android/iPhone. El punto 18
permanece parcialmente abierto por la conexión global de apariencia y las
comprobaciones nativas indicadas debajo.

| Recorrido | Implementación y comprobación reproducible |
|---|---|
| Cálculos | Mismo WorkoutAnalytics para vivo/guardado. LoadConvention aditiva, conteo explícito por implemento, asistencia/corporal/lastre separados; desconocido no se multiplica. TrainingPerformanceIndex conserva procedencia, repeticiones realmente observadas y estimación Epley acotada a 1–10 reps aplicables. `training_performance_index_test.dart`, `workout_live_metrics_test.dart` y regresiones de migración. |
| Registro | Filas compactas, una expansión de serie, nuevos IDs y resultados pendientes al duplicar. Herencia sin RIR/nota/fecha; sugerencias tardías respetan objetivos, edición y borrados explícitos. Cambiar modalidad de carga limpia sólo series pendientes; reemplazar con resultados pide confirmación. `training_session_expansion_test.dart`, `workout_set_editing_test.dart`, `workout_session_functional_test.dart`. |
| Descanso/overlay | Edición inline de segundos o m:ss, ±15 y validación; temporizador existente conservado. Barra oculta en modales/formularios/teclado, espacio final en biblioteca y movimiento reducido. `workout_rest_selector_test.dart`, `workout_mini_bar_host_overlay_test.dart` y ensayo de sesión. |
| Ficha y PRs | Resumen/Historial/Técnica con imagen existente, notas permanentes privadas, períodos, variantes de carga, métricas aplicables, gráfico fechado y tabla paginada; máx. 120 muestras dibujadas sin eliminar la tabla. PRs por repetición sin interpolación, enlaces a sesión. La pestaña PRs existente de Perfil consume el mismo índice. `training_expansion_ui_test.dart` y goldens de ficha. |
| Músculos | Series directas/secundarias separadas, días/ejercicios de origen, comparación y radar existente; mapa vectorial anterior/posterior más lista accesible. Grupos amplios del catálogo siguen amplios. No representa activación, hipertrofia, fatiga ni recuperación. `training_statistics_test.dart` y capturas de mapa. |
| Dashboard/calendario/informes | Cálculos por período/cambio de datos; ranking y acceso al origen, meses calendario y mes actual parcial, porcentaje sin base anterior explícito. Calendario diferencia historial filtrado, sesiones previstas y descansos de programas activos; no convierte ausencia en descanso. `training_expansion_ui_test.dart`, `training_units_and_calendar_test.dart`. |
| Programas | CRUD versionado por cuenta, inicio en lunes, semanas/días, edición, copia/eliminación de semana, orden visual dentro de semana y descanso explícito. Rutinas referenciadas, no modificadas. Ocurrencia programada conserva identidad al reanudar/guardar; adherencia y siguiente pendiente desde resultados confirmados, no objetivos. Rutina eliminada se muestra como no disponible. `training_library_repository_test.dart`, `training_program_and_export_ui_test.dart`, `training_session_expansion_test.dart`. |
| Ejemplos | Dos estructuras de rutina con IDs/equipamiento del catálogo; programa editable de cuatro semanas y tres/cuatro días. Preview en creador existente con borrador temporal aislado: cancelar no pisa el borrador personal; guardar crea copia del usuario. Sin pesos ni resultados inventados. `training_program_and_export_ui_test.dart`. |
| Historial | Corrección de nombre/notas/duración, cargas/reps/tiempo/distancia/finalización y mediciones deportivas. Validación de raw inválido, objetivos separados, control de revisión y recuperación de la proyección Home. Overlay versionado y tombstones preservan las filas originales, evitan resurrección y recalculan PRs/calendario/resumen. `workout_history_changes_test.dart`, `workout_history_editor_ui_test.dart`. |
| Resumen/exportación | Sólo sesiones guardadas por ID, marcas logradas en esa sesión diferenciadas de récord vigente. Tarjetas de sesión/mes/PR/evolución con preview, campos elegidos y PNG real de 1080 px. Notas privadas excluidas por defecto; sin envío automático. share_plus 13.3.1; prueba de bytes PNG, ancho decodificado y destino simulado. `training_program_and_export_ui_test.dart`. |
| Unidades | Preferencias por cuenta/invitado, kg/lb y m/km/mi, incremento configurable, conversión en entrada, objetivos, vivo, ficha, historial, gráficos y exportación. Almacenamiento y fórmulas permanecen en kg/metros. Se conservan campos desconocidos y se rechaza sobrescribir versiones futuras. `training_units_and_calendar_test.dart`. |
| Aislamiento | Hive y preferencias existentes; invitado siempre separado de las cuentas, propiedad capturada y resultados asíncronos obsoletos descartados. Pruebas de disco, reapertura, escritura fallida y reintento. No se añadió sincronización remota para notas/programas. |

## Comprobaciones finales

- `flutter test --no-pub`: **247/247**, incluyendo los módulos ajenos como
  regresión de la carpeta de trabajo actual; no es un checkout limpio de todo
  el trabajo preexistente. Log `build/training_expansion_final_tests.log`.
- `flutter analyze --no-pub`: **0 incidencias**.
  `build/training_expansion_final_analyze.log`.
- Android: `flutter build apk --debug --no-pub`, APK en
  `build/app/outputs/flutter-apk/app-debug.apk`; no se ejecutó en dispositivo.
  `build/training_expansion_android_final.log`.
- Web: `flutter build web --release --no-pub`, Wasm dry run aprobado;
  `build/training_expansion_web_final.log`. Se ejecutó el build en navegador
  integrado, localhost aislado, invitado, almacenamiento real Hive/preferencias:
  Inicio → Entrenamiento → Mi progreso/calendario; catálogo sin filtros → ficha
  Resumen/Historial/Técnica. Esto no verifica Firebase ni una API remota.
- Capturas revisadas: ficha con ilustración/gráfico, mapa, sesión compacta y
  resumen; variante clara 320 px/texto 200%, movimiento reducido y fixtures
  pobladas/vacías. PNGs reproducibles en `test/goldens/`; las imágenes se
  precargan antes de capturar, no se aprueban capturas con assets aún vacíos.
- Ensayo de índice en host: 1/20, 50/1.000 y 500/10.000 sesiones/series,
  respectivamente **1.274 / 13.847 / 76.908 μs** en una ejecución de la suite.
  Son observaciones del host con fixtures, sin umbral prometido ni equivalencia
  a tiempos de fotograma, memoria o rendimiento de un teléfono.
- Revisión acotada: persistencia/revisión/recuperación, asincronía y propiedad,
  navegaciones de edición, aplicabilidad de métricas, privacidad de exportación,
  formatos antiguos sin ID/fecha, rutas del overlay y compatibilidad nativa.
  Se corrigieron los problemas encontrados y se repitieron las regresiones.

## Pendientes explícitos para certificar el producto completo

1. Ejecutar el recorrido integrado y el diálogo real de compartir en Android;
   compilar/ejecutar iPhone con Mac/Xcode. El usuario no tiene esos equipos ahora.
   Verificar teclado, pausa/background/restauración y VoiceOver/TalkBack reales.
2. Perfilado en modo profile en hardware representativo: arranque, fotogramas,
   memoria y batería con historiales grandes. La caché por cuenta/día/revisión,
   listas lazy y gráficos acotados están implementados; falta esa medición nativa.
3. Apariencia global: el módulo respeta ThemeData heredado y se verificó claro/
   oscuro; `main.dart` todavía fija `AppTheme.dark`. Las opciones Clásico/Pink
   de Ajustes no tienen aún conexión global efectiva. No se certifican esos
   dos modos ni se altera el trabajo previo de Ajustes/Perfil para ocultarlo.
4. Contenido: 6 ilustraciones específicas y 291 fallbacks de categoría para los
   297 ejercicios; revisión profesional de técnica ampliada pendiente. No se
   inventan imágenes, animaciones biomecánicas ni datos fisiológicos faltantes.
5. Perfil conserva otros indicadores de demostración previos ajenos a la pestaña
   PRs; no usar esos indicadores como evidencia de estadísticas reales del módulo.
6. Preparación de tienda: Android conserva applicationId `com.example.fit_app`
   y release con firma de debug; hay que definir identidad/firma reales antes
   de distribuir. iOS y publicación no realizados. El build actual advierte una
   futura actualización del toolchain; no se saltaron validaciones de Gradle.
7. El adjunto original termina en 18.3: no se inventa la continuación faltante.

No hubo push, publicación, Figma ni sustitución de archivos locales por GitHub.
Los cambios ajenos se conservan fuera del commit de Entrenamiento, incluyendo
el asset USDA agregado previamente a pubspec.yaml.
