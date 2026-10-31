# Auditoría de contexto para sesiones de coding

Fecha: 2026-09-27. Alcance medido: `lib/**/*.dart` (145 archivos,
42.066 líneas). Los cuatro archivos más extensos reúnen 8.171 líneas
(19,4 %): `exercise_library.dart` (3.021), `workout_pro_screen.dart`
(2.092), `home_summary_screen.dart` (1.719) y
`nutrition_home_screen.dart` (1.339). La biblioteca de ejercicios contiene
principalmente definiciones de datos; las otras tres concentran UI y estado.

El tamaño del repositorio **no equivale** por sí solo a tokens consumidos por
una sesión. El costo depende de lo que el asistente y sus herramientas carguen
en el contexto y de sus límites de servicio. No hay una medición del prompt ni
de la cuota de la herramienta de Vibe Coding usada por el usuario; por eso no
se atribuye la interrupción de cinco minutos a una causa única ni se promete
un ahorro porcentual.

## Cambios de bajo riesgo aplicados

- `AGENTS.md` y `CLAUDE.md` indican empezar por un índice breve y leer sólo
  archivos/rangos pertinentes. `docs/CODEBASE_MAP.md` conserva la explicación
  textual; `FIT_APP.canvas` permite orientarse visualmente en Obsidian sin
  pegar el JSON en el chat.
- `tools/context.ps1` acota búsquedas por área y limita la salida a 30 líneas
  por defecto (máximo 80). Para una consulta puntual, usar
  `./tools/context.ps1 -Area home -Query HomeSummaryScreen -Limit 20`.
- Se preservó el código Dart. No se encontró una reducción de variables o
  definiciones que pudiera aplicarse masivamente sin verificar semántica,
  persistencia y pruebas; abreviar identificadores reduciría legibilidad sin
  demostrar una disminución útil de tokens de sesión.

## Regla operativa

1. Localizar con `CODEBASE_MAP.md` o `context.ps1`.
2. Leer rangos de los archivos implicados; seguir imports sólo si la tarea lo
   necesita. No imprimir `lib/`, el catálogo de ejercicios ni diffs completos.
3. Ejecutar primero la prueba del área y mostrar errores resumidos. Ampliar el
   análisis sólo cuando el cambio o un fallo cruce límites del módulo.

Para comprobar el efecto real en una herramienta de coding, comparar dos
sesiones de la misma tarea: tokens de entrada, texto devuelto por herramientas
y tiempo hasta agotar la cuota. Si la herramienta carga todo el repositorio
automáticamente, estas instrucciones no pueden impedirlo; habrá que cambiar
su configuración de indexación o contexto.
