# Current status

**Actualizado:** 2026-10-24
**Base auditada:** `9f61c68ff4a362d48f97265d300f7ae54de64edc`
**Carpeta local:** `D:\Datos User\Escritorio\fitness\fit_app`

## Salud comprobada

| Control | Resultado |
|---|---|
| SDK | Flutter 3.47.3 / Dart 3.13.3; actualización estable aplicada |
| `dart format` | Base de 158 archivos; cambios posteriores formateados por archivo |
| `flutter analyze --fatal-infos` | 0 problemas |
| `flutter test --no-pub` | 333 aprobadas + 1 omitida (24/10); contrato omitido ejecutado aparte con emuladores: 1 aprobado; backend social: 13 aprobadas |
| Web release | Compila; dry run Wasm aprobado. Último recorrido local en `/`; el build anterior también comprobó `/FIT_APP/` |
| YAML de GitHub | Sintaxis válida |
| APK Android | Debug compilado el 23/10 con notificaciones locales (desugaring activado); no ejecutado en Android ni validado para tienda |
| Integración móvil local | APK de prueba compilado; recorrido compartido ensayado en host. No ejecutado en Android/iPhone |

La ampliación previa de alimentación/USDA está en la carpeta original y sigue
pendiente de commit. Entrenamiento tiene commits locales en
`codex/workout-redesign-20261012`, `codex/routine-system-20261012` y
`codex/routine-inline-ux-20261014`; no se hizo push ni despliegue. Las comprobaciones
corresponden a la carpeta de trabajo actual, que conserva cambios previos de otros
módulos; no equivalen a validar un checkout limpio de esos commits.

## Entrenamiento · sesión sin fricción 23/10

Corte de UX y errores de la sesión en vivo. Verificado en la PC local con
`tools\claude_verify.bat` (analyze 0 problemas, 319 pruebas) y
`tools\claude_build.bat` (APK debug y web release compilan).

- Errores: ejercicio con series hechas pide confirmación y todo borrado se puede
  deshacer; la rutina abre su primer ejercicio y carga «Anterior»; kg sin «.0»;
  encabezado fijo en teléfonos (radar en hoja); «Reintentar» conserva el
  programa; conteo de distancia al finalizar; días por calendario; etiquetas.
- Registro: tabla SERIE/ANTERIOR/KG/REPS/✓, «Anterior» tocable y como sugerencia,
  ✓ completa con el valor anterior/objetivo, auto-avance al siguiente ejercicio,
  deslizar para borrar serie, duración en m:ss, barra de teclado ‹ › Listo.
- Descanso: vibración y sonido al terminar (también desde la mini-barra), cierre
  automático a los 3 s, −15/+15 s, cuenta regresiva en la mini-barra.
- Sesión: «Finalizar» fijo en la barra superior, barra inferior compacta, hoja de
  agregar con recientes, filtro por músculo, imágenes y selección múltiple;
  al finalizar se elige qué hacer con series sin marcar.
- Progreso: récord de peso en vivo (🏆), récords destacados en el resumen y
  propuesta de actualizar la rutina con lo hecho (no borra ejercicios no hechos).
- Inicio: tarjeta «Continuar entrenamiento» si hay sesión, bloques más compactos;
  mini-barra visible en Historial, Mi progreso y Programas con espacio reservado.

- Tipos de serie: normal, calentamiento (C), drop (D) y al fallo (F). El
  calentamiento se guarda pero no cuenta para volumen, récords ni músculos.
- Superseries: vincular con el siguiente desde el menú del ejercicio; el descanso
  arranca recién tras el último ejercicio del bloque. Se guardan en la rutina.
- Aviso de descanso en segundo plano: `flutter_local_notifications` + `timezone`;
  se programa al salir de la app con un descanso corriendo y se cancela al volver.
  Permiso pedido una sola vez, en el primer descanso. Android: desugaring y
  `SCHEDULE_EXACT_ALARM` (si no está concedido usa alarma inexacta).
- Flujo legado `pro/`: al iniciar sesión, los borradores viejos con ejercicios
  pasan al formato actual y abren en la sesión en vivo
  (`legacy_draft_migration.dart`). Se conserva la pantalla vieja solo para
  registros de actividad sin ejercicios (cardio por duración/distancia) y para
  terminar un guardado viejo a medias, porque la sesión en vivo aún no registra
  distancia/ritmo/RPE por sesión.

Pendiente: registro de actividad sin ejercicios en la sesión en vivo (para borrar
`pro/workout_pro_screen.dart` y su provider); probar notificaciones en un
teléfono real; actualizar Gradle/AGP/Kotlin antes de que Flutter deje de
soportar las versiones actuales (aviso del build).

## Expansión complementaria · 24/10

Auditoría/plan en `docs/expansion/`; estado granular en IMPLEMENTATION_STATUS.md.
Grupos guarda contactos privados por cuenta/invitado, conserva IDs y variantes
legadas en conflicto, sin semillas ni métricas aleatorias ni escrituras indirectas
a StatisticsService. Crear/agregar espera guardado y conserva entradas si falla.
El mismo ProfileController persiste nombre/avatar privados por cuenta y rechaza
controladores anteriores. Se retiraron picsum/@fit_user/objetivo fijo, conservando
Fotos/Estadísticas/PRs y sus cálculos. Los 18 conectores indican capacidad pendiente,
sin flags antiguos como prueba de conexión ni Premium activo sin sistema comercial.

Identidad social real en `backend/social`: handles únicos, búsqueda paginada,
follow/solicitudes, contadores, bloqueos y permisos probados con emuladores.
Grupos conserva Mis grupos y suma Descubrir internamente; Perfil tiene editor
de identidad/privacidad. No publica salud ni avatar privado. App Check y tokens
Firebase reales en el cliente; `FIT_SOCIAL_ENABLED=false` hasta configurar y
validar producción. Pendientes: Node 22, App Check registrado, ciclo de borrado
de cuenta, lista de bloqueados y dispositivos. Feed/grupos remotos/medidas y
otras etapas no se declaran completas. Ver TEST_REPORT para límites y evidencia.
333 pruebas Flutter + 13 backend + 1 contrato real; análisis estricto limpio,
web release y APK debug aprobados. Tres capturas sociales revisadas con texto
ampliado/temas. Sin cambios propios a Entrenamiento ni navegación principal,
push o despliegue. Se conserva WIP previo; no certifica checkout limpio.

## Buscar rutinas · 23/10

La entrada muestra 12 propuestas offline con fotografías distintas, cuatro por
nivel (básico/intermedio/avanzado), búsqueda y filtros. Cada detalle permite
consultar objetivos y fichas, abrir el editor existente y guardar una copia por
cuenta sin sobrescribir el borrador normal ni insertar sesiones/resultados.
Mis rutinas conserva el acceso a las guardadas. Corregido su reintento de lectura.
Nueve WebP nuevos suman 906.064 bytes; se reutilizan tres fotografías existentes.
Sin dependencias ni permisos nuevos. Plan: `docs/plans/ROUTINE_CATALOG_2026_10_23.md`.
Verificados 270 tests y análisis estricto sin incidencias; cuatro goldens revisados
(390 px oscuro/detalle, 900 px claro y 320 px/200% con movimiento reducido).
APK debug y web release recompilados. Recorrido web a 390×844 desde Home:
Entrenamiento → Buscar → detalle → ficha → personalizar → guardar → Mis rutinas
→ Home de Entrenamiento con la copia disponible y sin sesión registrada. Prueba
en un origen localhost separado, con copia identificada como «Prueba local»;
no se usó una cuenta del usuario. No equivale a ejecución Android/iPhone.

## Entrenamiento · continuidad 22–23/10

Perfil usa el historial real por cuenta para entrenamientos guardados, series y
días de los últimos 30 días, última marca verificada, frecuencia, volumen y
duraciones comparables. Reutiliza el motor de entrenamiento; no añade otra base
de datos ni fórmulas. Carga, vacío y error se distinguen; las respuestas de otra
cuenta se descartan. Perfil y PRs difieren sus lecturas mientras están ocultos,
conservan filtros y convierten unidades sin releer ni reescribir sesiones.

Plan y aceptación: `docs/plans/TRAINING_PROFILE_REAL_DATA_2026_10_22.md`.
Verificados 260 tests, análisis estricto sin incidencias, APK debug y web release;
tres goldens revisados, incluidos 320 px/200% y movimiento reducido. El 23/10 se
comprobó en navegador el historial local vacío, estadísticas, PRs, desplazamiento,
acceso al análisis y regreso conservando la pestaña. Las fotos e identidad de
demostración previas siguen separadas de estas métricas. No se declara 100% de tienda.

## Entrenamiento · corte 21/10

Expansión local en `codex/training-expansion-20261017`; fuente y aceptación en
`docs/plans/TRAINING_EXPANSION_2026_10_17.md` y auditoría inicial en
`docs/auditorias/ENTRENAMIENTO_AUDITORIA_FUNCIONAL.md`. Un único motor de métricas,
ficha/PRs reales, estadísticas/mapa/calendario/informes, programas y ejemplos,
historial editable recuperable, exportación PNG optativa y unidades por cuenta.
Invitado separado; sin cambios de navegación global ni sincronización nueva.
APK debug y web release compilados; recorrido de lectura ejecutado en navegador
con Hive local real. Capturas y widget tests cubren 320 px/200%, claro/oscuro.

Pendientes: Android/iPhone y compartir nativo, lectores de pantalla y perfilado
en hardware; conexión global de los modos Clásico/Pink (main fija tema oscuro),
cobertura de ilustraciones/técnica y preparación real de firma/identidad de tienda.
La conexión de los demás indicadores de entrenamiento de Perfil se completó en
la continuidad del 22–23/10 descrita arriba. No se declara 100% de tienda.

## Entrenamiento · cortes anteriores

El ajuste del 14/10 está en `docs/plans/ROUTINE_INLINE_UX_2026_10_14.md`: configuración
inline reutilizada, ficha técnica sólo desde el nombre y + independiente. Conserva
valores temporales al contraer/desmontar filas; los valores válidos seleccionados
actualizan el borrador por cuenta. Filtros vectoriales de 40 dp con selección
múltiple, traducciones y taxonomía separada sin alterar IDs. Corregida la comparación
UTC/local de «sesión hoy». Verificados 195 tests, análisis estricto sin problemas,
web release compilada y nueve capturas nuevas revisadas; incluye 320 px/200%,
teclado, anclaje con movimiento y fallback. En aquel corte, Entrenamiento imponía tema oscuro; la expansión del 21/10
respeta el tema heredado, con el límite global descrito arriba. Android/iPhone, lectores
nativos y perfilado siguen pendientes; el APK anterior no verifica este cambio.

El corte anterior de rutinas está en `docs/plans/ROUTINE_SYSTEM_2026_10_12.md`: borrador único
recuperable por cuenta, ficha/configuración compartida, biblioteca con slivers,
preview guardado, objetivos por serie, lastre y fútbol en seis modalidades/14
actividades. El catálogo conserva 297 IDs. Se generaron seis ilustraciones WebP
específicas (71.974 bytes); las otras 291 usan categorías genéricas con cobertura
pendiente registrada en el manifiesto. Guardado/error/reintento/doble toque,
carpetas, registros deportivos e inset de teclado están comprobados en host.
Análisis estricto: 0 problemas; suite: 170/170; web release y APK debug compilados.
No se realizó ejecución Android/iPhone, prueba de lectores nativos ni perfilado.

El párrafo siguiente describe el corte previo del rediseño de sesiones.

El rediseño autorizado del 12/10 está documentado en
`docs/plans/WORKOUT_REDESIGN_2026_10_12.md`, con entrega A–J y comprobaciones.
Sesión activa tiene acción contextual y confirmación previa; descanso usa un
selector único y banner. Guardar reemplaza la sesión por un resumen completo por
ID persistido. Historial ofrece filtros por cuenta, métricas, semanas reales y
lista agrupada por mes. Detalle conserva todas las series y permite repetir con
ID nuevo, sin modificar el original. Cálculos compartidos distinguen unidades,
datos ambiguos y tiempos desconocidos. Diez nuevos WebP locales suman 88.294 bytes.
Hay capturas golden a 320/390/900 px y texto al 200%; no son ejecución nativa.
Suite de 142 pruebas, análisis, web release y APK debug pasaron con este código.
Quedan ejecución Android/iPhone, lectores de pantalla, perfilado y ciclo de vida
de plataforma. No se certifica todavía preparación al 100% para App Store.

El siguiente párrafo conserva contexto de las mejoras anteriores del módulo.

El plan verificable está en `docs/plans/WORKOUT_PROFESSIONALIZATION.md` y la
evidencia del corte actual en `docs/plans/WORKOUT_READINESS_2026_10_01.md`.
Sesiones ricas v2 en Hive, proyección con ID estable a Home/Rachas, refresco de
Home al guardar, búsqueda real de rutinas, pausa y descanso persistentes,
validación de series, edición de nombre, tipo, carpeta, ejercicios y objetivos, detalle
de historial, ajustes de descanso, tres imágenes editoriales locales e iconografía
propia de entrada están implementados. Crear rutina muestra ejercicios desde el
inicio, prioriza movimientos variados y recientes, y permite agregarlos desde
la lista; búsqueda y filtros refinan el catálogo. La mini-barra vive dentro de un
`Overlay` válido para que sus tooltips no fallen al abrir Entrenamiento. Un
borrador legado `pro_*` reabre su flujo original y exige
decisión explícita antes de reemplazarlo. Datos corruptos de carpetas/metadatos
se aíslan sin bloquear el historial. El corte actual añade guardado al volver y
segundo plano, error/reintento de guardado, carga con recuperación, pausa visible,
configuración real, eliminación de series y resumen al terminar. Segundos y
asistencia quedan separados de repeticiones/carga externa; se conserva el tipo
de rutina. Una respuesta tardía del historial no pisa ediciones nuevas.
Invitado y cuentas usan namespaces independientes; los datos anteriores siguen
en invitado. Al arrancar se reparan proyecciones de cierre incompletas sin duplicar.
El reloj deja de reconstruir el gráfico cada dos segundos. El APK debug compiló
sin fallback en este corte; persisten warnings de futuro soporte Gradle/AGP/Kotlin.
La continuación del 02/10 corrige el encabezado y la altura de tarjetas de
rutinas guardadas para pantallas pequeñas/texto grande. El recorrido local
de `integration_test` está preparado con namespace aislado y limpieza acotada;
`integration_test/README.md` detalla cómo ejecutarlo y sus límites.

No está completado al 100 %: faltan recorridos Android/iPhone, lectores de pantalla
reales, benchmarks en profile mode, interrupciones de proceso/almacenamiento en
dispositivo, media e instrucciones validadas por ejercicio, metodología muscular
y sincronización de sesiones ricas/rutinas entre dispositivos. Los borradores
legados se conservan y aún requieren auditoría de migración. No hay Android
conectado ni AVD instalado; iPhone requiere macOS/Xcode.

## Continuidad de modernización (registro de otra copia)

Estas notas históricas de `work/fit_app` no certifican automáticamente la carpeta
original. Para Entrenamiento, prevalece el corte actual descrito arriba.

- Cola por propietario, modo force persistido, compare-and-swap y protección
  contra respuestas tardías/cambios de cuenta; tareas legacy no se reasignan.
- Contención local de una cuenta por dispositivo (no aislamiento multiusuario).
- Push Firestore transaccional y pull paginado con desempate por ID; 25 pruebas
  adicionales de sync/persistencia/binding/transporte frente a las 34 iniciales.
- UI: retirados datos/fotos ficticios del perfil, estados explícitos no conectados;
  contraste del botón primario, Home vacío y reduced motion; título de sesión.
- Mini-barra oculta en acceso/registro/sesión, sin perder el borrador al navegar;
  ruta inicial explícita para diferenciar login de Home.
- Alimentación: alimentos personalizados, comidas del día y recuperación de la
  última comida ahora persisten en `SharedPreferences`; un fallo conserva el
  borrador. Selector y acciones adaptables, porciones claras, estado de búsqueda,
  reduced motion y modo local no invasivo. Flujo real validado a 390×844:
  registrar 107 kcal y recargar conserva el resumen.
- USDA/offline: Worker gratuito Cloudflare desplegado y probado en vivo; catálogo oficial
  Foundation 04/2026 con 363 alimentos, aliases españoles y hasta 500 detalles
  aprendidos. Secreto cifrado y búsqueda web pública operativos.
- Registro de alimento: gramos y mililitros dejan de estar tras un paywall falso;
  incrementos predecibles, máximo acotado y resultados locales ordenados/limitados.
- Capturas visuales de Entrenamiento y Crear rutina a 390×844 revisadas; fotos,
  ejercicios e iconos visibles. Ambos layouts pasan a 320 px con texto 200 %.
- Figma: foundations, 45 variables, 8 estilos de texto y 2 efectos creados.
  Componentes y tres pilotos NO completados: última llamada bloqueada por cupo
  MCP Starter. No se ha comprobado un restablecimiento del cupo.
- Diseño/pendientes: `DESIGN_SYSTEM.md`, `UX_AUDIT.md`, `MODERNIZATION_PLAN.md`.

## Mejoras ya aplicadas

- Migración de APIs Flutter/Dart obsoletas y formato uniforme.
- Autenticación simulada reemplazada por Firebase Authentication.
- Arranque sin login anónimo automático y fallback local explícito.
- Reglas Firestore por propietario añadidas y denegación por defecto.
- Clave USDA eliminada del build web; timeout, errores, carreras y caché
  corregidos.
- Proxy USDA seguro, catálogo offline oficial y persistencia de consultados añadidos.
- Errores de rutinas/selectores y pruebas de widgets corregidos.
- Siete pruebas de nutrición añadidas; golden de perfil validado.
- CI, Pages, Dependabot, README y lockfile actualizados.
- APIs de reordenamiento migradas a `onReorderItem` para Flutter 3.47.
- Memoria técnica y Skill personal de contexto eficiente añadidas.

FlutterFire está actualizado a `firebase_core 4.15.0`, `firebase_auth 6.7.0` y
`cloud_firestore 6.10.0`; `cupertino_icons` está en 2.0.0. Se eliminó
`google_fonts` y se empaquetó Inter localmente para garantizar texto offline y
goldens reproducibles. `flutter pub outdated` deja cuatro transitivas no
resolubles con las restricciones actuales: `cross_file`, `equatable`,
`material_color_utilities` y `test_api`. No hay directas pendientes.

El entorno Android local quedó operativo con SDK 36, Build Tools 36.0.0,
Platform Tools 37.0.1, NDK 28.2.13676358, CMake 3.22.1 y Java 17. Los APK usan
`minSdk 24`, `targetSdk 36` y firma v2. El release todavía está firmado con el
certificado de debug. Flutter 3.47.2 también avisa que próximamente exigirá AGP
9.0.1, Gradle 9.1.0 y Kotlin 2.3.20; la migración de toolchain debe validarse
como cambio separado. Las dependencias Dart solicitadas sí quedaron actualizadas.

## Bloqueadores de producción

1. Elegir package/bundle IDs; todavía existen valores `com.example`.
2. Configurar firma Android release; el SDK local ya está operativo.
3. Registrar Firebase nativo, habilitar providers, probar/desplegar Rules y
   activar App Check.
4. Auditar el aislamiento por cuenta de los demás módulos; Entrenamiento ya tiene
   namespaces y pruebas de cambios de cuenta, pero falta verificación nativa.
5. Verificar con Firebase real la transición invitado/cuenta. La decisión está
   tomada: mantener el historial de invitado separado, sin importación automática.
6. Implementar exportación, importación, eliminación de cuenta y privacidad.
7. Completar los `TODO`/“Próximamente” reales en workout, nutrition, perfil,
   settings e integraciones.
8. Implementar handlers nativos para las integraciones de salud.

## Próximo orden recomendado

1. Revisar Entrenamiento en Android e iPhone reales siguiendo el informe del
   12/10; validar lectores de pantalla, teclado, rendimiento y segundo plano.
2. Validar Firestore con emuladores: los tests actuales usan dobles de contrato;
   timestamps del cliente aún pueden omitir escrituras tardías con fecha antigua.
3. Revisar los cambios previos pendientes de otros módulos antes de publicarlos;
   conservar cambios ajenos. Configuración Firebase y firma siguen abiertas.
4. Android físico aplazado por el usuario; no bloquea el trabajo anterior.

Flutter 3.47.3 actualizó `platform` a 3.2.0 e `image_picker_android` a
0.8.13+23. `material_color_utilities 0.13.0` y `test_api 0.7.12` siguen fijadas
por el SDK; no son dependencias directas actualizables desde esta app.

Actualizar este archivo sólo cuando cambien validaciones, versiones, bloqueadores
o decisiones; no copiar logs completos.
