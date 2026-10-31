# Nutrition 2.0 · auditoría F0

Fecha: 2026-10-29. Fuente: archivos locales de FIT_APP, rama
`codex/training-expansion-20261017`, HEAD `8c663cf`. El árbol ya contiene 212
entradas modificadas/no seguidas, incluidos avances USDA y Entrenamiento.
No se usa GitHub como sustituto de esta copia local.

La columna Estado corresponde a la inspección inicial, antes de este corte.
Las pruebas iniciales de Nutrición: 13 aprobadas; build web release aprobado.
Inspección estática no equivale a verificación de dispositivo o backend.

## Matriz funcional

Rutas relativas a `lib/features/nutrition/`, salvo indicación.

| Función / pantalla | Modelos / repositorio / fuente | Estado inicial | Evidencia, riesgo y acción |
|---|---|---|---|
| Home alimentación | `presentation/nutrition_home_screen.dart`; `NutritionDayRepository` | Defectuosa | Resumen usa preferencias globales y metas 2400/160/260/80 fijas; corregir origen antes de rediseñar |
| Registro y búsqueda | `FoodLogScreen`, `FoodLogController`, `FoodRepository` | Parcial | Borrador y debounce existentes; guardado durable en preferencias, sin proyección a Inicio |
| Diario / duplicar reciente | `LoggedMeal`, `RecentNutritionItem`; `nutrition_day_repository.dart` | Defectuosa | `duplicateRecent` crea una plantilla con proteína/carbs/grasa 0; no conserva snapshot |
| Inicio / Rachas / día | `core MealEntry`, `FitnessRepository`, Hive `fit_meals` | Defectuosa | Lee otra fuente; fecha inferida del ID; fallback recalcula desde catálogo por título |
| Analytics nutricional | `StatisticsService`, `NutritionMetrics` | Parcial | Historia nutricional en memoria; desaparece al recrear servicio; derivar desde comidas guardadas |
| Alimentos propios | `FoodItem`; `FoodRepository`; preferencias | Parcial | Test de reapertura aprobado; falta namespace por cuenta y protección de escrituras concurrentes |
| Catálogo offline | `offline_food_catalog.dart`, asset USDA Foundation | Funcional y verificada | 363 registros oficiales más semillas; tests offline/aliases aprobados. No es un catálogo argentino completo |
| USDA remoto | `FdcClient`, `FoodCache`, `fdc_mapper.dart`, Worker | Parcial | Cliente/proxy y dobles HTTP probados; este corte no demuestra llamada de producción ni todas las traducciones |
| Nutrientes ausentes | `MacroValues`, `nutrientAmount` | Defectuosa | Valores ausentes se convierten a 0; resolver en etapa B con semántica nullable/procedencia, sin inventar micros |
| Porciones | `DraftEntry`, `FoodUnit`, `FoodResultCard` | Parcial | g/ml/porción y test de edición; cantidad entera y ml sin base retorna 0. Decimales/conversiones fiables pendientes B |
| Plantillas/carpetas | `MealTemplate`, `TemplateFolder`; `TemplatesRepository` | Parcial | JSON durable, mover/favoritos/edición presentes; escrituras no verificadas y claves globales |
| Favoritos de plantilla | `MealTemplate.isFavorite` | Parcial | Persistido en lista compartida; no es favorito general de producto |
| Recientes/frecuentes | Diario + lista de recientes; recientes en memoria del controlador | Parcial | Lista kcal-only y duplicación defectuosa; no existe ranking real de frecuentes |
| Lite / Pro | `nutrition_screens.dart` | Parcial | `NutritionProScreen` delega a la misma Home; no se encontró un `NutritionLiteScreen` funcional independiente |
| Edición/eliminación de comida | Pantallas de borrador; diario | Parcial | Editar borrador no equivale a corregir/borrar comida histórica; completar en siguientes cortes |
| Metas | `core UserPreferences.targetCalories` | Parcial | Calorías configurables en modelo existente; no hay metas reales de macros ni historia de objetivos |
| Recetas | Plantillas con entradas / items | Parcial | Se pueden reutilizar ingredientes; faltan raciones/rendimiento/instrucciones y cálculos de cocción explícitos |
| Código de barras | `quick_add_placeholder_screen.dart` | Solo visual | No hay lector/product resolver de producción |
| Foto / texto / voz IA | Acciones rápidas y placeholder | Solo visual | Sin motor multimodal, consentimiento, backend ni cuotas; no afirmar reconocimiento funcional |
| Paywall | `paywall_sheet.dart` | Solo visual | No se encontró entitlement comercial que justifique bloquear Lite/Pro; no añadir nuevos cobros |
| Plan semanal/manual/automático | Sin entidad/servicio encontrado | Ausente | Debe separar planificado de consumido; no registrar propuestas como ingesta |
| Sustituciones/lista de compras | Sin servicio encontrado | Ausente | Agregar después de recetas/plan; no sumar unidades incompatibles |
| Hidratación | Hábitos/ajustes, sin diario nutricional de agua verificado | No verificada | Auditar punto de integración al llegar a G; no crear contador duplicado |
| Suplementos/notas/ayuno/asistente | No hay implementación nutricional completa encontrada | Ausente | Opcionales, privados; dependencias IA/permisos separadas |
| Sincronización | `core RemoteSyncService` para `MealEntry` | Parcial | El diario rico no la usa; proyección consolidada no equivale a sincronizar recetas/snapshots |
| Cuenta/invitado | `AccountSessionGate`, `ScopedPreferences` disponibles | Defectuosa | Nutrición aún no usa scope; separar con infraestructura existente, manteniendo legado global como invitado |
| Exportación nutricional completa | Accesos generales de configuración | No verificada | No afirmar exportación/importación rica con conflictos y medios sin probarla |
| Accesibilidad/temas/cámara/mic | Flutter/tema existentes | No verificada | Se requiere evidencia renderizada y móvil; no hay Android/iPhone disponible aportado por usuario |

## Referencia pública, no ingeniería inversa

Se consultaron el 29/10 las páginas oficiales de
[inicio](https://fitia.app/es/),
[funcionalidades](https://fitia.app/es/funcionalidades/) y
[registro](https://fitia.app/es/ayuda/articulos/registrar-comidas-fitia/).
Describen búsqueda/registro multimodal, metas, recetas, planificación y
seguimiento. Son capacidades declaradas públicamente, no funciones ensayadas
por este agente dentro de Fitia. No se adoptan sus afirmaciones comerciales de
precisión ni sus recursos propietarios.

`https://fitia.app/es/plan-de-comidas/` devolvió 404; el enlace de planificador
del sitio lleva al inventario de funcionalidades. No se identificó de forma
fiable la grabación Fitia de 2:54 entre los archivos de video locales listados;
no se afirma haber visto su contenido. Se debe identificar antes del diseño C.

## Decisión F0 → primer corte seguro

Consolidar el diario en el **NutritionDayRepository existente**, usando Hive
por cuenta; conservar copias legacy sin borrarlas, generar IDs idempotentes y
proyectar a `MealEntry` con snapshot/fecha explícita. Reutilizar `FoodRepository`
como catálogo y `TemplatesRepository` como plantillas, sin tercer diario.
Corregir repetición, separación por dueño, errores de persistencia, metas
inventadas y lectura de Inicio/Analytics. El rediseño completo, nutrientes
opcionales, fuentes nuevas y multimedia pertenecen a los siguientes bloques.
