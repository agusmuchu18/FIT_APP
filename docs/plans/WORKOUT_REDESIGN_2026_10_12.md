# Rediseño integral de Entrenamiento

Fecha: 2026-10-12. Fuente del encargo: prompt maestro adjunto del usuario.
Diseño oficial: `docs/design/DESIGN_SYSTEM.md`. Sin gamificación ni cambios en
alimentación, sueño o hábitos. Se preserva invitado separado de las cuentas.

## Fase 0 · informe previo a implementación

### Componentes y arquitectura inspeccionados

- Sesión v2: `application/workout_session_controller.dart`,
  `presentation/workout_in_progress_screen.dart`, `widgets/exercise_card.dart`,
  `set_row.dart`, `workout_in_progress_header.dart`, `rest_timer_banner.dart`.
- Reloj/pausa/descanso: marcas de inicio, pausa acumulada y comienzo de descanso
  en segundos transcurridos activos; singleton `workout_in_progress_controller.dart`
  conserva la mini-barra al salir. Pausar congela también el descanso.
- Datos: `domain/session_models.dart`, `pro/models/workout_models.dart`,
  `data/workout_repository.dart`, `workout_preferences.dart`, repositorio de rutinas.
- Hive guarda sesiones ricas por cuenta; preferencias guardan borrador, pausas,
  descanso y legado. Cierre v2 escribe historial y proyección central con ID estable;
  `workout_completion_recovery.dart` repara cierres parciales al arrancar.
- Legado Light/Pro: `pro/workout_pro_screen.dart`, `pro/providers/workout_pro_provider.dart`.
  Se conserva la reapertura del borrador legado; no se sustituye por una migración
  destructiva. Historial combina ambos formatos por ID.
- Historial/detalle comparten actualmente `training_home/workout_history_screen.dart`.
  Rutas se componen en `lib/main.dart`; Home y Rachas consumen `WorkoutEntry`.
- Inter local, `AppTheme.workout`, `AppColors`, `FitGlyph`, fuente de diseño oficial,
  radar existente y `fl_chart` son reutilizables. Tres fotos actuales siguen en
  entrada de Entrenamiento; el nuevo resumen/historial tendrá assets abstractos.

### Hallazgos demostrados

1. Finalizar está en el header y abre un modal de éxito; no hay resumen por ID.
2. La barra inferior da demasiado espacio a configuración/descarte.
3. El selector muestra simultáneamente `90s` y un campo `Seg 90`.
4. La lectura de sesiones ricas omite `durationSeconds`, aunque ya se persiste.
5. Cierre, radar y pantallas calculan métricas en sitios distintos. El radar mezcla
   kg×reps con puntos de peso corporal: unidades incompatibles.
6. El detalle oculta las series pendientes; tampoco permite repetir la estructura.
7. Historial no tiene filtro, agregación, gráfico ni comparación.
8. El parser legado convierte `weight` en `externalLoadKg` sin distinguir ambigüedad.
   No es seguro inferir masa corporal, asistencia o lastre desde ese campo.
9. Guardado Pro genera UUID por llamada y carece de transición terminal idempotente.
10. Fechas ilegibles pueden sustituirse por `DateTime.now()`: no deben inventarse.

### Decisiones compatibles y cambios de modelo mínimos

- Adaptador de presentación/agregación único, sin reescribir registros históricos.
- Segundos, naturaleza de duración, inicio/tiempo total y referencia de repetición
  opcionales. Sesiones anteriores siguen leyéndose; una duración vieja sin semántica
  documentada se presenta como registrada. El reloj v2 excluye pausas e incluye descansos:
  no representa tiempo efectivo de ejercicio.
- Peso legado ambiguo conserva su cifra y procedencia; se excluye de carga externa
  confirmada y de comparaciones porcentuales de carga.
- Distribución muscular: proporción de series registradas válidas, repartidas entre
  grupos principales conocidos del catálogo. Sin mezclar kg con puntos. Se etiqueta
  como estimación de catálogo, nunca como activación fisiológica.
- Comparación conservadora: misma modalidad y estructura de ejercicios/tipos de
  medición/carga; preferir misma rutina. No porcentaje contra cero ni datos ausentes.
- Repetir usa ID nuevo y series sin completar; conserva referencia al original y
  solicita decisión ante un borrador activo. No altera sesiones ni rutinas originales.

### Riesgos y límites

- 214 cambios previos sin commit en la carpeta original. Conservar cambios ajenos
  y trabajar en rama dedicada; nunca resetear la base ni publicar automáticamente.
- No hay dispositivos móviles disponibles según respuesta del usuario. La evidencia
  anterior: 118 tests host, análisis y builds; no acredita Android/iPhone físicos.
- Campos adicionales deben propagarse en todos los serializadores y dobles de test.
- Navegación terminal debe reemplazar sesión por resumen y bloquear doble envío.
- Legado desconocido/incompleto necesita estado explícito, no datos fabricados.
- Nuevos gráficos tienen que renderizar cero sin barras ficticias y responder a
  texto grande, lectores de pantalla y reducción de movimiento.

### Etapas y comprobación

1. Auditoría/documentación (este informe) y rama específica.
2. Sesión: acción contextual, confirmación previa y descarte protegido.
3. Descanso: selector único, presets, edición válida, banner compacto.
4. Datos/cálculos: adaptador único, duración exacta, cierre por ID y compatibilidad.
5. Resumen: sesión persistida por ID, hero, métricas, radar/comparación y navegación.
6. Historial: filtros persistidos, dashboard, barras dinámicas, agrupación y miniaturas.
7. Detalle: todas las series ordenadas/unidades/notas y repetición con ID nuevo.
8. Assets: inventario, generación abstracta local y fallback sin bloquear render.
9. QA: cálculos, carreras/guardado, descanso, navegación, fixtures visuales y
   320 px/200 %, suite/análisis/builds y límites móviles explícitos.

Pruebas existentes reutilizables: guardado/carreras, pausa, descanso, aislamiento,
proyección, migración, edición de rutinas/series, recorrido local y goldens.
Nuevas necesarias: agregaciones/fechas límite/comparación/cero, resumen por ID y
error, cierre anticipado/completo/doble toque, presets, detalle parcial, repetir,
historial vacío/filtro/error/muchas sesiones y recursos ausentes.

## Registro de implementación y entrega

## A. Resumen de implementación

Se implementó el recorrido sesión → confirmación → registro persistido → resumen
→ historial/detalle → repetición. La decoración comparte datos y cálculos con el
registro original. Se conservaron la identidad Dark Premium/Inter/turquesa, la
entrada fotográfica y los flujos anteriores de rutinas y Light/Pro. No se editó
Figma ni se añadió gamificación.

- El header activo contiene volver y «Tu sesión». La acción principal inferior
  agrega ejercicios hasta completar las series válidas; luego ofrece finalizar.
  El menú permite finalizar anticipadamente, configurar o descartar con protección.
- La confirmación previa muestra duración, ejercicios y series, y advierte sobre
  pendientes. Guardar conserva un ID estable y reemplaza la ruta por el resumen;
  no aparece un modal de éxito redundante.
- Descanso tiene un único m:ss, activación, +/-15 s, presets 30/45/60/90/120 y
  edición entre 1 y 3.600 s. Apagar conserva la configuración. El banner ofrece
  +30 s/Saltar. Pausa congela el tiempo; la recuperación calcula por marcas de
  tiempo, sin valores negativos ni depender de contar ticks.
- El resumen resuelve el ID guardado y muestra hero decorativo de 200, fecha real,
  estadísticas, radar estimado, comparación compatible, serie destacada y ejercicios.
  Hay estados de carga, error/reintento y registro no disponible.
- Historial ofrece 7 d/30 d/3 meses calendario/todo, filtro recordado por cuenta,
  frecuencia explícita, volumen externo y duración disponibles, barras semanales
  con cero real, meses/años y tarjetas con miniaturas. El agregado se calcula al
  cargar/filtrar y la lista crea filas visibles bajo demanda.
- Detalle muestra series completas, pendientes o parciales en orden, unidades,
  descanso, notas y referencia de origen. Repetir crea una sesión nueva y exige
  una decisión si existe borrador; un cierre pendiente no se reemplaza.
- Se corrigió también «Guardar borrador» en Pro: ahora guarda el borrador sin
  registrarlo como entrenamiento finalizado. Su cierre tiene recuperación por ID.

## B. Archivos y responsabilidades

Las rutas de esta sección son relativas a la raíz real del repositorio:
`D:\Datos User\Escritorio\fitness\fit_app`. El primer commit contiene además el
checkpoint de cambios anteriores autorizados de Entrenamiento que todavía no
tenían commit; no son todos cambios nuevos del 12/10. La lista exacta se obtiene
con `git show --name-status 411a72d`.

| Archivo, dentro de `lib/features/workout/` | Responsabilidad |
|---|---|
| `application/workout_session_controller.dart` | Identidad, pausa, validación, cierre estable, persistencia y acción contextual |
| `application/workout_completion_recovery.dart` | Reparación idempotente de proyección y cierre pendiente rico/Pro |
| `application/workout_repeat_service.dart` | Borrador nuevo, referencia y protección del borrador existente |
| `data/workout_repository.dart` | Lectura compatible, escritura por ID, preservación de filas y duración exacta |
| `data/workout_preferences.dart` | Preferencias del módulo por cuenta, checkpoint anterior |
| `domain/session_models.dart` | Contrato de sesión/series y compatibilidad de objetivos, checkpoint anterior |
| `domain/workout_analytics.dart` | Cálculos únicos, periodos, distribución, categorías y comparaciones |
| `domain/workout_live_metrics.dart` | Adaptación de métricas activas al cálculo compartido |
| `presentation/workout_in_progress_screen.dart` | Sesión, menú, confirmación y navegación posterior |
| `presentation/workout_summary_screen.dart` | Resumen completo por ID persistido |
| `presentation/workout_history_detail_screen.dart` | Detalle íntegro y repetición protegida |
| `presentation/widgets/workout_session_action_bar.dart` | Acciones inferiores adaptables a texto ampliado |
| `presentation/widgets/workout_rest_selector.dart` | Selector único, presets y validación |
| `presentation/widgets/rest_timer_banner.dart` | Descanso contextual, lifecycle, extensión y salto |
| `presentation/widgets/workout_report_widgets.dart` | Hero, métricas, radar, comparación y series compartidos |
| `presentation/widgets/exercise_card.dart` | Integra selector único en el ejercicio activo |
| `presentation/widgets/workout_in_progress_header.dart` | Métricas/gráfico activos y disposición adaptable, checkpoint anterior |
| `presentation/widgets/radar_chart_painter.dart` | Semántica y representación del gráfico activo, checkpoint anterior |
| `presentation/widgets/set_row.dart` | Edición/validación accesible de series, checkpoint anterior |
| `pro/models/workout_models.dart` | Campos opcionales de tiempo, origen, descanso y ambigüedad legado |
| `pro/providers/workout_pro_provider.dart` | Guardado recuperable, borrador real, pausa y propietario capturado |
| `pro/workout_pro_screen.dart` | Conserva Pro y abre resumen tras cierre; errores/reintento |
| `pro/widgets/workout_bottom_bar.dart` | Finalizar, guardar borrador y pausa separados y adaptables |
| `pro/widgets/exercise_card.dart` | Unidades/validación y presentación Pro, checkpoint anterior |
| `pro/widgets/template_section.dart` | Presentación de plantillas Pro, checkpoint anterior |
| `pro/widgets/workout_type_selector.dart` | Selector de modalidad Pro, checkpoint anterior |
| `pro/data/exercise_definition.dart` | Metadatos del catálogo y objetivos, checkpoint anterior |
| `pro/data/exercise_library.dart` | Catálogo e índice de búsqueda, checkpoint anterior reutilizado por reportes |
| `training_home/workout_history_screen.dart` | Dashboard, filtros, agrupación, lista y estados |
| `training_home/workout_settings_screen.dart` | Ajustes persistidos de entrenamiento, checkpoint anterior |
| `training_home/training_home_screen.dart` | Entrada fotográfica y navegación, checkpoint anterior |
| `training_home/training_home_widgets.dart` | Tarjetas/acciones y assets de entrada, checkpoint anterior |
| `training_home/training_home_controller.dart` | Carga de rutinas, historial y estados, checkpoint anterior |
| `training_home/routines_repository.dart` | Rutinas/metadatos por cuenta, checkpoint anterior |
| `training_home/routine_draft_controller.dart` | Borrador de rutina, checkpoint anterior |
| `training_home/routine_edit_screen.dart` | Edición de rutina, checkpoint anterior |
| `training_home/routine_search_screen.dart` | Búsqueda real de plantillas, checkpoint anterior |
| `training_home/routine_preview_screen.dart` | Vista previa de rutina, checkpoint anterior |
| `training_home/routine_review_screen.dart` | Revisión y guardado de rutina, checkpoint anterior |
| `training_home/folder_routines_screen.dart` | Carpeta y navegación de rutinas, checkpoint anterior |
| `training_home/template_exercise_picker_screen.dart` | Catálogo inicial visible y filtros, checkpoint anterior |
| `training_home/start_routine_flow.dart` | Inicio protegido ante borrador existente, checkpoint anterior |
| `workout_in_progress_controller.dart` | Estado global activo y reapertura del flujo correspondiente |
| `widgets/workout_mini_bar.dart` | Mini-barra de sesión, checkpoint anterior |
| `widgets/workout_mini_bar_host_overlay.dart` | Overlay válido y observación de rutas, checkpoint anterior |
| `widgets/now_playing_workout_chip.dart` | Acceso a sesión desde navegación, checkpoint anterior |

| Archivo o conjunto fuera del feature | Responsabilidad |
|---|---|
| `lib/main.dart` | Rutas resumen/detalle y bootstrap/aislamiento previamente autorizados |
| `lib/core/data/account_storage_scope.dart` | Namespaces y preferencias con propietario capturado |
| `lib/core/data/account_session_gate.dart` | Desmontar navegación anterior al cambiar cuenta |
| `lib/core/data/local_storage_service.dart` | Abrir cajas Hive por propietario |
| `lib/core/data/hive_sync_queue_store.dart` | Cola por propietario |
| `lib/core/data/repositories.dart` | Notificador de cambios de entrenamientos para consumidores |
| `lib/app/theme/app_theme.dart` | Tema de entrenamiento y tipografía local, con botones de mínimo 48 |
| `lib/features/common/theme/app_colors.dart` | Acento de entrenamiento aprobado, checkpoint anterior |
| `lib/features/common/theme/app_layout.dart` | Valores registrados de spacing/radio/movimiento/scrim |
| `lib/features/common/widgets/fit_glyph.dart` | Iconografía propia de entrenamiento, checkpoint anterior |
| `pubspec.yaml`, `pubspec.lock` | SDK/paquetes previamente actualizados, Inter y directorio de assets |
| `assets/fonts/Inter-Variable.ttf`, `OFL-Inter.txt` | Fuente local y licencia; sólo se retiró un espacio al final de línea |
| `assets/images/workout/` | Cuatro imágenes previas y diez nuevos WebP, inventariados en F |
| `tools/encode_workout_art.py` | Conversión/limitación de tamaño WebP sin sobrescribir originales |
| `assets/README.md` | Uso y procedencia de imágenes |
| `docs/design/DESIGN_SYSTEM.md` | Reglas oficiales y autorización posterior de implementación |
| `docs/design/WORKOUT_ASSETS_2026_10_12.json` | Inventario, dimensiones, bytes y procedencia |
| `docs/design/WORKOUT_ASSET_PROMPTS_2026_10_12.json` | Diez prompts exactos de generación |
| `docs/CODEBASE_MAP.md`, `docs/CURRENT_STATUS.md` | Contexto selectivo actualizado para futuras sesiones |
| Este plan | Auditoría previa, decisiones, evidencia y entrega A–J |
| `test/features/workout/` | Pruebas del feature: nuevos reportes/cálculos/descanso/repetición/Pro y regresiones anteriores |
| `test/support/workout_device_journey.dart` | Recorrido compartido actualizado al resumen por ID |
| `test/support/workout_report_fixture.dart` | Fixtures deterministas de registros y errores |
| `test/training_home_screen_test.dart` | Entrada e interfaz a 320 px/200% |
| `test/goldens/workout_*`, `training_home_*`, `routine_picker_*` | Pruebas y capturas visuales del alcance |
| `integration_test/workout_local_journey_test.dart`, `README.md` | Recorrido listo para ejecutar en dispositivo; limitaciones explícitas |

## C. Estado de funcionalidades y aceptación

«Completada» significa implementada y comprobada con la evidencia indicada; no
certifica comportamiento de plugins o rendimiento de un dispositivo no disponible.

| Funcionalidad | Estado | Evidencia / límite |
|---|---|---|
| Header y acción principal contextual | Completada | Prueba funcional de sesión; golden de edición/overview |
| Cierre anticipado y descarte protegido | Completada | Pruebas funcionales y estados de controlador |
| Confirmación, ID estable y resumen sin modal de éxito | Completada | Recorrido guardado/resumen/inicio y recuperación de proyección |
| Selector/presets/custom/off y banner +30/Saltar | Completada | Pruebas selector y reloj de descanso |
| Pausa y recuperación del descanso por timestamps | Parcial | Contrato comprobado en host; background/kill nativos pendientes |
| Resumen por ID, errores y ausencia de historial | Completada | Pruebas de reportes y cálculos + capturas |
| Radar con cero real, metodología y comparaciones | Completada | Test de escala absoluta 0–100 y comparabilidad; captura revisada |
| Dashboard, filtros por cuenta y meses/años | Completada | Fechas límite, filtro persistido, aislamiento y goldens |
| Historial grande | Completada en host | Fixture de 500 sesiones verifica creación diferida de filas; no prueba FPS nativos |
| Detalle íntegro y repetición | Completada | Series pendientes visibles, original intacto, IDs nuevos y borrador protegido |
| Light/Pro y guardar borrador | Completada en host | Pruebas de borrador, cierre fallido/reintento y recuperación |
| Assets y fallback | Completada | Diez WebP locales generados e integrados; capturas verificadas |
| Tamaño 320, texto 200%, movimiento reducido | Completada en host | Tests sin excepciones y golden compacto |
| TalkBack/VoiceOver y teclado de plataforma | Pendiente | Requiere ejecución móvil; semántica implementada no sustituye prueba real |
| Android | Parcial | APK debug compila; dispositivo/AVD no disponible |
| iPhone | Bloqueada por entorno | Sin Mac/Xcode/dispositivo; no se compiló iOS |
| Rendimiento de producción | Pendiente | Agregación única/lista lazy/assets acotados implementados; falta perfilado en hardware |
| Preparación para App Store | Pendiente | Firma, configuración nativa y criterios móviles no certificados |

## D. Validación ejecutada

Entorno usado: Windows, Flutter 3.47.3 / Dart 3.13.3. Resultado del corte final:

| Comando | Resultado real |
|---|---|
| `dart format` sobre archivos Dart cambiados | Formateados; sin errores al cierre |
| `flutter test --no-pub --reporter expanded` | **142/142 aprobadas** |
| `flutter analyze --no-pub --fatal-infos` | **0 problemas** |
| `flutter test --no-pub --update-goldens test/goldens/workout_reports_golden_test.dart` | Capturas actualizadas; comparación normal incluida en suite aprobada |
| `flutter build web --release --no-pub --base-href /FIT_APP/` | Éxito; `build/web`, dry run Wasm aprobado |
| `flutter build apk --debug --no-pub` | Éxito; `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --cached --check` | Sin errores en el commit de implementación |

Se ejecutaron primero pruebas focalizadas y después la suite. La última prueba
añadida valida que fl_chart no dibuje porcentaje positivo en ejes con cero.
Un error de sintaxis intermedio en esa prueba fue corregido; el resultado final
de 142 aprobadas corresponde al archivo corregido. No hay pruebas omitidas para
obtener ese resultado.

Los logs locales están en `build/workout_redesign_full_tests.log`,
`workout_redesign_analysis.log`, `workout_redesign_web_build.log` y
`workout_redesign_android_build.log`. `build/` es salida regenerable y no se
commitea. El APK debug final ocupa 188.542.144 bytes; no es un artefacto firmado
para distribución. La compilación web final tardó 46,9 s y Android 14,2 s.

La compilación Android advierte sobre futuras versiones mínimas de Gradle
(9.1), AGP (9.0.1) y Kotlin (2.3.20). Compila con el toolchain actual; su migración
es un cambio separado. Un build debug no demuestra fluidez ni corrección nativa.

La suite y los builds validan la **carpeta de trabajo actual**, que contiene
cambios previos de otros módulos. No se ejecutó un checkout limpio de los commits
de este rediseño. Se preservó en el working tree, sin incluir en el commit, la
entrada de asset USDA anterior de `pubspec.yaml` y los cambios de nutrición.

## E. Persistencia, compatibilidad y reglas de cálculo

- No se eliminó ni reescribió globalmente el historial. Los cierres hacen upsert
  por ID estable; un fallo entre historial/proyección/borrador se recupera con
  ese mismo ID. Pro persiste su snapshot pendiente antes de cerrar.
- Invitado y cuentas permanecen separados. Repositorios/preferencias capturan
  propietario antes de operaciones asíncronas; una respuesta tardía no transfiere
  datos a otra cuenta ni actualiza su mini-barra.
- Campos nuevos son opcionales: segundos exactos, tipo de duración, tiempo total,
  inicio, referencia de origen, descanso activado y carga ambigua. Se conservan
  serializadores y formatos antiguos sin convertir un dato desconocido en uno real.
- Fechas inválidas no se reemplazan con «hoy». Filas ilegibles se preservan, se
  excluyen del agregado y se informa su existencia; un contenedor corrupto produce
  error/reintento, sin sobrescribirlo con una lista vacía.
- `weight` legado sin tipo se conserva como carga ambigua. No se interpreta como
  kg externo ni como asistencia/peso corporal para inflar volumen. Un estado de
  serie ausente se muestra «Registrada», sin afirmar que fue completada.
- El volumen externo suma kg externos × repeticiones válidas registradas, excluye
  series pendientes y no mezcla asistencia, peso corporal o segundos. La unidad
  «kg × repeticiones» y las limitaciones se muestran al usuario.
- El tiempo nuevo mide transcurrido sin pausas e **incluye descansos**. No se
  presenta como tiempo efectivo de ejercicio. Datos anteriores mantienen duración
  registrada/declarada; desconocido no se transforma en cero. Agregados advierten
  si faltan tiempos o si mezclan tipos de duración.
- Distribución muscular estima proporción de series válidas según grupos primarios
  del catálogo; una serie reparte una unidad entre sus grupos conocidos. No mide
  esfuerzo, activación, recuperación ni fisiología. Si no hay grupos conocidos,
  muestra ausencia de datos. Radar tiene escala absoluta 0–100 y cero en el centro.
- Comparación busca un registro anterior con ejercicios/medidas/modalidad y estado
  de completitud compatibles, priorizando la misma rutina. Datos ambiguos se
  excluyen. No se calcula porcentaje frente a cero ni se afirma «mejora» automática.
- Serie destacada es la de mayor volumen externo registrado, con regla visible.
- Frecuencia del historial = sesiones incluidas × 7 / días calendario del periodo.
  7/30 días incluyen el día actual; 3 meses son calendario. Todo usa desde el
  registro más antiguo hasta hoy. Barras agrupan semanas desde lunes con cero real.
- Repetir conserva objetivos/unidades/descanso, genera IDs de sesión/ejercicio/
  series nuevos y deja las series sin completar. No copia duración/distancia ya
  realizadas; una carga ambigua requiere nueva entrada. El historial original
  permanece intacto. Reemplazar un borrador requiere decisión explícita.

Las pruebas usan carpetas Hive temporales/dobles de preferencias; no prueban
migración de una instalación móvil de producción ni fallos físicos de disco.

## F. Assets integrados

Los diez assets solicitados fueron generados con `image_gen` e integrados:

| Archivo en `assets/images/workout/` | Uso | Dimensiones | Bytes |
|---|---|---|---:|
| `summary_hero.webp` | Hero de resumen/detalle | 960×540 | 14.856 |
| `history_push.webp` | Empuje | Lado máximo 384 | 8.356 |
| `history_pull.webp` | Tirón | Lado máximo 384 | 10.618 |
| `history_legs.webp` | Piernas | Lado máximo 384 | 6.576 |
| `history_fullBody.webp` | Cuerpo completo | Lado máximo 384 | 6.148 |
| `history_arms.webp` | Brazos | Lado máximo 384 | 10.046 |
| `history_cardio.webp` | Cardio | Lado máximo 384 | 6.794 |
| `history_mobility.webp` | Movilidad | Lado máximo 384 | 6.844 |
| `history_mixed.webp` | Mixto | Lado máximo 384 | 8.980 |
| `history_empty.webp` | Historial vacío | Lado máximo 640 | 9.076 |

Total nuevo: **88.294 bytes**, WebP calidad 82. No queda ninguno de esos diez
pendiente de generación. Se conservaron `training_hero.png`, `session_strength.webp`,
`equipment_detail.webp` y `routine_builder.webp` anteriores. El PNG anterior de
~2 MB no se sustituyó en este corte; el ahorro informado corresponde a los diez
recursos nuevos y no al peso total de la app.

Las imágenes son decorativas: esculturas deportivas con ropa opaca y equipamiento,
sin atribuir resultados a una persona real. Si un recurso falta, un fallback
visual evita bloquear datos/navegación. El inventario conserva rutas originales,
dimensiones y tamaños; el archivo de prompts conserva las instrucciones exactas.
Los originales generados permanecen fuera del repo; los WebP de producción están
dentro. `tools/encode_workout_art.py` no sobrescribe assets ya existentes.

## G. Evidencia visual revisada

Capturas golden renderizadas por Flutter en host con fixtures, fuente y assets
locales cargados. **No son capturas de un Android/iPhone real ni sustituyen QA
nativo.** Se inspeccionaron las siguientes dentro de `test/goldens/`:

- `workout_session_overview.png` y `workout_session_editing.png`: sesión y edición.
- `workout_summary.png`: hero/fecha/métricas y radar con cero en el centro.
- `workout_summary_compact.png`: ancho 320 y texto 200%, métrica bajo la imagen.
- `workout_summary_wide.png`: ancho 900 y grid adaptado.
- `workout_history.png` y `workout_history_cards.png`: dashboard y lista enriquecida.
- `workout_history_empty.png`: vacío con ilustración local y acción.
- `workout_detail.png` y `workout_detail_sets.png`: detalle y series pendientes.
- `training_home_empty.png` y `routine_picker_default.png`: entrada y catálogo.

El fixture es deliberadamente comprobable: 40×10 + 40×12 = 880 kg externos;
una serie 40×8 pendiente no se suma; duración 24 min 34 s; dos grupos conocidos
al 50%. Esos números pertenecen al fixture de prueba, no al historial del usuario.

## H. Riesgos y pendientes reales

1. Sin Android conectado/AVD ni Mac/Xcode, tal como informó el usuario. Faltan
   ejecución Android/iPhone, background/kill/reapertura y plugins nativos.
2. TalkBack/VoiceOver, teclado real, contraste en pantalla y ajustes de accesibilidad
   necesitan validación de plataforma. Texto ampliado y movimiento reducido sí
   fueron comprobados en host. No se certificó tema claro.
3. Falta perfilado en modo profile de hardware móvil: FPS, memoria, energía y
   lectura/filtrado de historiales grandes. No se atribuye una mejora porcentual
   de rendimiento sin medición. El test de 500 sesiones sólo comprueba lista lazy.
4. Configuración/firma nativa/Firebase/identificadores de distribución anteriores
   siguen abiertas. No se generó release iOS ni se publicó una tienda.
5. La clasificación muscular depende de metadatos reales del catálogo. No se
   inventó anatomía de ejercicios desconocidos. Metas nutricionales, fuentes de
   datos y disponibilidad real de fotografías de ejercicios siguen siendo
   dependencias del producto, fuera de este rediseño.
6. Se preservaron los 214 cambios previos detectados al iniciar. El checkpoint
   incluye las mejoras anteriores autorizadas de Entrenamiento y sus dependencias;
   otros módulos continúan sin commit. Se necesita validación de checkout limpio
   antes de una entrega reproducible o publicación conjunta.
7. No se declara «100% App Store»: implementación y validación host/build están
   hechas; las comprobaciones móviles y de distribución siguen pendientes.

No se detectaron fallos pendientes en la suite final. Esto no equivale a afirmar
que no pueda existir ningún defecto fuera de los escenarios cubiertos.

## I. Rama y commits locales

Rama: `codex/workout-redesign-20261012`. Base preservada:
`9f61c68ff4a362d48f97265d300f7ae54de64edc`.

- `411a72d564c5c77a365d520d5f8a18bf37376adc` —
  `feat(workout): rediseñar sesión, descanso e informes persistidos`.
- Segundo commit: `test(workout): documentar y verificar el rediseño completo`.
  Su identificador se informa en la entrega y se consulta con `git log -2 --oneline`;
  no se embebe su propio hash en el archivo que forma parte de ese commit.

No hubo push, PR ni despliegue. Los dos commits separan implementación de QA/
documentación y permiten revisar/revertir cada conjunto. No se resetearon cambios
previos del usuario ni se incluyó su asset nutricional en el índice de este corte.

## J. Instrucciones para probar

En PowerShell:

```powershell
Set-Location -LiteralPath 'D:\Datos User\Escritorio\fitness\fit_app'
flutter pub get
flutter test --no-pub
flutter analyze --no-pub --fatal-infos
flutter run -d chrome
```

El build actual puede inspeccionarse localmente; se necesita dispositivo/Mac
antes de completar esta misma lista en Android/iPhone. Usar una cuenta/invitado
de prueba para no alterar un historial personal.

1. **Activa:** Entrenamiento → nueva sesión/rutina. Agregar dos ejercicios con
   varias series. Comprobar que el header dice «Tu sesión», el botón principal
   agrega ejercicios y los controles inferiores no cubren el último contenido.
2. **Descanso:** alternar off/on, elegir 45/90 s y custom válido; probar límites
   inválidos. Completar una serie, comprobar banner, +30, Saltar y pausa/reanudar.
   Salir de la ruta/reabrir y verificar persistencia. En dispositivo, mandar a
   segundo plano y comprobar tiempos reales; ese último paso sigue pendiente.
3. **Finalización:** completar todas las series para ver el botón principal
   finalizar. Probar también menú/finalizar anticipadamente: ver aviso de pendientes,
   cancelar y volver; después Guardar. Intentar doble toque/reintento sin duplicar.
   Descartar debe requerir confirmación y no crear historial.
4. **Resumen:** comprobar fecha, tiempo sin pausas, volumen externo, series y radar
   contra lo anotado. Sin sesión compatible anterior no debe inventar comparación.
   Abrir detalle y volver; «Volver al inicio» debe cerrar el recorrido activo.
5. **Historial:** alternar 7 d/30 d/3 meses/todo; reabrir para comprobar filtro
   recordado. Ver semanas sin sesiones en cero, meses/años, métricas y miniaturas.
   Probar cuenta sin registros y filtro sin resultados. Comparar con datos reales.
6. **Detalle:** abrir una sesión y revisar TODAS las series, incluyendo pendientes,
   valores/unidades, descanso y notas. Un peso legado ambiguo debe indicarse y no
   inflar volumen externo. Un registro desconocido no debe mostrar fecha inventada.
7. **Repetir:** repetir sin borrador; confirmar nueva sesión, todos los checks
   desmarcados, objetivos/rest y referencia, manteniendo intacta la anterior. Con
   borrador, comprobar cancelar/continuar actual/reemplazar. Con cierre pendiente,
   recuperar antes de repetir. En Pro, guardar borrador no debe crear historial.
8. **Accesibilidad:** repetir a ancho 320 y texto 200%, teclado abierto y movimiento
   reducido. En móvil probar TalkBack/VoiceOver y orientación/segundo plano.
9. **Dispositivo cuando esté disponible:** ejecutar
   `flutter test integration_test/workout_local_journey_test.dart -d <device-id>`.
   Para iPhone se requiere Mac/Xcode/configuración de firma; no es ejecutable en
   este Windows. El recorrido de integración no cubre todos los puntos nativos
   anteriores; mantener la matriz manual además de ese test.
