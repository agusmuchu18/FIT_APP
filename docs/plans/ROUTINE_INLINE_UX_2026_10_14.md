# Creador de rutinas · ajuste UX inline

Implementación real del encargo del 14/10/2026. Sustituye la apertura del
configurador desde el explorador; conserva la revisión, edición, guardado y
ejecución existentes. Base local: `2e274a3`.

## Interacciones entregadas

| Zona | Comportamiento |
|---|---|
| Miniatura, subtítulo y espacio del cuerpo | Expandir/contraer en la misma tarjeta |
| Nombre e indicador de información | Abrir `ExerciseTechnicalScreen` y volver conservando el explorador |
| Botón circular + | Agregar los parámetros válidos actuales; pasa a check sin expandir/contraer |
| Listo / Ver | Abrir revisión con el mismo `RoutineDraftController` |

Una sola tarjeta abierta. Movimiento de tamaño de 200 ms; sin animación cuando
el sistema solicita reducir movimiento. El scroll conserva un controlador estable
y ancla la cabecera tocada mientras se estabilizan las filas lazily construidas;
un gesto de desplazamiento cancela el anclaje. Una prueba reprodujo un salto de
407 px y verifica la posición tras corregirlo.

## Estado y configuración

`ExerciseConfigurationSheet` presenta los mismos campos en dos disposiciones:
inline para el explorador y modal para la edición desde revisión. Comparte
validación con `RoutinePlanValidation`; no hay otra implementación de las reglas
de series, repeticiones, cargas, descansos u objetivos deportivos.

- Antes de agregar: los valores válidos y las entradas incompletas se conservan
  temporalmente en memoria del explorador, por ID del catálogo.
- Después de agregar: cada modificación válida actualiza la instancia del
  borrador existente y su persistencia por cuenta.
- `ExerciseConfigurationMemory` conserva texto bruto, rangos, objetivos por
  serie y campos deportivos al contraer, filtrar o desmontar una fila fuera del
  viewport. Los `TextEditingController` de la fila se liberan al desmontarla.
- Los valores inválidos nunca sustituyen el último plan válido. Impiden agregar
  ese ejercicio o continuar con él seleccionado hasta corregirlo; no se descartan
  silenciosamente. Las entradas inválidas temporales no se persisten al cerrar
  por completo el explorador; sí se conserva el último borrador válido.
- La revisión sigue siendo la fuente de verdad de los ejercicios agregados.
  Al volver de ella se invalidan sus cachés de edición para leer los valores
  actuales. El descarte explícito de la selección limpia sus configuraciones.
- No hay botón de agregado dentro del desplegable. Las opciones por serie se
  agrupan en opciones avanzadas; permanecen disponibles y conservan sus valores.

La barra de selección ahora reserva espacio en la disposición de la pantalla;
no se superpone a los campos. Hay prueba con viewport 390×844 y teclado de 300 px.
A 320 px / texto 200%, selectores y acciones se reorganizan, los rótulos largos
quedan sobre los campos y los valores de carga pueden ocupar varias líneas.

## Ficha técnica y datos reales

La pantalla técnica reutiliza las seis ilustraciones específicas existentes y
el fallback de categoría para los demás ejercicios. Presenta descripción,
músculos, instrucciones, errores, consejos, alias, patrón y registro disponibles.
`domain/exercise_technique.dart` estructura las seis notas orientativas ya
existentes; no constituye una revisión profesional de técnica.

No se inventaron variantes ni instrucciones para los otros 291 ejercicios:
las secciones informan cuando no hay contenido revisado. La revisión técnica
profesional y completar esa cobertura siguen pendientes.

## Filtros visuales y taxonomía

`RoutineFilterArtwork` dibuja ilustraciones vectoriales de 40 dp en Flutter,
con fondo del tema azul noche, acento turquesa y sin texto/marcas incrustados.
No requiere paquetes, red ni decodificar nuevos bitmaps. Las zonas corporales
son representaciones esquemáticas regionales; no son diagramas clínicos ni mapas
de activación. Los objetivos no anatómicos usan símbolos propios y cualquier
categoría desconocida dispone de un fallback consistente.

`RoutineFilterSheet` conserva selección múltiple, aplicar, limpiar, cancelación
sin aplicar y las claves originales. Cada fila completa es táctil, con checkbox,
estado seleccionado y material local que impide pintar fuera de la lista.

- Músculos: secciones **Grupos musculares** y **Categorías y objetivos**.
  Cardio, estabilidad, movilidad y cuerpo completo pertenecen a la segunda.
  Zona media y piernas se conservan como agrupaciones/regiones anatómicas.
- Equipamiento: sección **Equipamiento** y sección **Patrones de movimiento**.
- `medicine_ball` → Balón medicinal; `rope` → Cuerda;
  `sled` → Trineo de entrenamiento; `carry` → Transporte con carga.
- Las traducciones de equipamiento, músculos y patrones están centralizadas en
  `RoutineLabels`. El catálogo conserva 297 IDs y sus asociaciones.

**Inconsistencia documentada:** `farmers_walk` y `suitcase_carry` almacenan
`equipment: carry`, que describe un patrón y no un objeto. Se conserva el filtro
heredado y se identifica visualmente como patrón. Una migración futura debería
separar patrón y equipamiento real, tras revisar los objetos admitidos por cada
ejercicio. Este encargo no cambia sus claves persistidas ni inventa equipamiento.

## Regresiones encontradas al verificar

1. La vista previa podía asignar 30 s a movimientos de repeticiones; el resultado
   válido ya no convierte esos ejercicios en ejercicios por tiempo.
2. La reducción de movimiento omitirá directamente `AnimatedSize`: usar duración
   cero provocaba una excepción de layout en el SDK instalado al cambiar tamaños.
3. Corregido el salto al cambiar de tarjeta expandida, con prueba de animación.
4. Corregidos footer y campos recortados con texto al 200%.
5. Las filas seleccionadas de filtros pintaban detrás de su cabecera al hacer
   scroll; ahora tienen un `Material` propio y recorte local.
6. El ensayo completo reveló que Home comparaba fechas UTC con el calendario
   local. Ahora convierte la fecha guardada a local antes de decidir si hubo
   sesión hoy; pruebas de sesión actual y de hace dos días.

## Verificación reproducible

- `test/features/workout/routine_inline_ux_test.dart`: 18 casos de expansión,
  memoria, navegación, + independiente, actualización/persistencia/revisión,
  errores, filtros múltiples/aplicar/limpiar/cancelar, traducciones, fallback,
  teclado, lazy list, anclaje con movimiento, objetivos por serie, contraste y fútbol.
- `test/training_home_screen_test.dart`: dos regresiones adicionales UTC/local.
- `test/goldens/routine_inline_golden_test.dart`: cinco casos y nueve capturas
  nuevas de inline, texto ampliado, controles, ficha, filtros y sus ilustraciones.
- Actualizadas las pruebas anteriores que esperaban agregar desde el modal.
- Revisión visual en dos pasadas: jerarquía compacta, lectura de campos a texto
  ampliado y recorte de los estados seleccionados al desplazar filtros.
- Resultados finales de suite/análisis/compilación: `../CURRENT_STATUS.md`.
  Los logs completos permanecen en `build/routine_inline_*.log` y no se versionan.

**Cierre verificado:** 195/195 pruebas aprobadas; `flutter analyze --no-pub
--fatal-infos` sin problemas; `flutter build web --release --no-pub --base-href
/FIT_APP/` aprobado (incluido dry run Wasm, sin ejecución ni publicación Wasm).
Los 26 casos focalizados de inline/Home/recorrido también aprobaron. Se verificó
contraste ≥4,5:1 en texto seleccionado de filtros, texto de superficie y glifo
de la acción primaria. Se prueba el tema de Entrenamiento, que fuerza oscuro
tanto sobre un contenedor claro como oscuro; no se certifica un tema claro nuevo.

Rama local: `codex/routine-inline-ux-20261014`. La corrección de calendario está en
`e72d38f`; el ajuste UX y su QA se conservan en un commit posterior de esta rama.
No se modifican dependencias, esquema histórico ni claves del catálogo. El cambio
previo de assets de nutrición y el trabajo ajeno siguen fuera de estos commits.

No se ejecutó el cambio en Android ni iPhone ni con TalkBack/VoiceOver nativos.
El perfilado en dispositivo sigue pendiente; construir sólo las filas visibles
no equivale a demostrar métricas de rendimiento en hardware. Figma no se modifica.

## Aceptación manual

1. Buscar un ejercicio y tocar su miniatura/cuerpo; debe desplegarse sin modal.
2. Cambiar series/rango/carga/descanso y objetivos por serie. Contraer, abrir otro
   ejercicio y volver: conservar los valores.
3. Tocar +: agregar esos valores sin cerrar la tarjeta; no permitir duplicados.
4. Cambiar un valor agregado y pasar a revisión: comprobar el objetivo nuevo.
5. Escribir un valor inválido: conservar el último válido y exigir su corrección.
6. Abrir la ficha desde el nombre y volver: mantener filtros, búsqueda y scroll.
7. Combinar dos equipos y dos músculos; aplicar, volver a abrir, limpiar/aplicar.
   Probar también cerrar sin aplicar: mantener la selección anterior.
8. Repetir con teclado, texto 200% y reducción de movimiento; alcanzar el último
   control sin que quede tapado por la barra. Completar el recorrido hasta historial.
