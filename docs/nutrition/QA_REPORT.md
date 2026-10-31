# QA · Nutrition 2.0

## Corte incremental B–H · 31/10/2026

Estado: **implementación parcial, verificada en host/web**. No es aprobación
global de todas las capacidades B–H ni de paridad con Fitia.

### Resultado ejecutado

| Control | Evidencia |
|---|---|
| Flutter analyze | 0 observaciones, `build/nutrition_bh_analyze_final.log` |
| Suite global | 435 aprobadas + 1 omitida; `build/nutrition_bh_full_tests_final.log` |
| Incremento sobre A | 39 regresiones permanentes nuevas; ninguna prueba se omite para ocultar fallos |
| Worker USDA | 5 aprobadas; `node --test worker/test/worker.test.js`; transporte inyectado de prueba |
| Web release | `flutter build web` aprobado; dry run Wasm aprobado; no es ejecución Wasm |
| Android | `flutter build apk --debug` aprobado; no ejecutado en dispositivo ni firmado para tienda |
| Navegador | Compilación local en 127.0.0.1:61252, invitado nuevo, datos sintéticos, 390 y 320 px |
| Widget tests | Coma/decimales/nulls a 320 px con texto 200 %, temas claro/oscuro y movimiento reducido; diario/recetas/planes, borrador reactivo y Analytics |
| iPhone / Android real | No verificados: sin dispositivos ni Mac/Xcode |

La prueba social omitida requiere emuladores y se conserva como tal; no se
ejecutó infraestructura social en este corte. Advertencia Android del toolchain
preexistente: SDK XML v4 frente a herramienta que conoce v3; build aprobado,
modernización y ensayo móvil pendientes. No se actualizaron dependencias.

### Funciones implementadas y reutilizadas

Se amplían MacroValues/FoodItem/DraftEntry, MealTemplate, FoodRepository,
TemplatesRepository y NutritionDayRepository; se conserva la cola por cuenta,
Hive, las preferencias y StatisticsService. Inicio y Analytics consumen la misma
proyección. No se reescribe Entrenamiento ni cambia la navegación principal.

- **B:** macros/micros nullable, decimales, procedencia, porciones verificadas y
  catálogo Foundation de 424 alimentos. 50 energías no reportadas quedan null.
  Se conservan los 363 IDs anteriores y snapshots históricos. Nuevos detalles
  USDA usan ficha completa; cliente y proxy piden energía Atwater y vitaminas.
- **C:** Diario/Recetas/Plan/Más dentro de Alimentación, fecha común, resumen,
  edición y cambio de tipo de comida, borrado con Deshacer, recientes, favoritos,
  frecuentes, alimentos propios editables y ficha ampliada. Tema existente con
  turquesa, Inter y tokens comunes; imagen editorial generada, WebP 268.054 bytes.
- **D:** texto con cantidades explícitas y selección confirmada, GTIN manual con
  checksum, producto exacto/caché y creación desde etiqueta. No se simulan IA ni cámara.
- **E:** recetas privadas con ingredientes/raciones/preparación/peso final opcional,
  registro de una ración, planificación manual con snapshot, confirmación idempotente,
  copia semanal sin superposición y lista de compras. Planificar no suma consumo.
- **F:** metas manuales con fecha y revisiones conservadas; períodos 7/30/90 en
  Analytics existente, tabla exacta y ausencias honestas. Gráfico semanal cabe en
  320 px; períodos largos y texto grande permiten desplazamiento explícito.
- **G:** notas y suplementos declarados por fecha, modo Lite/Pro privado y registro
  opcional de ventanas de ayuno; acceso al agua existente de Hábitos.
- **H:** JSON versionado con preflight, vista previa y confirmación; importación
  aditiva por ID, conflictos sin sobrescribir, sin credenciales. No hay atomicidad
  entre Hive y preferencias: un fallo de I/O requiere reintentar el mismo archivo.

### Recorrido real de navegador

1. Abrir origen de QA y continuar como invitado; diario vacío sin metas ficticias.
2. Guardar objetivos sintéticos manuales 2100/120/240/70 para 31/10 y comprobar resumen.
3. Elegir Hummus comercial USDA fdc:321358, porción de 33,9 g; ingresar 0,5 con coma.
4. Revisar 39 kcal, guardar receta «Hummus · prueba QA» y registrar el almuerzo.
5. Abrir Recetas: imagen editorial y receta persistida; planificar una ración.
6. Confirmar consumo explícitamente desde Plan: diario pasa de 39 a 78 kcal,
   P 2,5 / C 5,1 / G 5,8 g (presentación redondeada; snapshots precisos).
7. Eliminar la primera comida: total 39; Deshacer restaura 78 sin duplicados.
8. Abrir Analytics en 320 px. La primera revisión descubrió el día actual fuera
   del gráfico; se corrigió y se añadió aserción de posición visible de su etiqueta.
9. Reabrir el mismo origen con la compilación final y comprobar persistencia y
   gráfico corregido. La evidencia final se guarda junto a este documento.

La UI de exportación mostró «JSON copiado». El portapapeles virtual del navegador
automatizado no recibe el contenido escrito por Flutter, por lo que el recorrido
manual exportar→pegar/importar **no se declara aprobado**. Los tests de persistencia
y backup sí prueban estructura, restaura datos reales de fixture, duplicados,
conflictos, versiones y validación antes de escribir. USDA remoto se ensaya con
MockClient; no se declara conexión a producción ni despliegue del Worker.

Capturas sintéticas: [diario](evidence/bh-diary.png),
[recetas](evidence/bh-recipes.png), [plan](evidence/bh-plan.png),
[gráfico final 320 px](evidence/bh-analytics-320.png),
[diario reabierto](evidence/bh-reopened.png).

### Compatibilidad, fórmulas y revisión

Schema 3 lee filas 2/3 dentro del mismo box v2. Marcador de migración legacy 2
intacto; sin reset ni cambios de IDs. Ediciones archivan el original; borrados
son tombstones. Las revisiones de metas viajan en la copia; las revisiones internas
de comidas y planes retirados permanecen locales fuera de ese backup canónico.
No se activan preferencias de ayuno al importar historial.

Fórmulas y fuentes: NUTRIENT_CALCULATIONS y FOOD_DATA_SOURCES. No hay densidades
ni factores de cocción supuestos. Null no es cero; asistencia clínica y ajustes
dietarios automáticos no se infieren de estas métricas.

Revisión acotada: corregidas carreras de sugerencias, borrador sin escuchar cambios,
doble envío, ciclo de vida de diálogo, composición sin detalles confirmados,
copia semanal después de consumo, pérdida de revisión de meta, respuesta abreviada
USDA y desbordes de ficha/selector/gráfico. No se atribuye perfilado móvil a tests.

Archivos principales: dominio `models.dart`; datos `fdc_mapper`, `food_repository`,
`offline_food_catalog`, `nutrition_day_repository`, part `nutrition_workspace`,
`nutrition_backup_service`, `templates_repository`; aplicación `food_log_controller`;
UI `nutrition_home_screen`, `food_log_screen`, `food_result_card`, `meal_draft_sheet`,
editores/ayuno/texto/GTIN/comparador; proyecciones core/Inicio/Analytics; asset y
generador USDA; Worker y pruebas; pubspec solo por assets. Lista exacta y hashes
en `nutrition_bh_changed_files.json`, junto al parche de revisión de Codex.

### Pendientes y continuidad

La matriz canónica es IMPLEMENTATION_STATUS. Restan catálogo español/regional más
amplio y fuente argentina/OFF, escáner de cámara, foto/voz/asistente IA con backend
y consentimiento, planes automáticos/sustituciones, cálculo inicial confirmado,
ajustes/informes/CSV/PDF, hidratación profunda, recordatorios de ayuno,
sincronización rica, controles Material localizados, temas adicionales y pruebas
móviles/rendimiento. No se presentan como terminados.

Sin commits, push ni despliegues: rama `codex/training-expansion-20261017`, HEAD
`8c663cf`, con WIP anterior mezclado; índice Git intacto. El parche
`NUTRITION_BH_REVIEW.patch` compara con snapshot local del 30/10 y **no** debe
aplicarse ciegamente sobre Git HEAD. No sustituye assets binarios; el manifiesto
incluye sus hashes. El parche de A se conserva separado.

---

# Evidencia histórica · lote A

Fecha: 29–30/10/2026. No confundir las pruebas de esta etapa con aprobación global
de las funcionalidades futuras de Nutrition 2.0.

## Evidencia inicial

- 13 tests de Nutrición previos aprobados.
- Build web release inicial aprobado.
- Auditoría visual real a 390×844: 2400 kcal, macros 160/260/80 sin configurar,
  tarjeta de comida vacía alta y botones con apariencia de función pendiente.
- Captura: `evidence/before.png`. No se inspeccionó la grabación Fitia de 2:54.

## Primer corte

38 pruebas focalizadas finales aprobadas (`test/features/nutrition` y el test de actualización de Inicio). Incluyen la regresión previa de Entrenamiento. Análisis sin problemas.
Nuevas regresiones en `test/features/nutrition/data/nutrition_journal_test.dart`:
reapertura real de Hive, snapshots, repetición, migración repetida/corrupta,
reciente sin macros, IDs, concurrencia, cuentas/escrituras tardías, fallos y
conflictos de proyección, versión futura, preferencias, favoritos, equivalencias
ml inválidas y continuidad de Analytics. Los 2 widget tests nuevos comprueban
metas desconocidas y recuperación visible con los bytes corruptos intactos.

Superficie: tests de host/widgets Windows, Hive real temporal y preferencias
mockeadas; proyección simulada para fallos, repositorio central real para
reapertura de Analytics. No se probaron servicios remotos ni dispositivos físicos.
Regresión añadida tras revisar la precisión: dos snapshots de 4,5 g de grasa
proyectan 9 g al agregarse; JSON y cambios de metadata conservan los decimales,
mientras una corrección de macros invalida un snapshot anterior. Otra regresión verifica que un conflicto de 4,5 frente a 4,6 g no se oculte detrás del mismo entero redondeado.
Logs locales: `build/nutrition2_focused_tests.log`, `nutrition2_analyze.log`.

Suite completa: **396 aprobadas + 1 omitida** (contrato social con emuladores,
no ejecutado aquí). Web release y dry run Wasm aprobados; APK Android debug
compilado. El APK presenta avisos previos de Gradle/AGP/Kotlin y herramientas SDK,
que requieren mantenimiento coordinado y no impiden esta compilación.
Recorrido real de navegador local, invitado de prueba, a 390×844:

1. Se abrió el catálogo offline y una porción USDA de hummus (34 g).
2. Se agregó al borrador y se registró en el día: 78 kcal.
3. Recientes → Repetir: 156 kcal; proteína 5 g, carbs 10 g, grasa 12 g.
4. Se cerró la pestaña y se reabrió el mismo origen local: Inicio y Alimentación
   conservaron esos totales sin duplicación.
5. No se muestran porcentajes contra una meta ficticia; se retira el radar fijo
   decorativo que no representaba datos. No se afirma un rediseño integral.

Capturas: [antes](evidence/before.png), [diario](evidence/after.png),
[Inicio reabierto](evidence/reopened-home.png). Son datos sintéticos de QA,
no registros personales ni evidencia de sincronización con producción.
iOS/Android reales continúan pendientes. No hay pruebas
de reconocimiento IA/código/cámara porque esas funciones aún no se implementaron.

## Reutilización, modelos y migraciones

Se extienden `FoodRepository`, `TemplatesRepository`, `NutritionDayRepository`,
`MealEntry`, `FitnessRepository` y `StatisticsService`, sin repositorios paralelos.
Nuevo coordinador `NutritionWrites` para serializar escrituras por recurso/cuenta.
La migración v1→v2 conserva el original, IDs y snapshots. Es aditiva; no hay reset
ni migración destructiva. Los detalles y fórmulas están en ARCHITECTURE y
NUTRIENT_CALCULATIONS. USDA offline y cliente existentes permanecen; ninguna
IA, cámara o fuente comercial nueva se presenta como funcional.

## Archivos de código de este corte

| Área | Archivos relativos a la raíz de FIT_APP |
|---|---|
| Datos compartidos | `lib/core/data/repositories.dart`, `lib/core/data/statistics_service.dart`, `lib/core/domain/entities.dart` |
| Inicio | `lib/features/home/domain/home_activity_utils.dart`, `lib/features/home/presentation/activity_day_screen.dart`, `activity_module_day_detail_screens.dart`, `home_summary_screen.dart` |
| Nutrición · aplicación/dominio | `lib/features/nutrition/application/food_log_controller.dart`, `lib/features/nutrition/domain/models.dart` |
| Nutrición · datos | `lib/features/nutrition/data/food_repository.dart`, `nutrition_day_repository.dart`, `templates_repository.dart`, `nutrition_writes.dart` (nuevo) |
| Nutrición · UI | `lib/features/nutrition/presentation/food_log_screen.dart`, `nutrition_home_screen.dart` |
| Arranque | `lib/main.dart` |
| Pruebas | `test/support/nutrition_test_storage.dart` (nuevo), `test/features/nutrition/data/nutrition_journal_test.dart` (nuevo), `food_repository_persistence_test.dart`, `test/features/nutrition/presentation/nutrition_home_safety_test.dart` (nuevo), `test/features/home/home_workout_refresh_test.dart` |

Documentación nueva: los ocho documentos `docs/nutrition/*.md` y capturas de
`evidence/`; se actualizan CODEBASE_MAP, DATA_MODEL y CURRENT_STATUS.

## Git y revisión

Rama local `codex/training-expansion-20261017`, HEAD `8c663cf`. Al comenzar ya
había 212 entradas locales sin consolidar, con cambios previos mezclados en
varios de los mismos archivos. No se hizo commit de esos avances ajenos ni push
ni despliegue. Se mantiene intacto el índice Git.

El parche `NUTRITION_2A_REVIEW.patch` en el espacio de trabajo de Codex contiene
solo las diferencias de esta etapa respecto de la copia local de partida del
29/10. Sirve para revisión; no debe aplicarse ciegamente sobre Git HEAD, que no
contiene todos los cambios previos. El test de Inicio se reconstruye excluyendo
solo las adiciones conocidas de esta etapa. La lista exacta se guarda en
`nutrition2_changed_files.txt` junto al parche.

## Reproducción

Ejecutar desde la raíz: `flutter analyze`, `flutter test --reporter expanded`,
`flutter build web` y `flutter build apk --debug`. Para el recorrido usar un origen
local de prueba, entrar como invitado, agregar una porción USDA, registrar,
repetir desde Recientes, cerrar la pestaña y reabrir el mismo origen. Comparar
Inicio y Alimentación, incluidos macros. No utilizar datos personales para QA.

## Pendientes y dependencias

Lote B: nutrientes desconocidos distinguibles de cero, catálogo/procedencia en
español, cantidades decimales y porciones verificables. C–H siguen pendientes.
Sin ensayo móvil, iOS, cámaras, reconocimiento IA, integraciones remotas ni
perfilado de rendimiento. La sincronización rica y ediciones/eliminaciones
remotas requieren reconciliación propia, no están resueltas por esta proyección.
