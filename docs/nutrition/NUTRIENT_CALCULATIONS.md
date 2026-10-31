# Cálculos y datos desconocidos

El lote A conserva `MacroValues`/`DraftEntry`, sin un segundo motor.

- Gramos: nutriente por 100 g × gramos equivalentes / 100.
- Porción: cantidad × equivalencia en gramos declarada por el alimento.
- Mililitros: solo si existe base por 100 ml; un nuevo registro sin equivalencia
  es rechazado en lugar de guardarse con nutrientes cero.
- Suma diaria: snapshots de comidas consumidas de esa fecha; planes no se
  convierten automáticamente en consumos.
- Duplicación: snapshot original íntegro con nuevo ID; no reconstruir macros
  desde kcal. Un reciente legacy sin composición no puede repetirse inventándola.
- Diario y `MealEntry.nutritionSnapshot` conservan decimales; los campos enteros
  anteriores permanecen como compatibilidad. Inicio, detalles y Analytics suman
  los valores precisos y redondean el total para las vistas heredadas. Dos comidas
  con 4,5 g de grasa suman 9 g, no 10 g por redondeos prematuros. La ficha y los
  formularios nuevos conservan cantidades decimales.
- Objetivo no configurado = null, nunca objetivo 0 ni 2400/160/260/80 de muestra.
- No se obliga a que energía declarada coincida con 4/4/9. No se descuenta
  automáticamente gasto de ejercicio ni se infieren micros o grasa corporal.

## Motor B

Los cuatro macros son nullable. `null + conocido = null`; no se publica una suma
parcial como total exacto. JSON conserva null. Fuente USDA ausente, negativa,
no finita o con una unidad incompatible devuelve null; cero explícito se conserva.
Los micronutrientes solo se incorporan cuando la fuente los declara, con unidad
identificada en la clave. No se convierten micros por 100 g a ml sin densidad.

Se aceptan cantidades decimales y coma decimal en formularios. Una porción se
escala por su equivalencia declarada; g y ml no se mezclan al copiar comidas.
Receta: total = suma de ingredientes; ración = total × raciones elegidas / raciones
de la receta. El peso final solo se utiliza si lo aporta el usuario; no se inventa
un factor de cocción. Las composiciones históricas se conservan como snapshots.

Los enteros de compatibilidad de MealEntry no expresan nutrientes desconocidos:
la marca `unknownNutrients` debe acompañarlos en cualquier consumidor nuevo.
La UI actualizada muestra — y evita gráficos completos sobre datos incompletos.
Metas nuevas tienen vigencia por fecha; una preferencia legacy sin fecha solo se
usa para hoy, sin inventar el objetivo de un día histórico.

Pendiente: ampliar catálogo español/regional, métricas e informes profesionales,
planes automáticos y sincronización rica. Ver IMPLEMENTATION_STATUS.

## Procedencia y revisiones

El catálogo activo usa solo energía declarada por USDA: específico 958, general
957 y reportado 208, en ese orden. No se aplica 4/4/9 para rellenar ausencias.
Un valor negativo de origen no se convierte en cero; queda null con nota.
La porción publicada conserva decimales (33,9 g no se redondea a 34 g).
Detalles: FOOD_DATA_SOURCES.md y el generador versionado.

Una corrección de objetivo para la misma fecha conserva una revisión anterior;
solo el último valor vigente participa en el resumen. La historia y la copia
JSON incluyen esas revisiones. Copiar una semana no registra consumo, rechaza
semanas superpuestas y reintentarlo no duplica ni reactiva planes consumidos.
