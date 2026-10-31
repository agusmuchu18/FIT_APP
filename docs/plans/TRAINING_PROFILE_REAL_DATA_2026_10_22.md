# Entrenamiento en Perfil · datos reales y carga diferida

Corte: 22/10/2026. Continuación del commit local `e02bcfb` y de
`TRAINING_EXPANSION_2026_10_17.md`. Fuente: carpeta local de FIT_APP.

## Resultado

- Cabecera: entrenamientos históricos guardados, series y días de los últimos
  30 días, y última marca vigente con unidad y procedencia del índice existente.
- Estadísticas: frecuencia por semana calendario, volumen externo, tiempo
  registrado y duración media comparable de los últimos 30 días. No se infiere
  peso, sueño ni recuperación a partir de estos datos.
- `WorkoutProfileSummary` reutiliza `TrainingPerformanceIndex` y
  `TrainingStatistics`. El total histórico cuenta informes canónicos sin repetir
  el cálculo muscular de todo el historial. No se añade almacenamiento ni motor.
- El índice conserva sus reglas: datos futuros excluidos, cargas comparables,
  resultados legados sin confirmación diferenciados, volúmenes parciales
  explícitos y media sólo con criterios de duración compatibles.
- Carga, ausencia de datos y fallo de lectura tienen estados distintos. Un error
  muestra valores desconocidos y permite reintentar; no equivale a cero sesiones.
- Cambios de historial actualizan cabecera, estadísticas y PRs desde la misma
  cuenta. Resultados tardíos de otra cuenta se descartan.
- `MainShell` indica cuándo está seleccionada la pestaña Perfil. Sus nuevas
  lecturas/agregaciones y las de PRs se difieren mientras no lo está. Las
  revisiones pendientes se reúnen al volver; también se comprueba el día local.
- Cambiar unidades convierte la presentación sin leer de nuevo el historial ni
  reescribir resultados. Cambiar de pestaña conserva los filtros de PRs.
- Encabezado con altura natural, desplazamiento coordinado y pestañas opacas
  fijadas. Listas lazy; blur limitado al encabezado. Los valores y unidades se
  separan visualmente, con reflujo a 320 px/200% y movimiento reducido.

## Aceptación comprobable

1. Fixture de cuatro sesiones: 4 entrenamientos, 4 series y 4 días recientes,
   1.720 kg·rep, 80 min registrados y media de 20 min; marca de 57,5 kg enlazada
   al registro real. Ninguna cifra proviene de las tarjetas de demostración.
2. Historial vacío: contadores cero, marca desconocida y duración sin registro.
3. Una lectura fallida: estado de error y reintento; no mostrar historial vacío.
4. Eliminar/corregir resultados invalida la fuente y actualiza Perfil y PRs.
5. Cambiar de dueño con lectura pendiente no publica resultados del dueño anterior.
6. Unidades, filtros y pestañas no originan lecturas ni conversiones persistidas
   innecesarias. Perfil/PRs inactivos no solicitan el índice.
7. Cabecera y métricas se pueden recorrer con texto al 200%; no hay overflow ni
   contenido oculto bajo el blur o las pestañas.

Pruebas: `test/features/workout/workout_profile_summary_test.dart` (11 casos) y
`test/goldens/profile_training_golden_test.dart` (2 casos, 3 capturas revisadas).
Las capturas pobladas usan fixtures identificables; no son datos del usuario.

## Evidencia y límites

Los resultados finales de suite, análisis y builds se registran en
`docs/CURRENT_STATUS.md`. Logs: `build/profile_training_final_*.log`.
Resultado: 260/260 pruebas aprobadas, análisis estricto sin incidencias, APK
debug y web release compilados. Recorrido web local completado el 23/10: Perfil
con historial vacío, estadísticas, PRs, desplazamiento completo, acceso al análisis
y regreso conservando la pestaña. No se crearon sesiones ni se usaron datos de
una cuenta externa. Evidencia visual: `browser-profile-statistics-20261023.png`
en los artefactos locales de esta conversación. Los escenarios poblados,
errores de lectura, cambios de cuenta y unidades se comprueban en tests de host.
La validación corresponde a la carpeta local actual con trabajo previo ajeno;
no certifica un checkout limpio de todos esos cambios.

Se preservan las imágenes/identidad y el trabajo previo de Perfil, Ajustes,
nutrición y navegación. Las fotos e identidad de demostración existentes no se
convierten en registros reales mediante esta entrega. No se modifican credenciales,
Firebase, navegación principal ni datos persistidos del usuario.

Continúan los pendientes externos/de producto del plan principal: ejecución y
perfilado Android/iPhone, compartir nativo, identidad/firma de tienda, conexión
global de Clásico/Pink y cobertura/revisión de imágenes y técnica. No se declara
el producto listo al 100% para una tienda.
