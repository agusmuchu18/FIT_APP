# Mapa para sesiones de coding

Abre la carpeta raíz `fit_app` como bóveda en Obsidian y luego `docs/ai/FIT_APP.canvas`. [JSON Canvas](https://jsoncanvas.org/spec/1.0/) es el formato nativo del mapa. Los nodos de archivo apuntan a rutas reales del repositorio; las flechas muestran las relaciones principales, no cada import.

Para Codex o Claude Code, el índice de texto es `docs/CODEBASE_MAP.md`. El Canvas se usa para orientación visual y no debe inyectarse como JSON en cada prompt. El script `tools/context.ps1` acota los resultados por área:

La medición del tamaño del código, el alcance de esta optimización y cómo comprobar su efecto están en `docs/ai/CONTEXT_AUDIT.md`.

```powershell
./tools/context.ps1 -Area home
./tools/context.ps1 -Area workout -Query WorkoutSessionController
./tools/context.ps1 -Area nutrition -Query FoodRepository -Limit 20
```

El script busca nombres de archivos cuando falta `-Query` y líneas coincidentes cuando se indica. No cambia el código.

## Cómo mantener el mapa

Cuando se mueva un punto de entrada o cambie una relación de módulos, actualiza primero `docs/CODEBASE_MAP.md` y luego el nodo o la flecha correspondiente del Canvas. No dupliques contratos completos de arquitectura, datos o diseño dentro del Canvas.
