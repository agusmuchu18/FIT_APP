# Plan de profesionalización de Entrenamiento

Estado: **en ejecución**. Última revisión: 2026-10-01.

Continuación implementada y evidencia actual:
[WORKOUT_READINESS_2026_10_01.md](WORKOUT_READINESS_2026_10_01.md).
Incluye aislamiento invitado/cuentas, guardado al salir, recuperación de cierre,
series temporizadas/asistidas, ajustes reales y capturas de sesión. Los estados
y cifras de las tablas históricas inferiores describen sus cortes anteriores.

## Objetivo y alcance

Una persona debe poder crear o elegir una rutina, iniciar o reanudar una
sesión, registrar series, descansar, terminarla y encontrar el mismo resultado
en Entrenamiento, Home, Rachas y las vistas de progreso. El flujo debe conservar
datos al cerrar la app, funcionar sin conexión, respetar la cuenta activa y ser
usable con texto ampliado y lector de pantalla. La dirección visual aprobada
por el usuario es deportiva premium, con fotografía de entrenamiento y detalles
de equipamiento, iconografía coherente y movimiento funcional.

El alcance incluye `lib/features/workout/`, sus consumidores de Home/Rachas,
`FitnessRepository`, persistencia, navegación, assets, pruebas y documentación
de diseño. Se preservan sesiones y rutinas existentes, incluso las de las claves
`pro_*` y `workout_in_progress_v2_*`. No se borra una ruta, clave o modelo legado
hasta demostrar una migración reversible y comprobar su uso real.

## Punto de partida comprobado

- 33 archivos Dart y 14.346 líneas en el módulo. Hay cambios locales previos en
  el código y las pruebas; cada edición debe conservarlos.
- `/workout/session` usa `WorkoutSessionController` y `WorkoutRepository`;
  `WorkoutProScreen` y `WorkoutProProvider` contienen otro flujo que no está
  conectado a las rutas actuales.
- Las sesiones nuevas se guardan en `workout_in_progress_v2_sessions`;
  Home/Rachas leen `WorkoutEntry` desde `FitnessRepository`. La mini barra y
  Training Home mezclan los borradores `pro_workout_draft` y
  `workout_in_progress_v2_draft`.
- El lector de series previas pide `getStringList('pro_workout_sessions')`,
  aunque el proveedor anterior guardaba esa clave como `String` JSON.
- Buscar rutinas, ajustes y configuración global contienen marcadores de
  posición. El historial sólo lista sesiones, y editar una rutina sólo cambia
  el nombre. El catálogo de ejercicios no tiene media ni instrucciones.
- Las pruebas presentes cubren creación de rutina, picker, mini barra, formato
  del encabezado y estado inicial de Training Home. Faltan regresiones del
  repositorio, sesión completa, migración y accesibilidad.

## Reglas de ejecución

1. Trabajar por cortes verticales pequeños: dato → controlador → UI → prueba.
   Cada corte debe compilar y pasar sus pruebas antes de abrir el siguiente.
2. Antes de cambiar persistencia, guardar fixtures de las formas previas de
   JSON. Las migraciones son idempotentes: reabrir la app no duplica ni borra
   sesiones. Un registro malformado se aísla; no provoca borrado masivo.
3. Un único identificador de catálogo (`exerciseId`) permanece estable.
   Los IDs de instancia de rutina, ejercicio y serie son independientes.
4. No declarar «100 %» a partir de lectura estática o pruebas de widgets:
   exigir pruebas automatizadas, recorridos reales en dispositivo, inspección
   visual y evidencia de las plataformas soportadas. Registrar resultados y
   bloqueos al lado de cada criterio.
5. Actualizar `docs/CODEBASE_MAP.md`, `docs/DATA_MODEL.md`,
   `docs/ARCHITECTURE.md`, `docs/CURRENT_STATUS.md` y el Canvas sólo cuando
   cambien sus contratos o rutas; no duplicar código en la documentación.

## WP-00 · Línea base y decisiones de datos

**Estado:** en curso (línea base focal registrada; inventario y capturas pendientes). Inventariar datos reales y fixtures sin imprimir datos
personales. Confirmar versiones de Flutter/Dart y rutas soportadas; ejecutar
pruebas actuales, análisis focalizado y capturas de Home, picker, sesión,
historial, tema claro/oscuro, pantalla estrecha y texto ampliado. Registrar el
resultado previo y los cambios locales por archivo. Preparar fixtures para
ambas familias de borradores/sesiones, rutinas duplicadas y datos corruptos.

**Decisión de arquitectura antes de migrar:** escoger un repositorio canónico
de sesión rica (ejercicios y series) respaldado por almacenamiento duradero
existente. Definir su proyección única a `WorkoutEntry` para Home/Rachas, el ID
estable, propietario `uid`, política de invitado/cambio de cuenta, conflicto
offline/remoto y el punto transaccional de finalización. No asumir que una
escritura en dos repositorios independientes es atómica.

**Cierre:** diagrama de propiedad de datos, fixtures versionados y línea base
de pruebas/capturas disponibles; decisión de migración documentada.

## WP-01 · Compatibilidad de historial y series previas

**Estado:** implementación y pruebas unitarias completas; verificación de UI pendiente. Leer la clave antigua con su tipo real (`String` que
contiene una lista JSON); aceptar también una lista de strings si existiera en
instalaciones anteriores. Elegir la sesión más reciente del mismo ejercicio,
sin perder la prioridad de una sesión nueva. El JSON defectuoso se salta sin
ocultar otros registros válidos. No reescribir datos legados en este corte.

**Comprobaciones:** tests unitarios con sesión antigua, dos sesiones antiguas
en distinto orden, sesión nueva y antigua, clave ausente, tipo inesperado y
registro malformado. El selector y «Agregar serie» muestran el antecedente
correcto sin excepción.

## WP-02 · Identidad y ciclo de sesión activa

**Estado:** en curso (identidad v2, conflicto, pausa persistente y continuidad del borrador `pro_*` implementados). Introducir una representación única del borrador con
`sessionId`, `templateId`, nombre, tipo, inicio, pausa, duración pausada,
ejercicios y revisión de escritura. Al intentar iniciar otra rutina con un
borrador, ofrecer **Continuar / Reemplazar / Cancelar**; no atribuir ejercicios
del borrador a la rutina recién pulsada. Inicio libre, plantilla vacía, doble
tap, regreso desde segundo plano y cierre forzado deben converger al mismo
estado. Mini barra, Training Home y pantalla de sesión observan la misma
fuente; pausar, reanudar y descartar afectan sólo esa sesión.

**Comprobaciones:** tests de transición de estados y widgets para las tres
decisiones; reabrir tras terminar, pausar, descartar y matar/reiniciar proceso;
comprobar identidad, cronómetro y visibilidad de mini barra en cada ruta.

## WP-03 · Persistencia canónica e integración transversal

**Estado:** en curso (sesiones ricas v2 migradas a Hive y proyección a Home/Rachas implementadas). Migrar sesiones y rutinas desde `SharedPreferences` a
la solución duradera elegida en WP-00, conservando copias legadas hasta pasar
la auditoría de migración. Eliminar el límite silencioso de 100 sesiones.
Finalizar una sesión una sola vez e incorporar su proyección a Home, Rachas,
historial y estadísticas sin duplicados. Establecer orden de escrituras,
reintentos, exportación/recuperación y propiedad por cuenta.

**Comprobaciones:** fixtures de versiones previas, primera apertura,
reapertura, migración repetida, fallo a mitad de escritura, 101+ sesiones,
offline/online, cambio de usuario e invitado. Misma sesión e ID en todas las
vistas; ninguna sesión perdida ni duplicada. Prueba de integración que registre
una sesión y la encuentre en Home y Rachas.

## WP-04 · Rutinas y biblioteca de ejercicios

**Estado:** en curso (edición de rutinas, ID de catálogo, búsqueda real e historial con detalle básico probados). Mantener ID de catálogo al duplicar rutinas; añadir ID
de instancia separado para permitir el mismo ejercicio dos veces. Hacer
edición real de nombre, tipo, orden, ejercicios, series, repeticiones, carga,
descanso y carpeta. Conectar «Buscar rutinas» con fuentes reales y estados
vacío/carga/error. Definir búsqueda y filtros consistentes entre creación y
sesión; validar alias, acentos y equipamiento. Revisar catálogo: datos
obligatorios, duplicados conceptuales, instrucciones, contraindicaciones de
interfaz y disponibilidad de media; no inventar datos biomecánicos.

**Comprobaciones:** crear→editar→duplicar→mover→iniciar→reanudar; IDs de
catálogo intactos, configuraciones persistidas y dos instancias distinguibles;
búsquedas con acentos, sin resultados y catálogo offline.

## WP-05 · Registro de series y descanso

**Estado:** en curso (borrado, foco, validación, descanso persistente y ajustes reales probados). Distinguir explícitamente «sin valor» de «conservar
valor» en kg/reps; validar rango, separador decimal, unidades y series vacías.
Evitar que las actualizaciones muevan el cursor. Confirmar series con respuesta
visual y accesible, deshacer/corregir, y temporizador de descanso asociado a
la serie completada (iniciar, omitir, ampliar, pausar, notificación si procede).
Al terminar, mostrar resumen con duración real, series y próximos pasos.

**Comprobaciones:** borrar valor existente, 0, negativos, decimal local,
teclado, repetición rápida, bloqueo/desbloqueo y retorno desde segundo plano;
timer correcto con reloj simulado y dispositivo real. No guardar un resultado
engañoso por ausencia de datos.

## WP-06 · Métricas y visualización veraz

**Estado:** en curso (desconocidos no se asignan a Core; planificación y ejecución separadas). Definir por escrito volumen, series realizadas,
ejercicios sin carga, asistencia, unilateralidad y comparaciones válidas.
Separar planificado de ejecutado. Nunca clasificar un músculo desconocido como
Core por defecto. Sustituir el radar actual si la definición no justifica sus
porcentajes; mostrar fuente, unidad, cobertura y alternativa tabular. Validar
la metodología con la dependencia de producto señalada en el Design System.

**Comprobaciones:** casos de peso corporal, asistencia, unilateral, series
parciales, ejercicio desconocido, entrenamiento vacío y comparación previa;
valores recalculables desde las series y lectura por lector de pantalla.

## WP-07 · Experiencia deportiva premium

**Estado:** en curso (fotografía editorial integrada en la entrada de Entrenamiento). Diseñar pantallas reales de entrada, rutinas, picker,
sesión, descanso, cierre e historial con la dirección elegida por el usuario:
fotografía de personas entrenando, detalles de equipamiento, contraste y
energía. Definir cobertura por ejercicio, procedencia/licencia, formatos,
tamaños, cache y fallback offline; imagen decorativa nunca contiene texto o
datos indispensables. Crear familia de iconos consistente y jerarquía de
acción/estado. Animar acciones significativas (serie, descanso, navegación,
resumen), con variante de movimiento reducido. Actualizar la sección visual
aplicable de `docs/design/DESIGN_SYSTEM.md` antes de codificar nuevos estilos.

**Comprobaciones:** aprobación del diseño sobre pantallas representativas;
capturas comparadas con diseño y estado real con/sin imágenes; modo claro y
oscuro, imágenes fallidas/offline, movimiento reducido y revisión de licencias.

## WP-08 · Accesibilidad, adaptación e internacionalización

**Estado:** pendiente. Etiquetar iconos y gráficos; exponer valores, unidades y
acciones completos a TalkBack/VoiceOver. Garantizar objetivos táctiles y foco
visible; probar contraste, teclado, lectura de formularios y orden semántico.
Eliminar alturas fijas que recortan tarjetas con texto grande. Revisar español
consistente («Gym», «Custom», «Sets», etc.), números y unidades por locale.

**Comprobaciones:** guideline tests de Flutter, texto al 200 %, ancho 320 dp,
orientación, tablet, teclado, TalkBack y VoiceOver; cada acción completa el
flujo sin depender de color, imagen, gesto oculto ni animación.

## WP-09 · Rendimiento y calidad de código

**Estado:** pendiente. Medir en profile mode la apertura del picker, escritura
de series, scroll y animaciones. Sólo entonces acotar reconstrucciones,
indexar búsquedas/cálculos repetidos y revisar el timer del encabezado.
Separar los widgets/servicios grandes por responsabilidad cuando reduzca
acoplamiento y facilite pruebas. Decidir qué capacidades de `WorkoutProScreen`
se migran; retirar el flujo antiguo sólo tras migración de datos y pruebas.

**Comprobaciones:** trazas antes/después en dispositivos objetivo, sin pérdida
de funciones; pruebas de regresión de las rutas y contratos retirados.

## WP-10 · Cierre integral y criterio de «100 %»

**Estado:** pendiente. Ejecutar pruebas unitarias, widgets y de integración
del recorrido completo; análisis estático, builds de plataformas soportadas y
pruebas manuales con datos nuevos/migrados. Registrar versión/dispositivo,
captura o log de cada escenario. Revisar privacidad y aislamiento por cuenta,
offline, pérdida de red, reinicio, error de imagen, error de almacenamiento y
actualización desde una versión anterior. La lista de incidencias P0/P1 debe
estar vacía; P2 sólo si la persona responsable acepta explícitamente el alcance.

La finalización exige simultáneamente: **datos correctos**, **flujo completo sin
marcadores**, **diseño visual aprobado**, **accesibilidad verificada**,
**rendimiento medido**, **pruebas y builds verdes** y **documentación fiel**.
Marcar una tarea como implementada no equivale a marcarla verificada.

## Registro de verificación

| Corte | Código | Test focal | Integración/dispositivo | Estado |
|---|---|---|---|---|
| WP-00 | inventario parcial | suite completa: 87 pruebas verdes en Windows | capturas y Android/iPhone pendientes | en curso |
| WP-01 | lector legado corregido | tipos, orden, prioridad, clave ausente y corrupción cubiertos | selector y «Agregar serie» en dispositivo pendientes | en curso |
| WP-02 | identidad v2, conflicto, pausa persistente y ruta de continuidad para `pro_*` | identidad, pausa y decisiones sobre borrador legado cubiertas | reinicio real, convergencia de modelos y mini barra en dispositivo pendientes | en curso |
| WP-03 | sesiones ricas en Hive, ID estable, proyección a Home/Rachas y refresco de Home | migración, 101+ sesiones, reintento y Home verdes | cuenta, transacción y dispositivo pendientes | en curso |
| WP-04 | editor de nombre, tipo, carpeta, orden, ejercicios y objetivos; búsqueda e historial con detalle | edición, validación, búsqueda y repetición de un ejercicio verdes | catálogo/media, IDs de instancia en rutina y dispositivo pendientes | en curso |
| WP-05 | borrado, foco, validación, descanso, ajustes y guardado serializado | controlador, widgets, pausa, preferencias y carrera verdes | notificación, UX de cierre y dispositivo pendientes | en curso |
| WP-06 | desconocido sin atribución a Core; planificado separado de ejecutado | regresiones unitarias verdes | definición completa y accesibilidad pendientes | en curso |
| WP-07 | imagen editorial en tarjeta de inicio | render widget verde | diseño integral, media por ejercicio y aprobación visual pendientes | en curso |
| WP-08 a WP-10 | pendiente | pendiente | pendiente | pendiente |

### Evidencia de ejecución · 2026-09-28

- `flutter test --no-pub --reporter expanded test/features/workout test/training_home_screen_test.dart`: **25/25 pruebas aprobadas** en el entorno local Windows. Incluye las regresiones nuevas de historial, identidad de sesión, duplicación, métricas y edición de series.
- `dart analyze lib/features/workout test/features/workout test/training_home_screen_test.dart`: **sin problemas**.
- El lector de series previas acepta el `String` JSON legado y una lista de strings, prioriza sesiones v2 y salta entradas corruptas. No modifica los datos guardados.
- Al duplicar una rutina se conserva el ID del ejercicio de catálogo y se regeneran los IDs de series. Un ejercicio desconocido deja de figurar como Core en la distribución.
- Al vaciar kg o repeticiones, el modelo pierde el valor anterior. Al escribir kg, la reconstrucción de la fila no reescribe el campo enfocado ni desplaza el cursor.
- El borrador v2 conserva `sessionId`, `routineId`, nombre e inicio incluso si aún no contiene ejercicios. Al elegir otra rutina, el flujo ofrece Continuar, Reemplazar o Cancelar antes de navegar. Continuar conserva el borrador; Reemplazar lo limpia; Cancelar no cambia la sesión. Falta unificar el borrador `pro_*` y probar el proceso completo en dispositivo.
- Estos resultados iniciales verificaban sólo el corte focal. La continuación siguiente amplía persistencia e integración, pero sigue pendiente la verificación en dispositivo, accesibilidad, diseño integral y rendimiento. Ningún WP está cerrado al 100 %.

### Evidencia de ejecución · continuación 2026-09-28

- `flutter test --no-pub --reporter compact`: **79/79 aprobadas** en Windows tras los cambios transversales. La prueba de Home observa que 0 min cambia a 25 min al guardar; la de carrera retiene una escritura en curso y verifica que finalizar/descartar no resucita el borrador. El banner de descanso no desborda a 320 dp con texto 200 %; el control de pausa congela y reanuda el descanso.
- Las sesiones ricas v2 se copian de preferencias a Hive `fit_workout_sessions` por ID, sin borrar la fuente antigua; los registros corruptos se aíslan. El cierre guarda la sesión rica, proyecta el mismo ID a `WorkoutEntry` y borra el borrador al confirmar ambas escrituras. Falta aislamiento por cuenta, migración de `pro_*`, transacción/reconciliación y prueba de reinicio real.
- La pausa v2 conserva inicio y tiempo pausado. El descanso comienza al completar una serie, se conserva en el borrador, se congela con el tiempo activo, permite ampliar 30 s u omitir y tiene variante de movimiento reducido. No hay notificación en segundo plano ni verificación en dispositivo.
- La búsqueda de rutinas usa datos reales y acepta acentos; se validan kg/reps antes de completar una serie. La tarjeta de inicio usa una fotografía local con fallback. Falta completar las restantes pantallas, medios, iconografía y accesibilidad.
- Al salir de sesión, Training Home recarga historial; `FitnessRepository` avisa a Home tras guardar para refrescar el resumen montado. Android e iPhone siguen sin recorrido real: no hay dispositivo Android conectado y iPhone necesita macOS/VoiceOver.
- `flutter analyze --fatal-infos`: **sin problemas**. `flutter build apk --debug --no-pub` no quedó verificado: Kotlin falló por caché incremental con rutas en unidades diferentes (`C:`/`D:`); un segundo intento sin incremental quedó sin progreso y se interrumpió. Los cambios automáticos del migrador Flutter en `android/gradle.properties` se retiraron. No atribuir este fallo al código Dart sin una compilación limpia.
- El historial abre un detalle por sesión con series realmente ejecutadas; `SetEntry.done` es opcional para conservar el legado. Los ajustes de Entrenamiento ya guardan descanso predeterminado para ejercicios nuevos. Sin series completadas, el radar devuelve cero y la carga se etiqueta como externa; sigue pendiente definir y validar el método de distribución muscular antes de presentarlo como métrica final.
- Metadatos de rutinas y carpetas dañados se aíslan por entrada; un registro inválido ya no bloquea Entrenamiento ni oculta otros registros válidos. Prueba focal y análisis del último ajuste verdes.

### Evidencia de ejecución · 2026-09-29

- `flutter test --no-pub --reporter compact`: **87/87 aprobadas** en Windows; `flutter analyze --fatal-infos --no-pub`: **sin problemas**.
- «Editar rutina» permite cambiar nombre, tipo, carpeta, orden, ejercicios del catálogo, series, repeticiones, carga y descanso. Valida límites, admite borrar objetivos opcionales y encuentra nombres sin tildes. Los objetivos guardados precargan la sesión siguiente. La vista previa expande por posición cuando se repite el mismo ejercicio de catálogo.
- Si sólo hay un borrador `pro_*`, `/workout/session` reabre el flujo que conserva sus campos y series. Al iniciar otra rutina se ofrecen Continuar, Reemplazar o Cancelar; sólo Reemplazar borra ese borrador. Se probó cada opción con un fixture legado. Falta migrar ambas familias a un modelo único sin perder RIR, duración, componentes de carga y metadatos; esta ruta de continuidad es una protección transitoria.
- Las pruebas de widgets no sustituyen el recorrido en Android e iPhone. Compilación Android del corte y ejecución iOS siguen sin verificar.

Registrar aquí fecha, comando, resultado, entorno y evidencia al completar
cada corte. Si una herramienta no puede acceder al SDK, caché o dispositivo,
el estado permanece **no verificado**, nunca «aprobado» por inferencia.
