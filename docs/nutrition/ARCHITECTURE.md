# Arquitectura nutricional

## Primer corte A · 29/10/2026

Se reutilizan los repositorios actuales:

```text
FoodLogController / plantillas / recientes
 -> NutritionDayRepository (diario rico canónico)
 -> Hive fit_nutrition_journal_v2[_scope]
 -> MealEntry con mismo ID y consumedAt (proyección existente fit_meals)
 -> FitnessRepository -> Inicio / Rachas / Analytics

FoodRepository -> catálogo offline / personalizados / USDA / caché
TemplatesRepository -> plantillas / carpetas / favoritos
```

No se agrega un tercer diario ni un motor de alimentos paralelo.
`NutritionWrites` ordena mutaciones por dueño/recurso entre instancias.
Los tres repositorios capturan `AccountStorageScope.current` antes de esperar;
alimentos propios, aprendidos USDA y plantillas usan `ScopedPreferences`.
Los datos globales históricos siguen perteneciendo al invitado; no se transfieren
a cuentas al iniciar sesión. El catálogo público empaquetado es inmutable.

## Persistencia y recuperación

- `LoggedMeal` incorpora UUID estable, snapshot agregado, título, método y origen.
  Cada entrada conserva un snapshot del alimento, su cantidad/unidad/equivalencia.
- La fila v2 conserva fecha civil serializada, instante UTC y offset capturado,
  creación y estado de proyección. No modifica la composición por cambios de catálogo.
- Migración v1: ID existente o determinista por día/posición; se escribe el marcador
  `__legacy_v1_complete=2` al final. Las preferencias originales no se borran ni
  continúan siendo una fuente editable. Un fallo no reinicializa Hive.
- Versiones futuras o nutrientes legacy incompletos se rechazan preservando el
  original. Nutrición ofrece reintento; el arranque conserva acceso a otros módulos.
- Un reintento de registro conserva ID/fecha. Mismo ID con otro payload no
  sobrescribe el registro anterior. Repetir voluntariamente crea otro UUID.
- La proyección se escribe después del diario; si falla queda pendiente durable,
  visible y recuperable al abrir/resumir la sección o arrancar la cuenta. No es
  una transacción entre almacenes. Si existe otro payload bajo el mismo ID se
  señala conflicto, sin pisarlo. Un replay idéntico no toca su revisión.
- Las comidas antiguas presentes solo en `fit_meals` se adoptan por ID; no se
  deduplican por título, calorías o una fecha aproximada. Su tipo no registrado
  se agrupa provisionalmente como snack, documentando el origen `legacyCore`.

## Consumidores

`MealEntry.consumedAt` y `nutritionSnapshot` son opcionales. Este último conserva
decimales; los campos enteros anteriores siguen siendo compatibles. Los cambios
de calorías/macros mediante `copyWith` invalidan el snapshot antiguo si no se
aporta uno nuevo, evitando datos obsoletos. Renombrar o tocar metadata lo conserva.
`recordedAt` usa el ID histórico parseable o
metadata original como fallback. Copy, tombstone y JSON conservan el campo.
Inicio usa snapshots (incluido cero real), escucha `mealsRevision` y ya no
recalcula alimentos comparando títulos. Calendario y detalle usan esa fecha.
Analytics mantiene sus APIs de `FitnessRepository` y reutiliza
`StatisticsService.summarizeNutrition` sobre comidas durables; el mapa en memoria
ya no es su fuente de verdad. Las sumas se hacen con decimales antes de redondear
en el límite de presentación heredado.

## Límites explícitos

No se implementó sincronización rica de recetas/diario ni resolución de ediciones
remotas posteriores. La proyección consolidada no equivale a sincronizar todos
los snapshots. Correcciones/eliminaciones remotas, exportación y cambios de zona
horaria deben verificarse integralmente antes de declarar ese soporte completo.
Las metas de calorías reutilizan `UserPreferences.targetCalories`; los macros
objetivo ausentes son null. El corte B–H añade edición e historial de metas manuales por fecha.

## Ampliación B–H · 31/10

`MacroValues` admite null explícito. Una suma con un dato desconocido permanece
desconocida para ese nutriente. Se conserva el cero real. `DraftEntry.quantity`,
`gramsOverride` y la equivalencia de porción aceptan decimales. Los datos nuevos
llevan schemaVersion 3 dentro del mismo box v2; se leen filas 2/3. El marcador de
migración legacy sigue siendo 2: no es la versión de cada fila.

`MealEntry.nutritionSnapshot` conserva nulls y `unknownNutrients` los distingue de
los enteros de compatibilidad. Los consumidores de Inicio/Analytics no presentan
esos enteros como datos completos. `NutritionMetrics` conserva la incompletitud.
La recuperación lee todas las proyecciones una vez por lote, evitando N lecturas
para N comidas pendientes.

`nutrition_workspace.dart` es un part de NutritionDayRepository; no se importa
por separado. Usa el mismo box y cola. Claves reservadas `__goal:`, `__plan:`,
`__note:` y `__fast:` se separan del diario consumido. Los planes son snapshots;
confirmarlos usa `nutrition-plan:<id>` idempotente. Comidas borradas son tombstones;
las ediciones conservan una revisión y verifican la proyección esperada antes de
actualizarla. No se cambia ningún ID histórico.

Las recetas amplían MealTemplate (raciones, preparación, peso final opcional).
NutritionBackupService coordina los repositorios existentes. Importación:
previsualización + validación completa + inserciones aditivas con comprobación
de conflicto en cada almacén. No hay transacción entre Hive y preferencias;
un error de I/O puede dejar un prefijo importado y debe reintentarse con el mismo
archivo. Los IDs impiden duplicarlo. No se borran ni reemplazan datos del destino.

La copia no contiene credenciales; no es sincronización remota. Los accesos a agua
reutilizan Hábitos. La captura por IA y cámara no se simula.

Las revisiones de metas usan `__goalRevision:<uuid>` y se incluyen en la copia.
Las revisiones internas de comidas y planes retirados se conservan en el box
original, pero no se exportan como historial de auditoría: la copia representa
el estado canónico vigente (incluidos tombstones), no un journal completo de
cambios. Las preferencias Lite/Pro y activar ayuno no se activan al importar.
Una ventana de ayuno importada no cambia el consentimiento local.

El proveedor USDA remoto usa ficha completa y códigos de energía compatibles
con Foundation; el Worker requiere despliegue autorizado para aplicar ese
contrato en un servicio ya publicado. No se añade infraestructura IA ficticia.
