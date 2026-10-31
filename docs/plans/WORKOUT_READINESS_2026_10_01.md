# Entrenamiento: revisión y cierre verificable

Fecha: 2026-10-01. Checkout: `D:\Datos User\Escritorio\fitness\fit_app`.
Continuación y preparación de integración móvil: 2026-10-02.
Complementa `WORKOUT_PROFESSIONALIZATION.md`. Estado: mejoras implementadas;
certificación móvil y preparación de publicación pendientes. No se declara 100 %.

## Fallos corregidos y evidencia

| Problema | Cambio aplicado | Comprobación duradera |
|---|---|---|
| El historial tardío reemplazaba series recién editadas | Se combina el antecedente con el estado actual, por ID | `workout_autosave_race_test.dart`: edición durante carga y dos altas simultáneas |
| El historial podía completar sobre un ejercicio eliminado o controlador destruido | Guardas de ciclo de vida y de identidad; una petición por ejercicio/catálogo | Mismo test: eliminación/dispose antes de respuesta |
| Volver cancelaba el debounce y perdía la última edición | Guardado esperado antes de volver; vaciado al pasar a segundo plano/dispose | Test de carrera y recorrido volver → reabrir → terminar |
| Fallos de almacenamiento se trataban como éxito | Escrituras de preferencias comprobadas, error visible y reintento | Fallo inyectado y recuperación de la edición más reciente |
| Un borrador ilegible se sobrescribía con una sesión vacía | La carga falla conservando el texto original | `workout_session_functional_test.dart`: JSON roto sin sobrescritura |
| Se podía editar/finalizar mientras seguía cargando | Estado de carga/error y guardas en mutaciones | Controlador y widgets; no se finaliza una sesión sin series válidas |
| Configuración de sesión era un placeholder | Abre ajustes reales y recarga las preferencias al volver | Recorrido configuración → añadir ejercicio; descanso nuevo aplicado |
| No había pausa dentro de la sesión | Pausar/reanudar visible y persistente | Tests de pausa/rest; tiempo activo excluye pausa |
| Plancha y cardio temporizado exigían repeticiones | Segundos y objetivo de duración, JSON compatible, edición e historial | Rutina temporal → sesión → reapertura → historial; tipo funcional conservado |
| La asistencia inflaba el volumen externo | Campo separado `assistanceKg`, etiqueta explícita e historial compatible | Dominadas asistidas: 30 kg de asistencia, 0 kg de volumen externo |
| No se podía quitar una serie | Eliminación, renumeración estable y cancelación de su descanso | Test del controlador |
| Terminar no daba una confirmación útil | Resumen con series, tiempo activo y volumen externo | Recorrido completo de widgets hasta volver a la pantalla de origen |
| Un cierre parcial dejaba Home y el historial distintos | Sesión rica canónica; intención de cierre y reparación idempotente al arrancar | Fallo de proyección → reinicio/reparación; sin duplicados ni borrado de otro borrador |
| Invitado y cuentas compartían datos de entrenamiento | Preferencias, Hive, observadores y cola independientes; navegación reconstruida | Invitado/A/B, escrituras tardías, reapertura de Hive y restauración tardía |
| Guardar rutinas concurrentemente perdía una de ellas | Cola por propietario y bloqueo del doble envío en creación | Dos repositorios guardando simultáneamente; flujo de creación existente |
| Doble toque podía abrir dos sesiones | Guarda de navegación mientras se abre una sesión | Conflicto de borrador y guardas de flujo |
| Búsqueda de sesión sólo aceptaba el nombre literal | Índice compartido: nombre, alias y músculos, sin sensibilidad a tildes | Flujos existentes de biblioteca; selección temporal por alias `plank` |
| Crear rutina arrancaba vacío | Catálogo visible, prioridad de variedad/recientes, páginas de 50 y alta rápida | Picker inicial y capturas visuales; filtros siguen disponibles |
| Entrenamiento no tenía foto en Nueva rutina | Asset generado `routine_builder.webp`, 960×960, 88.300 bytes | Registro de assets y captura de Training Home |
| Controles tapaban series y fallaban con texto grande | Barra inferior participa del layout; series/rest adaptables y valores completados legibles | 320 px, texto 200 %; capturas de sesión y edición |
| Con rutinas guardadas el encabezado desbordaba a 390 px | Controles del encabezado fluyen y tarjetas crecen con la escala de texto | Rutinas guardadas a 390 px y 320 px/200 %; recorrido completo compartido |
| El reloj reconstruía/reanimaba el gráfico cada dos segundos | Sólo actualiza el texto del reloj; pausa ticks en segundo plano; `RepaintBoundary` | Test: el painter mantiene identidad después de tres segundos |
| Búsquedas de catálogo y orden de historial repetían trabajo | Índice por ID, caché de antecedentes y una decodificación de fecha por fila al ordenar | Regresiones de métricas, historial/migración y 101+ sesiones |

## Propiedad, compatibilidad y recuperación

- Política elegida por el usuario: **invitado separado de todas las cuentas**.
  Los nombres originales permanecen como espacio de invitado. No se borran ni
  se importan automáticamente datos anteriores a una cuenta.
- Una cuenta usa un namespace derivado de su UID. Cada repositorio captura el
  propietario antes de las operaciones asíncronas: una escritura tardía de A
  no termina en B. El UID usado por sync queda ligado al repositorio/cola.
- `AccountSessionGate` retira las pantallas anteriores mientras restaura datos;
  una restauración tardía no vuelve a mostrar la cuenta anterior.
- Campos nuevos opcionales: duración/objetivo en segundos, asistencia y tipo
  de entrenamiento. Los JSON previos siguen leyéndose. El catálogo permite
  reconocer ejercicios temporizados/asistidos en borradores antiguos.
- El borrador sigue en preferencias; las sesiones ricas siguen en Hive. La
  reparación entre sesión rica y `WorkoutEntry` **no es una transacción**.
  Conserva el mismo ID, sólo añade proyecciones ausentes y limpia exclusivamente
  el borrador cuyo cierre ya consta en el historial.
- Tras guardar la sesión rica, el controlador bloquea ediciones y descarte
  mientras se reintenta la proyección. El reintento conserva fecha y duración.
- No se prometen aislamiento global de todos los singletons/features ni sync
  remoto de rutinas y sesiones ricas. Este corte protege Entrenamiento y las
  cajas de entidades centrales/cola que componen su repositorio.

## Validación de este corte

- Suite completa: **118/118 aprobadas**. `flutter analyze --fatal-infos`:
  **0 problemas**. Logs locales: `build/workout_full_test_results.log` y
  `build/workout_final_analysis.log`.
- Capturas revisadas: `test/goldens/workout_session_overview.png` y
  `workout_session_editing.png`; también Training Home y Crear rutina.
- Builds web release y APK debug comprobados. No se publicaron ni se firmaron
  artefactos de producción.
- Sólo se detectaron Windows, Chrome y Edge. `flutter emulators` no encontró
  imágenes AVD. No hubo ejecución móvil real.
- El usuario confirmó que por ahora no dispone de Android por USB ni Mac/Xcode.
- `integration_test/workout_local_journey_test.dart` prepara un recorrido local
  con pantallas reales, preferencias nativas y Hive: crear rutina → editar →
  volver/reabrir → pausa → cierre → proyección central → Home de Entrenamiento →
  historial. Usa un namespace único y limpia únicamente sus propios registros.
  No prueba Firebase, arranque completo de `main`, muerte del proceso ni permisos.
- El mismo recorrido pasó en host a 390×844 con Hive en disco y preferencias
  simuladas (`workout_device_journey_rehearsal_test.dart`). No equivale a una
  ejecución de `integration_test` en Android/iPhone. Instrucciones y alcance:
  `integration_test/README.md`.
- El entrypoint de integración compiló como APK Android debug. Se conservó
  separado como `build/app/outputs/flutter-apk/workout-integration-debug.apk`.
  Compilar el APK de prueba no significa que sus afirmaciones hayan sido
  ejecutadas en Android. El APK normal usa `lib/main.dart`.

## Pendientes para cerrar el 100 %

| Criterio | Trabajo/aceptación pendiente |
|---|---|
| Android real | Recorrer rutina → sesión → pausa/descanso → segundo plano → reapertura → cierre → historial/Home/Rachas; comprobar teclado, botón Atrás y cierre forzado |
| iPhone | Compilar en macOS/Xcode, ejecutar en simulador y equipo; validar Safe Area, teclado, navegación, suspensión y VoiceOver |
| Accesibilidad de plataforma | TalkBack/VoiceOver, foco, anuncios del descanso y objetivos táctiles en equipos reales; las pruebas de texto grande no los sustituyen |
| Rendimiento medido | Profile mode en ambos targets: frames/rebuilds, apertura de catálogo, scroll, escritura de series, memoria e historiales grandes; registrar valores antes/después |
| Persistencia bajo interrupción real | Matar proceso entre las escrituras, poco espacio y reapertura; verificar reparación sin pérdida. Revisar almacenamiento duradero del borrador y rutinas antes de producción |
| Identidad y cloud | Recorrido real Firebase con cuentas A/B/invitado y reglas desplegadas; definir sincronización remota de rutina/sesión rica entre dispositivos |
| Catálogo profesional | Instrucciones y media por ejercicio con fuente técnica validada/licencia; no se inventaron demostraciones biomecánicas para 297 movimientos |
| Métricas musculares | Aprobar metodología: el radar actual es estimado, agrupa el primer músculo principal y combina volumen externo con puntos de fallback; no mide activación muscular |
| Legado | Verificar borradores `pro_*` en instalaciones reales antes de retirar ese flujo/modelos. La continuidad se conserva |
| Publicación | Firma, entornos/configuración Firebase, políticas de privacidad, crash monitoring y revisión de release; migración del toolchain Android con sus warnings actuales |

Metas nutricionales, fuentes de datos e imágenes disponibles siguen siendo
dependencias del producto; no se resuelven cambiando el Design System.
