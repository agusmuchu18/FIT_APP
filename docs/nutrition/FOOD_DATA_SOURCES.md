# Fuentes de alimentos

Actualizado: 31/10/2026. Fuente activa offline: **USDA Foundation 29/10/2026**.

## Catálogo verificable

La [descarga oficial USDA](https://fdc.nal.usda.gov/download-datasets/) ofrece el
[ZIP Foundation JSON](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_foundation_food_json_2026-10-29.zip).
SHA256 del ZIP: `dd414cc9f1a132626bad354ef6655972c78b44aff14f16114dc899708663c579`.
El generador reproducible `tools/build_verified_usda_catalog.py --input <ZIP>`
verifica ese hash y genera `assets/data/usda_foundation_2026_10.json`.
Contiene 424 alimentos; 50 no tienen energía utilizable reportada y mantienen null.
Los 363 IDs del catálogo anterior siguen presentes. No se reescriben snapshots.

La auditoría del asset anterior de abril encontró energía derivada por 4/4/9,
ausencias convertidas en cero y porciones redondeadas. Se conserva ese archivo
histórico en el repositorio, pero pubspec ya no lo incluye como catálogo activo.
No se corrigen retrospectivamente comidas ya registradas ni se cambia su ID.
Por ejemplo, la porción publicada de hummus fdc:321358 conserva 33,9 g, y un
carbohidrato negativo declarado por diferencia queda no disponible con una nota.

Se toma energía reportada por USDA en prioridad 2048/958 (Atwater específico),
2047/957 (general), 1008/208 (energía reportada). El cliente no calcula energía
desde macros. La [documentación de Foundation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)
explica esos métodos y la disponibilidad variable de nutrientes. Los micros
mantienen unidad y nulls. Las porciones son pesos reales publicados, sin clamps,
densidades supuestas ni factores de cocción. Se conserva nombre original, fuente,
ID externo, fecha, método de energía y notas de calidad.

La [guía USDA](https://fdc.nal.usda.gov/api-guide/) declara CC0 y solicita atribución.
No se afirma verificación clínica ni nutricional profesional de la aplicación.
Hay 16 traducciones exactas por ID y alias regionales para búsqueda; la mayoría
del catálogo aún conserva su nombre original. Las semillas previas sin fuente
siguen identificadas como heredadas. No se inventan productos argentinos.

## Consulta remota y GTIN

Se reutilizan FdcClient, caché y Worker. Cliente y proxy solicitan ficha completa,
incluidos los códigos Atwater y vitaminas C/D, preservando etiquetas y porciones.
El Worker mantiene origen permitido, límites, secreto solo en servidor y errores
redactados; su caché cambia de versión para no reciclar respuestas abreviadas.
El cambio del Worker es local: **no se ha desplegado**.

El código manual valida GTIN/checksum, rechaza códigos nulos y solo acepta una
coincidencia exacta de USDA Branded; luego la guarda para uso offline. La cobertura
argentina no está garantizada. Sin servicio configurado consulta propios/caché y
permite crear desde etiqueta. Los tests usan transporte mock, no conexión real.
Los productos con porción en ml usan sus nutrientes de etiqueta y volumen
declarado; no se supone que 1 ml = 1 g. La cámara no está implementada.

## Fuentes pendientes

Open Food Facts **no está integrado**. Se consultaron su
[API](https://openfoodfacts.github.io/openfoodfacts-server/api/),
[lectura por GTIN](https://openfoodfacts.github.io/documentation/docs/Product-Opener/v3/products/get-api-v3-product-code/)
y [licencias](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/).
La documentación distingue base ODbL, contenidos DbCL e imágenes CC BY-SA.
Falta cerrar estrategia de atribución/bases derivadas; no se usaron datos ni
imágenes OFF. También falta una fuente argentina verificada y curación española
amplia. Los alimentos propios son declaraciones privadas del usuario.
