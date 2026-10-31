# FIT_APP context router

Aplicar estas reglas a todo el repositorio.

Mapa visual para Obsidian: `docs/ai/FIT_APP.canvas`. Para contexto de texto
usar `docs/CODEBASE_MAP.md`; no volcar el JSON del Canvas en el chat.

## Regla principal

Minimizar contexto y salida: buscar antes de leer, abrir sólo archivos/rangos
necesarios, reutilizar lo ya comprendido y ampliar el alcance sólo por una
dependencia real. No releer ni reauditar globalmente sin una razón arquitectónica.

## Dónde buscar contexto

| Necesidad | Leer primero |
|---|---|
| Ubicar un feature, pantalla, controlador o test | `docs/CODEBASE_MAP.md` |
| Entender capas, arranque, estado o sincronización | `docs/ARCHITECTURE.md` |
| Cambiar entidades, JSON o persistencia | `docs/DATA_MODEL.md` |
| Firebase, USDA o integraciones nativas | `docs/INTEGRATIONS.md` |
| Saber qué funciona y qué sigue bloqueado | `docs/CURRENT_STATUS.md` |

Leer más de un documento sólo si la tarea cruza esos límites.

## Flujo de trabajo

1. Delimitar el feature.
2. Usar `rg --files`, `rg` por símbolo/import/ruta y referencias antes de abrir.
   `tools/context.ps1 -Area home -Query HomeSummaryScreen` limita la búsqueda
   y la salida a un área.
3. Leer rangos pequeños; seguir imports y llamadas sólo cuando sean relevantes.
4. Revisar cambios por archivo (`git diff -- <archivo>`), no con diffs globales.
5. Ejecutar primero tests focalizados; ampliar a análisis, suite y builds completos
   únicamente por riesgo transversal o para cierre.
6. Mantener stdout resumido y mostrar sólo detalles útiles de fallos.

Actualizar los documentos de `docs/` cuando cambie significativamente su verdad
técnica; mantenerlos compactos y sin duplicar el código fuente.
