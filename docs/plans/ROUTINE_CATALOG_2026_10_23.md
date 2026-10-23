# Buscar rutinas · biblioteca inicial

Fecha: 23/10/2026. Fuente: carpeta local de FIT_APP. Solicitud: mostrar al menos
10 propuestas desde el ingreso, por nivel y con imágenes como en Entrenamiento.

## Entrega

12 propuestas incluidas con la app, cuatro por nivel. Disponibles offline;
explorar no guarda rutinas ni agrega sesiones, resultados o marcas personales.
Los niveles describen complejidad y volumen; no se deducen del sexo, peso o edad.
Cada propuesta representa una sesión editable, no un programa semanal automático.

| Nivel | Propuestas |
|---|---|
| Básico | Primeros pasos en el gym; Cuerpo completo con mancuernas; Empezá en casa; Zona media esencial |
| Intermedio | Torso equilibrado; Piernas y zona media; Empuje: pecho, hombros y tríceps; Tracción: espalda y bíceps |
| Avanzado | Torso: volumen y control; Piernas: fuerza y unilateral; Fuerza con básicos; Cadena posterior y espalda |

- Inicio en Explorar; sin teclado automático. Filtros por nivel y búsqueda sin
  tildes por nombre, objetivo, ejercicios y equipamiento. Mis rutinas conserva
  el acceso al historial de plantillas guardadas, edición e inicio existentes.
- Tarjetas con fotografía propia por propuesta, nivel escrito, objetivo,
  equipamiento, número de ejercicios y series. Una columna compacta; dos en
  anchos de al menos 720 px sin texto ampliado. No se trunca el nombre.
- Detalle antes de guardar: descripción, experiencia prevista, ejercicios en
  orden, series, repeticiones o segundos y descanso; enlace a fichas existentes.
- Personalizar abre el editor existente en un namespace temporal independiente.
  El usuario puede cambiar todo antes de guardar una copia con ID nuevo. No se
  asignan cargas personales ni series realizadas; guardado por cuenta existente.
  Cancelar no inserta rutinas; las aperturas repetidas no apilan detalles/editores.
- Error y reintento de Mis rutinas no bloquean la biblioteca incluida. Corregido
  el callback de reintento que devolvía un Future desde setState.

## Imágenes y coste

Nueve fotografías nuevas generadas con la herramienta integrada image_gen y
tres fotografías existentes reutilizadas: 12 portadas distintas. Nuevas: 906.064
bytes WebP en `assets/images/workout/catalog_*.webp`; originales preservados.
Sin nuevas dependencias, fuentes, permisos ni cambios de pubspec.yaml. Los
assets se incluyen mediante la carpeta ya declarada. Decodificación limitada a
1024 px de ancho; lista con slivers. No hay peticiones de red del catálogo.

Prompts, procedencia, rutas y tamaños:
`docs/design/ROUTINE_CATALOG_ASSETS_2026_10_23.json`. Son portadas decorativas,
no demostraciones de técnica ni sustitutos de las ilustraciones de ejercicios.

## Comprobaciones

- `routine_catalog_test.dart`: 12 IDs/portadas distintos, 4 por nivel, ejercicios
  reales, planes válidos, tiempos/cargas, búsqueda, estado inicial, filtros,
  lectura fallida/reintento, detalle/cancelación, guardado sin tocar el borrador
  normal, ID nuevo, objetivos conservados y separación de cuentas.
- `routine_search_screen_test.dart`: búsqueda en las rutinas guardadas preservada.
- `routine_catalog_golden_test.dart`: móvil 390 px oscuro; detalle; 900 px claro;
  320 px/200% con movimiento reducido y acción alcanzable; contraste de texto
  sobre superficies. Cuatro capturas revisadas y precarga con el tamaño real de
  decodificación para evitar aprobar fotografías vacías.
- Suite completa: 270/270 aprobadas. Análisis estricto: 0 incidencias.
  APK debug y web release compilados. Recorrido local 390×844: Home →
  Entrenamiento → biblioteca → detalle → ficha → editor → guardar copia →
  Mis rutinas → Home con la rutina disponible, sin insertar una sesión.
  Origen localhost aislado y copia «Prueba local · catálogo básico»; no cuenta
  del usuario. Resultado y límites en `docs/CURRENT_STATUS.md`.
- La revisión del árbol accesible detectó y eliminó un segundo contenedor
  anunciado como botón en cada portada. La activación la aporta InkWell.

## Límites

El contenido es editorial y adaptable: no prescribe pesos, progresión individual,
máximos o resultados. La revisión ampliada de técnica/media del catálogo y las
comprobaciones nativas Android/iPhone siguen en el plan principal. La presencia
de estas propuestas no certifica toda la app para tienda. Se conservan los cambios
previos del usuario fuera de esta entrega; no se publica ni se hace push.

Referencia general consultada: [posición ACSM 2026](https://pubmed.ncbi.nlm.nih.gov/41843416/).
Las 12 combinaciones y sus niveles son decisiones editoriales de FIT_APP, no
rutinas publicadas, personalizadas o certificadas por ACSM. No se presenta una
sesión aislada como cobertura de todos los grupos musculares de la semana.
