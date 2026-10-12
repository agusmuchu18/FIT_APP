# FIT_APP — Design System

**Versión:** 0.2.0 · **Fecha:** 2026-09-29 · **Estado:** Fase 2A aprobada; aplicación visual parcial en Entrenamiento.

Este documento es la fuente de verdad visual de FIT_APP. Define el lenguaje compartido de Figma, Flutter, Codex y futuros agentes. El piloto Flutter de Entrenamiento incorpora la dirección deportiva premium aprobada posteriormente: imágenes editoriales, iconografía propia y mayor jerarquía visual. El resto de la especificación sigue siendo objetivo de migración, no prueba de que todas las pantallas ya lo implementen.

## 0. Alcance, evidencia y lectura

Fuente oficial prevista: `docs/design/DESIGN_SYSTEM.md` dentro del repositorio FIT_APP. Modo definido: **Dark Premium**. El tema claro existente no se elimina ni se considera resuelto; necesitará especificación y validación antes de migrar componentes que también lo utilicen.

### Source of Truth

`DESIGN_SYSTEM.md` define las reglas visuales de FIT_APP. Figma las representa visualmente y Flutter las implementa. Ninguna pantalla puede introducir estilos arbitrarios: cualquier nueva decisión visual debe seguir la arquitectura de tokens, la gobernanza y el proceso de excepción de este documento.

Base: auditoría aprobada de la tarea «Auditar y planificar rediseño», del 14 de septiembre de 2026; lectura focalizada de `AGENTS.md`, `lib/app/theme/app_theme.dart`, `lib/features/common/theme/app_colors.dart`, `lib/features/common/widgets/summary_card.dart` y `pubspec.yaml` del repositorio FIT_APP. La auditoría estática tiene prioridad sobre `docs/UX_AUDIT.md` donde este último afirma correcciones que la Fase 1 no encontró en las rutas activas. No se realizó una nueva auditoría renderizada ni una modificación del repositorio.

Hallazgos que condicionan esta especificación:

- Inter está empaquetada como fuente local; algunos números usan cifras tabulares. La inconsistencia procede de su aplicación, no de una limitación demostrada de la familia.
- El tema usa azul de acción y radios 12/16/18; `AppColors` conserva turquesas; `SummaryCard` añade radio 24, altura mínima 140 y una variante glass con blur, gradiente y sombra. Se requiere convergencia, no otro tema paralelo permanente.
- La Fase 1 identificó contenido ficticio de Perfil/Grupos, metas nutricionales divergentes, radar nutricional sin significado fiable y visualizaciones que dibujan magnitud con cero o ausencia. Son dependencias funcionales futuras, no problemas que un token pueda resolver.
- `SleepEntry` no aporta fases de sueño verificadas. El horario de dormir/despertar sí permite una línea temporal. La distribución muscular mezcla criterios y no mide recuperación.

Las guías `fit-app-efficient-development`, `ui-ux-pro-max` y `flutter-build-responsive-layout` informan este trabajo. Se descartó la sugerencia automática de estilo deportivo lúdico; la búsqueda específica de minimalismo analítico aportó jerarquía y reducción de superficies, adaptadas aquí al producto.

**Convenciones:** DEBE es obligatorio; PUEDE expresa una opción definida. Los tamaños son unidades lógicas a escala de texto 1×: puntos de diseño en Figma, logical pixels en Flutter y CSS px en web. No son píxeles físicos. Las alturas de controles son mínimas; el contenido y el escalado pueden ampliarlas.

## 1. Principios de diseño

1. **Cada dato conserva su contexto.** Valor, unidad, período y calidad viajan juntos. «7 h» sin fecha no basta para representar el sueño de hoy.
2. **La precisión se ve.** Cero, ausencia, estimación y antigüedad tienen tratamientos distintos. No se rellena un gráfico para hacerlo atractivo.
3. **El registro debe ser fácil durante la actividad.** Controles legibles, áreas táctiles amplias y continuidad de la sesión tienen prioridad sobre efectos o densidad extrema.
4. **La jerarquía antecede al contenedor.** Alinear, espaciar y titular antes de agregar una card. El gráfico o la cifra dirige la lectura; la superficie la sostiene.
5. **El progreso se explica sin juzgar.** Toda comparación nombra su referencia. Subir no equivale siempre a mejorar; una racha no representa salud ni valor personal.
6. **Un producto, varios dominios.** Entrenamiento, alimentación, sueño y hábitos comparten controles, tipografía y superficies. Sus acentos identifican información, no temas independientes.
7. **El detalle aparece cuando hace falta.** Una lectura inicial clara conduce a series, registros y metodología accesibles; no se ocultan unidades, errores ni procedencia en tooltips obligatorios.
8. **Accesibilidad desde la definición.** Texto escalable, foco visible, lectura asistida, contraste y movimiento reducido son contratos de cada variante, no mejoras opcionales.

## 2. Arquitectura y registro de tokens

### 2.1 Tres niveles y nombres

`p.*` (primitivo literal) → `s.*` (rol semántico) → `c.*` (receta de componente).

Ejemplo normativo: `p.color.teal-300` → `s.action.primary` → `c.button.primary.background`.

Identificadores en inglés, minúsculas, segmentos separados por punto y palabras compuestas con guion. Sin nombres de pantalla, números de ticket, `new`, `premium2` o equivalentes. El modo se almacena en la colección, no en el nombre: `s.text.primary` tiene un valor en Dark, no un sufijo `.dark`.

Los bloques de tablas con identificadores `p.*`, `s.*` y `c.*` son el registro normativo. Una celda con un objeto es un token compuesto; sus propiedades son parte del contrato. Las rutas de propiedad, como `c.button.primary.background`, acceden al objeto `c.button.primary` y no duplican el registro. Los nombres de variantes no crean automáticamente nuevos tokens.

Al resolver una ruta, buscar primero el ID exacto y después el prefijo registrado más largo: `s.surface.elevated` es un token independiente, mientras `s.space.4` es una propiedad de escala. En una serialización futura se preserva esa diferencia con grupos explícitos; no convertir un valor escalar en objeto accidentalmente. Hexadecimales opacos se expresan como RGB; el único transparente está en RGBA y debe convertirse al orden ARGB de Flutter al implementarse.

Reglas de resolución:

- Solo `p.*` contiene valores literales visuales. `s.*` referencia primitivos o roles semánticos ya definidos; no se permiten ciclos. `c.*` consume roles `s.*` o hereda otra receta `c.*`, sin acceder directamente a `p.*`.
- Los valores de las tablas explicativas de tipografía y geometría son proyecciones del registro, no otra fuente.
- Ningún widget/frame consume un color hexadecimal, radio, tamaño tipográfico, opacidad o duración independiente. No se permite `withOpacity`/`withValues` arbitrario ni un override local para «que encaje».
- Medidas calculadas a partir de constraints, safe areas, texto, datos y proporciones documentadas no son hardcodes: su fórmula debe quedar indicada. Los valores de datos, fechas y unidades no son tokens visuales.
- Las recetas heredan solo donde este documento lo declara. En Figma se representarán como variantes y propiedades; en Flutter, como estilos/temas y contratos. No se exporta ciegamente una cadena de herencia a ambos entornos.
- No generar una paleta de 50 tonos ni un token para cada instancia. Agregar únicamente roles utilizados y documentados. No crear aliases sin consumidor salvo los contratos fundacionales de esta versión.

### 2.2 Primitivos de color

Colores sRGB opacos, salvo `transparent` y el scrim compuesto. La elección retiene la base azul oscura actual y reduce la saturación del turquesa original.

| Token | Valor | Propósito de paleta |
|---|---|---|
| `p.color.navy-950` | `#0E1624` | Base oscura |
| `p.color.navy-900` | `#161F2C` | Card |
| `p.color.navy-850` | `#1B2738` | Elevación |
| `p.color.navy-800` | `#223248` | Interacción en reposo |
| `p.color.navy-750` | `#2B3D55` | Hover |
| `p.color.navy-700` | `#344963` | Pressed; superficie oscura más luminosa permitida |
| `p.color.teal-950` | `#193B44` | Selección |
| `p.color.slate-700` | `#334155` | Separador no esencial |
| `p.color.slate-500` | `#7B8A9D` | Inactivo |
| `p.color.slate-400` | `#8E9FB5` | Contorno funcional |
| `p.color.slate-300` | `#ADBACC` | Texto de menor énfasis |
| `p.color.slate-200` | `#C7D2E1` | Texto secundario |
| `p.color.slate-050` | `#EAF1FF` | Texto principal |
| `p.color.teal-200` | `#8AE6D6` | Acción hover |
| `p.color.teal-300` | `#63DCC7` | Acción y entrenamiento |
| `p.color.teal-400` | `#42C5AE` | Acción pressed |
| `p.color.green-300` | `#73D8A0` | Confirmación |
| `p.color.amber-300` | `#F6C85F` | Atención y alimentación |
| `p.color.rose-300` | `#FF9AA2` | Error |
| `p.color.blue-300` | `#8CBFFF` | Información |
| `p.color.violet-300` | `#C0ACFF` | Sueño |
| `p.color.pink-300` | `#F5A7D0` | Hábitos |
| `p.color.black` | `#000000` | Scrim |
| `p.color.transparent` | `#00000000` | Sin relleno, formato RGBA |

### 2.3 Primitivos de otras dimensiones

Los objetos de escala son registros cerrados, no rangos que autoricen interpolaciones arbitrarias.

| Token | Valor |
|---|---|
| `p.space` | `{none:0, 1:4, 2:8, 3:12, 4:16, 5:20, 6:24, 8:32, 10:40, 12:48, 16:64}` |
| `p.radius` | `{none:0, small:8, medium:12, large:16, overlay:24, pill:999}` |
| `p.stroke` | `{none:0, thin:1, strong:2}` |
| `p.icon` | `{small:16, default:24, large:32}` |
| `p.icon.style` | `{family:FIT Glyph, stroke:2, cap:round, join:round, grid:24}` |
| `p.size` | `{target:48, input:56, row:64, navigation:64, chart:192, sparkline:48, media-empty:96}` |
| `p.width` | `{compact:360, regular:400, medium:600, expanded:1024, form:600, reading:720, content:1200, dialog:480, sheet:640, cell:280}` |
| `p.ratio` | `{square:1/1, landscape:4/3, portrait:3/4, wide:16/9}` |
| `p.opacity` | `{area:0.12, scrim:0.64}` |
| `p.duration` | `{fast:120ms, normal:200ms, slow:320ms, loading-cycle:1000ms}` |
| `p.curve` | `{standard:cubic-bezier(0.2,0,0,1), enter:cubic-bezier(0,0,0.2,1), exit:cubic-bezier(0.4,0,1,1), linear:cubic-bezier(0,0,1,1)}` |
| `p.layer` | `{content:0, sticky:10, persistent:20, scrim:30, modal:40, feedback:50, tooltip:60}` |
| `p.font.family` | `Inter; fallback: system sans-serif` |
| `p.font.weight` | `{regular:400, medium:500, semibold:600, bold:700}` |
| `p.font.features` | `{normal:default, numeric:tabular lining figures (tnum, lnum)}` |
| `p.type.display` | `{size:32, weight:700, line:40, tracking:-0.4}` |
| `p.type.heading-large` | `{size:28, weight:700, line:36, tracking:-0.3}` |
| `p.type.heading-medium` | `{size:24, weight:600, line:32, tracking:-0.2}` |
| `p.type.heading-small` | `{size:20, weight:600, line:28, tracking:0}` |
| `p.type.body-large` | `{size:18, weight:400, line:28, tracking:0}` |
| `p.type.body` | `{size:16, weight:400, line:24, tracking:0}` |
| `p.type.body-small` | `{size:14, weight:400, line:20, tracking:0}` |
| `p.type.label` | `{size:14, weight:600, line:20, tracking:0.1}` |
| `p.type.caption` | `{size:12, weight:500, line:16, tracking:0.1}` |
| `p.type.metric-xl` | `{size:40, weight:700, line:48, tracking:-0.4}` |
| `p.type.metric-large` | `{size:32, weight:700, line:40, tracking:-0.3}` |
| `p.type.metric-medium` | `{size:24, weight:600, line:32, tracking:0}` |

Los estilos `p.type.*` usan `p.font.family` y pesos del catálogo `p.font.weight`. Sus números se enumeran completos para trasladar la misma composición entre plataformas. Las métricas incorporan `p.font.features.numeric`.

## 3. Colores semánticos y estados de interacción

### 3.1 Registro semántico de color

| Token | Referencia | Uso obligatorio |
|---|---|---|
| `s.background` | `p.color.navy-950` | Fondo global |
| `s.surface` | `p.color.navy-900` | Card |
| `s.surface.elevated` | `p.color.navy-850` | Sheet, dialog, snackbar, tooltip |
| `s.surface.interactive` | `p.color.navy-800` | Control secundario y card accionable |
| `s.surface.hover` | `p.color.navy-750` | Hover neutro |
| `s.surface.pressed` | `p.color.navy-700` | Pressed neutro |
| `s.surface.selected` | `p.color.teal-950` | Selección de controles |
| `s.surface.disabled` | `p.color.navy-900` | Control inactivo |
| `s.surface.none` | `p.color.transparent` | Sección sin contenedor |
| `s.border.subtle` | `p.color.slate-700` | Divisor decorativo; nunca único límite de un input |
| `s.border.control` | `p.color.slate-400` | Límite funcional y marcador de dato cero |
| `s.border.selected` | `p.color.teal-300` | Selección explícita |
| `s.text.primary` | `p.color.slate-050` | Valor y contenido principal |
| `s.text.secondary` | `p.color.slate-200` | Contexto y unidades |
| `s.text.muted` | `p.color.slate-300` | Metadatos legibles, placeholder |
| `s.text.disabled` | `p.color.slate-500` | Solo contenido de control realmente inactivo |
| `s.action.primary` | `p.color.teal-300` | Acción principal |
| `s.action.primary-hover` | `p.color.teal-200` | Hover de acción principal |
| `s.action.primary-pressed` | `p.color.teal-400` | Pressed de acción principal |
| `s.action.on-primary` | `p.color.navy-950` | Texto/icono sobre acción primaria |
| `s.focus` | `p.color.slate-050` | Anillo de foco |
| `s.status.success` | `p.color.green-300` | Operación completada |
| `s.status.warning` | `p.color.amber-300` | Atención recuperable |
| `s.status.error` | `p.color.rose-300` | Fallo o destrucción |
| `s.status.information` | `p.color.blue-300` | Información neutral |
| `s.module.workout` | `p.color.teal-300` | Datos de entrenamiento |
| `s.module.nutrition` | `p.color.amber-300` | Datos de alimentación |
| `s.module.sleep` | `p.color.violet-300` | Datos de sueño |
| `s.module.habits` | `p.color.pink-300` | Datos de hábitos |
| `s.chart.protein` | `p.color.blue-300` | Proteínas en toda la app |
| `s.chart.carbohydrate` | `p.color.amber-300` | Carbohidratos en toda la app |
| `s.chart.fat` | `p.color.violet-300` | Grasas en toda la app |
| `s.chart.comparison` | `p.color.slate-300` | Período de referencia; trazo discontinuo |
| `s.chart.grid` | `s.border.subtle` | Guías auxiliares no esenciales |
| `s.chart.zero` | `s.border.control` | Marca de cero, sin magnitud artificial |
| `s.chart.unknown` | `s.text.muted` | Ausencia anotada, no serie gris ficticia |
| `s.scrim` | `{color:p.color.black, opacity:p.opacity.scrim}` | Oscurecer fondo de modal |

Un mismo primitivo puede servir a dos roles: ámbar de alimentación y warning no significan lo mismo. La etiqueta, el icono y el contexto los distinguen. No se cambia el color de botones al entrar a otro módulo. Perfil y Grupos usan roles globales; no necesitan nuevos acentos.

### 3.2 Contrato común de interacción

| Estado | Primario sólido | Secundario / superficie interactiva | Evidencia adicional |
|---|---|---|---|
| Default | `s.action.primary` + `s.action.on-primary` | `s.surface.interactive` + `s.text.primary`, borde control | Etiqueta visible |
| Hover | `s.action.primary-hover` | `s.surface.hover` | Solo con puntero; no revela información indispensable |
| Pressed | `s.action.primary-pressed` | `s.surface.pressed` | Sin encoger texto ni mover layout |
| Selected | No aplica a una acción momentánea | `s.surface.selected`, borde selected, texto primary | Check, subrayado o indicador y estado accesible |
| Disabled | `s.surface.disabled` + `s.text.disabled` | Igual, borde subtle | Semántica disabled; motivo fuera del control en texto secondary |
| Focus | Anillo `s.focus` | Mismo anillo | Borde strong, separación space.1 con fondo background |

Prioridad: disabled cancela interacción; busy bloquea reenvío pero conserva contraste normal; pressed vence a hover. Selected mantiene indicador y semántica durante hover/pressed, aunque cambie el fondo. Focus se agrega al estado resultante, no lo sustituye. Error de campo mantiene mensaje y borde de error también cuando hay foco; el anillo exterior permanece visible.

No aplicar reducción de opacidad al componente completo. El foco blanco se separa del botón turquesa por el gap oscuro: no se exige distinguir blanco directamente sobre turquesa. El anillo y su separación no alteran el tamaño ni se recortan por contenedores.

### 3.3 Contraste permitido

Objetivo: WCAG 2.2 AA. Texto normal ≥4.5:1; texto grande ≥3:1 (24 CSS px regular o aproximadamente 18.67 CSS px en negrita). FIT_APP exige ≥4.5:1 también en métricas grandes para mantener margen. Contornos e iconos esenciales ≥3:1 respecto del fondo adyacente. Referencias: [contraste de texto](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) y [contraste no textual](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).

Solo combinar los textos y acentos definidos con las superficies oscuras registradas. Sobre el sólido primario usar exclusivamente on-primary. Sobre una foto no ubicar texto crítico: situarlo en una superficie opaca. No usar texto blanco sobre el turquesa de acción. Bordes sutiles y áreas al 12% no son información suficiente por sí solos; requieren etiquetas, trazos o bordes que cumplan contraste. Los inactivos están exceptuados del mínimo WCAG, pero su explicación sigue siendo legible.

## 4. Tipografía

**Decisión: conservar Inter.** Ofrece continuidad, lectura de datos y disponibilidad en el tema actual. No hay evidencia que justifique sustituirla por una familia deportiva o condensada. La personalidad surge de jerarquía y composición. No se incorpora una segunda familia.

| Token semántico | Primitivo | Tamaño / peso / línea / tracking | Uso permitido |
|---|---|---|---|
| `s.type.display` | `p.type.display` | 32 / 700 / 40 / −0.4 | Introducción excepcional; no encabezado de todas las cards |
| `s.type.heading-large` | `p.type.heading-large` | 28 / 700 / 36 / −0.3 | Título principal |
| `s.type.heading-medium` | `p.type.heading-medium` | 24 / 600 / 32 / −0.2 | Sección principal |
| `s.type.heading-small` | `p.type.heading-small` | 20 / 600 / 28 / 0 | Subsección, título de dialog |
| `s.type.body-large` | `p.type.body-large` | 18 / 400 / 28 / 0 | Explicación breve destacada |
| `s.type.body` | `p.type.body` | 16 / 400 / 24 / 0 | Contenido e inputs |
| `s.type.body-small` | `p.type.body-small` | 14 / 400 / 20 / 0 | Metadatos y ayuda complementaria |
| `s.type.label` | `p.type.label` | 14 / 600 / 20 / +0.1 | Botón, pestaña, etiqueta de formulario |
| `s.type.caption` | `p.type.caption` | 12 / 500 / 16 / +0.1 | Eje, timestamp breve; nunca instrucción crítica |
| `s.type.metric-xl` | `p.type.metric-xl` | 40 / 700 / 48 / −0.4 | Una métrica protagonista por bloque principal |
| `s.type.metric-large` | `p.type.metric-large` | 32 / 700 / 40 / −0.3 | Resumen analítico |
| `s.type.metric-medium` | `p.type.metric-medium` | 24 / 600 / 32 / 0 | Métrica de lista o comparación |

Line-height es altura absoluta a 1×; Flutter deriva `height = line / size`. Tracking se expresa en unidades lógicas, no porcentaje. Textos siguen el escalador del sistema, incluidas métricas y captions. No usar `FittedBox` para encoger cifras ni limitar el escalador para salvar una fila: reorganizar columnas y permitir salto de línea.

Métricas, tablas, cronómetros y columnas de series usan cifras tabulares y lining figures; títulos y prosa conservan espaciado normal. Unidades con Body Small y text.secondary, junto al valor o en una línea propia cuando no entren; la lectura asistida recibe la frase completa. Una abreviatura visual debe ofrecer valor íntegro mediante detalle accesible.

Formato numérico según locale y unidad del usuario, sin decimales ficticios. Mantener precisión consistente en una misma comparación; calcular con precisión original y redondear solo al presentar. Duración se expresa en h/min o cronómetro según contexto, nunca como decimal ambiguo. «— · Sin datos» no se reemplaza por «0». No forzar mayúsculas sostenidas en botones. Inter se carga desde `assets/fonts/Inter-Variable.ttf` para permitir arranque offline.

## 5. Espaciado

| Nivel de `p.space` | Valor | Uso |
|---|---|---|
| 1 | 4 | Valor–unidad, ajustes entre metadatos relacionados |
| 2 | 8 | Icono–texto y separación mínima entre objetivos táctiles distintos |
| 3 | 12 | Líneas de un grupo y padding compacto |
| 4 | 16 | Padding de card/input, margen pequeño, separación de filas |
| 5 | 20 | Margen de teléfono estándar |
| 6 | 24 | Secciones móviles y padding de modal |
| 8 | 32 | Secciones principales en ancho medio, margen de tablet |
| 10 | 40 | Margen expandido o separación de grupos mayores |
| 12 | 48 | Separación excepcional de bloques de introducción |
| 16 | 64 | Aire de composición amplia; nunca relleno de una card vacía |

`none=0` significa ausencia de espacio, no un undécimo paso positivo. No sumar paddings de padre e hijo para simular un nivel no aprobado. Las cards no reciben margen implícito: el layout padre decide su separación.

## 6. Radios, tamaños y roles geométricos

| Token semántico | Referencia | Contrato |
|---|---|---|
| `s.space` | `p.space` | Escala espacial compartida |
| `s.shape.small` | `p.radius.small` | Radio 8: chip, segmented, controles pequeños |
| `s.shape.control` | `p.radius.medium` | Radio 12: button, input, snackbar |
| `s.shape.card` | `p.radius.large` | Radio 16: card y contenedor grande no modal |
| `s.shape.overlay` | `p.radius.overlay` | Radio 24: sheet y dialog |
| `s.shape.pill` | `p.radius.pill` | Cápsula; clamped a la mitad del lado menor |
| `s.shape.none` | `p.radius.none` | Sección, gráfico, imagen sin marco propio |
| `s.stroke` | `p.stroke` | Thin 1; strong 2 para foco/selección/trazos |
| `s.icon` | `p.icon` | 16 / 24 / 32 |
| `s.icon.style` | `p.icon.style` | Familia y ejes únicos de iconografía |
| `s.size` | `p.size` | Mínimos controlados y altura preferida de gráfico |
| `s.width` | `p.width` | Breakpoints y máximos |
| `s.ratio` | `p.ratio` | Proporciones de media |
| `s.opacity` | `p.opacity` | Área analítica, scrim, transparente, opaco |
| `s.motion.duration` | `p.duration` | Tiempos comunes |
| `s.motion.curve` | `p.curve` | Curvas comunes |
| `s.layer` | `p.layer` | Orden de superposición conceptual |

**Circle** usa proporción square y recorte circular geométrico, no un nuevo radio numérico. Solo avatar e IconButton circular. Pill queda reservada para etiquetas compactas de estado; no convertir todos los botones en cápsulas. Contenedor grande comparte radio card: su importancia no requiere un radio nuevo. Sheet anclada abajo redondea solo esquinas superiores; dialog flotante las cuatro.

## 7. Superficies y elevación

| Nivel | Fondo / borde | Padding | Profundidad y regla |
|---|---|---|---|
| Background | background / none | Márgenes del layout | Lienzo |
| Section | none / none | Sin padding adicional al del padre | Separar con título, espacio y alineación |
| Card | surface / subtle opcional | space.4 | Unidad informativa; altura según contenido |
| Interactive card | surface.interactive / border.control | space.4 | Affordance explícita; estados comunes |
| Overlay | scrim detrás de superficie elevated | Según contenido | Scrim no contiene texto; bloquea interacción de fondo si es modal |
| Modal | surface.elevated / border.control | space.6 | Sheet/dialog; foco contenido |

Elevación visual por cambio tonal y contorno, **sin sombras**, sin surface tint automático ni blur en esta versión. No se añade otra capa de color dentro de una card para alojar una métrica. Una tarjeta seleccionable necesita borde funcional; una informativa puede carecer de borde. No usar gradientes decorativos ni variantes glass. Excepción estructural legítima: input o control dentro de un modal/card; conserva su propia affordance y no se trata como «card dentro de card».

## 8. Layout adaptable

Medir el ancho disponible del contenedor tras insets del sistema y superficies persistentes que ocupen espacio. Las etiquetas de dispositivo son ejemplos, no condiciones del código. Los umbrales siguientes corresponden a `s.width`; el margen se aplica después de elegir el rango.

| Ancho útil W | Ejemplo | Margen horizontal | Composición permitida |
|---|---|---|---|
| W < 360 | Small phone / ventana estrecha | space.4 (16) | Una columna; métricas apiladas, etiquetas envuelven |
| 360 ≤ W < 400 | Standard phone | space.5 (20) | Una columna principal |
| 400 ≤ W < 600 | Large phone | space.6 (24) | Una columna; parejas solo si texto y controles caben |
| 600 ≤ W < 1024 | Tablet / ventana intermedia | space.8 (32) | Hasta dos columnas según ancho mínimo de celda |
| W ≥ 1024 | Desktop/web / ventana amplia | space.10 (40) | Hasta tres columnas, contenido centrado máximo 1200 |

Ancho interior = `min(W − 2×margen, s.width.content)`. Para cards informativas en grid, mínimo preferido de celda `s.width.cell=280`, gap space.6 y columnas = mínimo entre límite del rango y `floor((interior + gap)/(280 + gap))`, nunca menor que uno. En ancho insuficiente una celda se contrae al ancho disponible y su contenido se reorganiza. No aplicar esa fórmula a filas de inputs densos: requieren su propia prueba de ajuste.

Formularios máximo 600; prosa máximo 720; dialogs máximo 480; sheets flotantes máximo 640. Son máximos, no anchos fijos. Dos números breves pueden convivir en teléfono amplio, pero no es permiso para fijar métricas a 184 px. Si escala de texto o contenido invalida la composición, pasar a una columna sin cambiar la escala tipográfica.

Separación entre secciones: space.6 en W<600 y space.8 desde 600. Espacio dentro de sección space.4; dentro de un grupo space.2/3. Evitar scrolling horizontal de la página. Una tabla analítica compleja puede tener desplazamiento horizontal local con nombre accesible y alternativa textual, pero los controles de registrar series deben reorganizarse.

**Safe areas y barras:** una sola autoridad de layout cuenta cada inset. Si el Scaffold ya reserva una barra, no volver a agregar su altura. Si las capas inferiores se superponen al scroll, clearance = altura real del conjunto de barras visibles (navegación + sesión/borrador + CTA, sin insets internos duplicados) + safeBottom aún no consumido + space.4. No usar 160 px globales. La navegación tiene mínimo s.size.navigation=64, puede crecer con etiquetas; medir su altura final.

Teclado: usar el área realmente disponible, permitir desplazar hasta campo y error, y contabilizar `viewInsets` una vez. Un CTA no debe quedar entre teclado y contenido sin espacio operable. Headers sticky se usan solo para contexto o controles necesarios; altura real y scroll-to-focus evitan tapar el elemento enfocado. Orden: content → sticky → persistent → scrim → modal → feedback → tooltip. En modal, snackbar/tooltip pertenecen a ese ámbito; no se dibujan mensajes de fondo por encima.

En altura reducida se elimina la fijación no esencial antes de comprimir contenido; dialog/sheet permite scroll y acciones alcanzables. No cambiar destinos ni introducir sidebar en esta fase. Una futura adaptación de navegación necesita diseño específico aprobado, preservando rutas y funciones.

## 9. Iconografía

Familia propia **FIT Glyph**, configurada por `s.icon.style`: cuadrícula de 24, trazo de 2 y extremos/uniones redondos. `lib/features/common/widgets/fit_glyph.dart` implementa navegación principal y acciones de Entrenamiento sin depender de una fuente de iconos externa. Los iconos Material existentes en otros flujos siguen pendientes de migración; no se deben mezclar estilos en una misma pantalla nueva. Figma deberá representar esta familia cuando se continúe el piloto.

Tamaños: small 16 junto a caption, default 24 en controles y navegación, large 32 en estados. El tamaño óptico base se escala uniformemente; no alterar grosor por pantalla. Estado activo: mismo contorno, marcador y etiqueta seleccionada; **no cambiar arbitrariamente a filled**. Inactivo navegable usa text.secondary; disabled real usa text.disabled.

Área táctil mínima 48 aunque el dibujo mida 16/24. Iconos con texto redundante se excluyen de lectura asistida; iconos informativos necesitan descripción; IconButton necesita nombre de acción y estado. No usar emoji como icono UI. Mapas musculares e ilustraciones anatómicas son media de dominio, no una segunda familia de iconos.

## 10. Taxonomía de componentes — especificación, no implementación

### 10.1 Recetas registradas

Todos los estados interactivos heredan §3.2; tipografía, iconografía, movimiento y accesibilidad heredan sus secciones. Las propiedades no redefinidas conservan la receta base. Se enumeran solo diferencias reales, no una copia completa por módulo. En las tablas, cada valor `s.*` es una referencia, nunca una cadena literal de estilo.

| Token de componente | Composición normativa |
|---|---|
| `c.control` | `{min-height:s.size.target, target:s.size.target, radius:s.shape.control, horizontal:s.space.4, vertical:s.space.3, gap:s.space.2, type:s.type.label, foreground:s.text.primary, border:s.border.control, border-width:s.stroke.thin}` |
| `c.button.primary` | `{base:c.control, background:s.action.primary, foreground:s.action.on-primary, border-width:s.stroke.none}` |
| `c.button.secondary` | `{base:c.control, background:s.surface.interactive, foreground:s.text.primary}` |
| `c.button.tertiary` | `{base:c.control, background:s.surface.none, foreground:s.action.primary, border-width:s.stroke.none}` |
| `c.button.destructive` | `{base:c.control, background:s.surface.interactive, foreground:s.status.error, border:s.status.error}` |
| `c.icon-button` | `{base:c.control, icon:s.icon.default, horizontal:s.space.3, background:s.surface.none, border-width:s.stroke.none}` |
| `c.input` | `{base:c.control, min-height:s.size.input, type:s.type.body, background:s.surface.interactive, label:s.type.label, helper:s.type.body-small, placeholder:s.text.muted}` |
| `c.search` | `{base:c.input, icon:s.icon.default, gap:s.space.2}` |
| `c.chip` | `{base:c.control, radius:s.shape.small, horizontal:s.space.3, background:s.surface.interactive}` |
| `c.segmented-control` | `{base:c.control, radius:s.shape.small, background:s.surface.interactive, padding:s.space.1, segment-min-height:s.size.target}` |
| `c.card` | `{background:s.surface, foreground:s.text.primary, radius:s.shape.card, padding:s.space.4, gap:s.space.3, border:s.border.subtle, border-width:s.stroke.none}` |
| `c.card.interactive` | `{base:c.card, background:s.surface.interactive, border:s.border.control, border-width:s.stroke.thin}` |
| `c.metric` | `{background:s.surface.none, value:s.type.metric-large, unit:s.type.body-small, label:s.type.label, context:s.type.body-small, foreground:s.text.primary, secondary:s.text.secondary, gap:s.space.1}` |
| `c.list-row` | `{min-height:s.size.row, background:s.surface.none, type:s.type.body, secondary:s.type.body-small, foreground:s.text.primary, horizontal:s.space.4, vertical:s.space.3, gap:s.space.3, divider:s.border.subtle}` |
| `c.section-header` | `{type:s.type.heading-medium, foreground:s.text.primary, action:s.type.label, gap:s.space.3, bottom:s.space.4, background:s.surface.none}` |
| `c.bottom-navigation` | `{min-height:s.size.navigation, background:s.surface.elevated, label:s.type.label, icon:s.icon.default, foreground:s.text.secondary, selected:s.action.primary, indicator:s.surface.selected, padding:s.space.2, target:s.size.target}` |
| `c.sheet` | `{background:s.surface.elevated, radius:s.shape.overlay, padding:s.space.6, gap:s.space.4, width-max:s.width.sheet, title:s.type.heading-small, border:s.border.control, border-width:s.stroke.thin, scrim:s.scrim}` |
| `c.dialog` | `{base:c.sheet, width-max:s.width.dialog}` |
| `c.snackbar` | `{background:s.surface.elevated, foreground:s.text.primary, type:s.type.body-small, radius:s.shape.control, padding:s.space.4, gap:s.space.3, border:s.border.control, border-width:s.stroke.thin, action:s.action.primary}` |
| `c.tabs` | `{min-height:s.size.target, label:s.type.label, foreground:s.text.secondary, selected:s.text.primary, indicator:s.action.primary, indicator-width:s.stroke.strong, gap:s.space.4, background:s.surface.none}` |
| `c.chart` | `{background:s.surface.none, preferred-height:s.size.chart, label:s.type.caption, foreground:s.text.secondary, line:s.stroke.strong, grid:s.chart.grid, grid-width:s.stroke.thin, area-opacity:s.opacity.area, gap:s.space.3}` |
| `c.media` | `{ratio:s.ratio.square, radius:s.shape.card, background:s.surface.interactive, placeholder:s.text.muted, icon:s.icon.default}` |

Botones tertiary e IconButton sin relleno usan surface.hover/pressed al interactuar. Destructive conserva foreground y borde error sobre los fondos neutros de estado; no usa texto blanco en sólido rojo. El estado disabled de todos reemplaza esos colores por los definidos en §3.2. Las recetas son objetos compuestos listos para especificar; no código Flutter ni componentes Figma creados.

### 10.2 Variantes y anatomía

| Familia | Variantes permitidas | Anatomía y comportamiento visual |
|---|---|---|
| Button | Primary, secondary, tertiary, destructive; icono inicial opcional; busy | Una acción primaria por ámbito de decisión. Altura mínima 48; padding horizontal 16 y vertical mínimo 12. Etiqueta puede envolver. Busy conserva ancho y nombre, agrega indicador; nunca dispara envíos duplicados. No variante «NutritionButton». |
| IconButton | Quiet, secondary, destructive; cuadrado redondeado o círculo | Área 48×48 mínima. Quiet hereda c.icon-button; secondary usa fondo/borde de c.button.secondary; destructive usa sus colores de error. Tooltip suplementario, nombre accesible obligatorio. Sin iconos de acción ambiguos cuando cabe texto. |
| Input | Texto, numérico con unidad, multiline, password, selector; readonly, disabled, error | Label persistente encima; valor; unidad/sufijo; ayuda/error debajo. Error tiene icono y mensaje, no solo borde. Readonly sigue siendo legible/copiarable y no usa text.disabled. Inputs multiline crecen o ofrecen scroll interno explícito. |
| Search | Global del ámbito, con filtros externos; idle, typing, loading, results, no-results, error | Label «Buscar alimentos/ejercicios…» accesible, icono buscar, texto, limpiar con target propio. Filtros fuera del campo y envuelven. «Sin resultados para…» distingue búsqueda vacía de base sin datos. Loading no borra consulta ni resultados válidos sin contexto. |
| Chip | Filter multi-select, choice single-select, action, status no interactivo | Filter/choice muestran check y selected; action no conserva selección. Altura táctil mínima 48. Status usa padding 8 horizontal/4 vertical y no simula botón. Chips envuelven, no recortan etiquetas esenciales. |
| Segmented Control | Elección única de vista/período; 2–4 opciones breves | Fondo compartido, segmentos de mínimo 48 de alto dentro de padding 4; selected tiene fondo, borde y check/indicador. Opciones no caben: reemplazo futuro por selector equivalente, no reducir letra. No usar para navegación entre destinos principales. |
| Card | Informativa, interactive, selected | Informativa sin altura mínima universal ni borde obligatorio. Interactive agrega affordance textual/icono y estados; selected suma borde selected e indicador. Una acción principal de card; controles internos no compiten con un tap envolvente. No variantes por decoración. |
| Metric | Hero (metric-xl), standard (metric-large), compact (metric-medium); delta opcional | Etiqueta → valor/unidad → período/calidad → comparación. Sin fondo propio. La unidad no desaparece al compactar. Puede habitar una sección, fila o card. Ausencia es estado, no un cero coloreado. |
| List Row | Simple, con metadatos, seleccionable, accionable, con media | Nombre y contexto a la izquierda; valor/acción al extremo lógico final. Nombre puede ocupar varias líneas. Media usa miniatura 48 cuadrada. Evitar varias cards para una lista homogénea; divisores opcionales. |
| Section Header | Simple, con acción, con subtítulo | Heading Medium; Heading Small solo para subsección. Acción tertiary con área 48; en espacio insuficiente pasa debajo. No todo encabezado necesita botón «Ver todo». |
| Bottom Navigation | Default y selected por destino; badge si existe dato real | Icono y etiqueta siempre visibles. Distribución uniforme de destinos existentes. Área ≥48, foco y semántica selected. No comunica selección solo por color. Esta especificación no añade, quita ni reordena destinos. Si no caben, la adaptación se resuelve en el piloto posterior. |
| Sheet | Informativa, selección, formulario; modal o persistente según flujo existente | Título, contenido, cierre accesible, acciones. Modal usa scrim; persistente no bloquea fondo ni atrapa foco. Drag handle opcional acompañado por alternativa de cerrar; contenido y teclado determinan altura. No depender solo de arrastrar. |
| Dialog | Confirmación, decisión destructiva, mensaje bloqueante | Título explica consecuencia; body y hasta dos acciones principales de decisión. En narrow/texto ampliado, acciones apiladas. Cancelar visible donde corresponda; no cerrar silenciosamente con cambios sin guardar. |
| Snackbar | Información, éxito, fallo recuperable; con acción opcional | Mensaje breve + icono de estado + acción. No único lugar para error de formulario o pérdida de datos. Sin stacking de varios mensajes. Mensajes accionables persisten hasta resolver/cerrar; informativos pueden cerrarse tras 6 s y pausan con hover/foco. El tiempo de lectura es conducta, no animación. |
| Tabs | Secciones hermanas de contenido, con etiqueta; fija o desplazable | Underline strong y texto selected; no cápsulas aleatorias. Scroll local solo si conserva indicación y acceso a todas las pestañas. Teclado con flechas; Home/End cuando aplique; selección y panel anunciados. No reemplazar Bottom Navigation. |

Estados obligatorios por familia: todo control soporta default, focus, disabled y pressed; hover donde exista puntero; selected solo si la semántica lo admite. Inputs/Search incorporan error y carga; Card/Metric/List Row/Chart incorporan estados de datos de §14. Sheets/dialogs cubren contenido largo, teclado y error. Las mismas variantes se documentarán en Figma y Flutter con nombres equivalentes.

## 11. Sistema de visualización de datos

### 11.1 Contrato común de un gráfico

Antes de construirlo se documentan: pregunta, fuente/entidad, campo temporal, unidad, agregación, cobertura, denominador, tratamiento de ausencias, precisión, regla de comparación y responsable de validar el significado. Este contrato es requisito de diseño, no una migración de modelos.

Anatomía: título que nombra la medida → resumen numérico descriptivo → visualización → período/unidad/cobertura → acceso «Ver datos» y metodología cuando corresponda. No títulos como «Tu rendimiento» si el único dato es duración. No inferir salud, fatiga o recuperación a partir del color o la forma.

Reglas universales:

- Tiempo de izquierda a derecha para series cronológicas; fechas y números según locale. Registrar zona horaria del período. Cambio de horario estacional no autoriza calcular duración restando horas de reloj sin contexto temporal.
- Ejes y líneas comparables comparten escala, unidad, granularidad y agregación. Sin doble eje, 3D, perspectiva ni curvas suavizadas que inventen máximos. Barras y áreas parten de cero; línea puede usar rango recortado solo con límites muy visibles y justificación. Nunca invertir un eje para insinuar mejora.
- Color de módulo para serie principal; referencia histórica con s.chart.comparison y trazo discontinuo. Máximo tres series simultáneas por defecto; cuatro solo en comparación explícita de los cuatro módulos, con unidades compatibles o paneles separados. Otros casos requieren selección o pequeños múltiples.
- Paleta de macros fija en toda la app. Series semánticas de módulos conservan nombre y color aunque compartan primitivos con estados. No colorear un dato malo de rojo sin regla de interpretación aprobada.
- Marcador, patrón y etiqueta directa complementan color. Las series contiguas se separan por espacio/fondo oscuro o contorno; no se supone contraste entre dos acentos claros. Una tabla es alternativa exacta, no permiso para una gráfica ilegible.
- Labels usan Caption como mínimo; valor/resumen Body o Metric. Reducir cantidad de ticks antes de reducir letra: aproximadamente tres ticks en espacio estrecho y hasta seis cuando entren, preservando extremos y acceso al detalle. No forzar una etiqueta diaria bajo cada barra.
- Tooltips se activan con tap, hover y teclado. Muestran fecha/intervalo, valor sin redondeo engañoso, unidad, origen/calidad y serie. Se mantienen mientras el usuario los consulta, se cierran explícitamente/Escape y no contienen información crítica exclusiva. No salir del viewport ni tapar foco.
- Líneas strong=2; punto/dato cero visible con diámetro space.1=4, sin atribuirle volumen. Altura preferida 192, no fija: labels y escalado pueden ampliarla. Sparkline preferida 48. Espacios internos no se toman del área de la serie.
- Datos ausentes interrumpen trazos. No unir dos fechas separadas por registros faltantes sin mostrar claramente el hueco. No rellenar con cero, arrastrar último valor, interpolar ni normalizar en silencio.
- No animar números desde cero al abrir. Al actualizar, conservar contexto temporal y selección. Un gráfico necesita alternativa textual con resumen y tabla/lista accesible, con los mismos filtros.

### 11.2 Calidad y significado del dato

| Situación | Representación | Contrato de lectura/cálculo |
|---|---|---|
| **0 confirmado** | «0» y unidad; punto/marca en línea base | Solo si la fuente confirma medición/registro de cero o cobertura completa con total cero. Barra de altura cero, sin mínimo artificial. |
| **Sin datos** | «— · Sin datos»; hueco anotado | Ausencia no es medición. No participa como cero en promedios. No dibujar serie ficticia gris ni círculo de 100%. |
| **Dato parcial** | Valor disponible + «Parcial» + cobertura conocida | Total dice «Total registrado»; media dice n observaciones/días. No extrapolar automáticamente al período completo. |
| **Dato estimado** | «≈» y etiqueta «Estimado»; trazo discontinuo/patrón | Origen y método disponibles. No mezclar con mediciones sin identificar. Intervalo de incertidumbre solo si existe en la fuente. |
| **Dato antiguo** | Valor conservado + fecha absoluta + «Último registro» | No mostrarlo como hoy/anoche. Separar fecha de medición y última sincronización. Un dato histórico no es stale por ser histórico: stale significa que la vista espera una actualización que no está disponible. |

Estas dimensiones pueden coexistir: «≈ 6 h · Estimado · 12 sep · Sin conexión». El estado de red no cambia la calidad original del dato. Si falta cobertura o timestamp, declarar «Cobertura desconocida»/«Fecha no disponible», sin inventarlos. No crear umbrales médicos de colores desde el sistema visual.

### 11.3 Line chart

- **Pregunta:** ¿cómo evoluciona una misma medida a lo largo del tiempo? Usar para carga del mismo ejercicio, duración de sueño o una métrica registrada con historial comparable.
- **Cuándo no:** una observación, categorías sin orden temporal, unidades mezcladas o un score sin definición. Con un punto mostrar el punto y valor; no una tendencia.
- **Colores:** serie = módulo; referencia = comparison discontinuo. Estimado también discontinuo con etiqueta de origen para no confundirse con referencia.
- **Labels y ejes:** X fechas reales, Y valor/unidad; ticks legibles. Línea recta entre observaciones consecutivas conocidas, huecos donde falten. Si Y no parte de cero, ambos límites quedan visibles; nunca usar ese recorte en barras.
- **Tooltip:** fecha, medida, unidad, condición comparable (ejercicio/equipo si corresponde), calidad.
- **Vacío:** «Todavía no hay registros de [medida] en [período]» y acción existente de registrar o cambiar período. Error no se convierte en este vacío.
- **Accesibilidad:** resumen con primer/último valor y cobertura; navegación por observaciones y tabla, sin anunciar cada punto al entrar a la pantalla.

### 11.4 Area chart

- **Pregunta:** ¿cuánto se acumula durante el período? Usar para minutos registrados acumulados de entrenamiento, con definición de inicio y reinicio.
- **Cuándo no:** comparar pequeñas diferencias, varias áreas superpuestas, métricas que no son acumulables o datos insuficientes para conocer el acumulado. No sugerir continuidad de cobertura si falta un día.
- **Colores:** borde módulo opaco + área al s.opacity.area=12%; sin gradiente. El borde, etiquetas y tabla contienen la información esencial.
- **Labels y ejes:** X período; Y acumulado desde cero con unidad. Incrementos discretos se representan como escalones, no pendientes inventadas. Indicar «Acumulado de registros disponibles» cuando corresponda.
- **Tooltip:** fecha, aporte de ese intervalo y acumulado disponible; cobertura visible.
- **Vacío:** sin área de ejemplo; explicar falta de historial. Si el total es cero confirmado, mostrar línea base y «0 [unidad]».
- **Accesibilidad:** tabla con incremento y acumulado. No interpretar el relleno translúcido como una serie adicional.

### 11.5 Bar chart

- **Pregunta:** ¿qué día o categoría tiene mayor cantidad? Usar para totales discretos o comparar categorías con la misma unidad.
- **Cuándo no:** series continuas de alta resolución, demasiadas categorías sin agrupación explícita o escalas diferentes en barras lado a lado.
- **Colores:** módulo para una serie; comparison para referencia. Comparación agrupada con separación space.2 siempre que el ancho lo permita; si no, barras horizontales o paneles.
- **Labels y ejes:** baseline cero obligatoria; categorías completas y unidad. Barras horizontales para nombres largos. No top-N que oculte el resto sin indicar «Otros» y su cálculo.
- **Tooltip:** categoría/fecha, total, unidad, cantidad de registros y calidad. No hacer pasar un día sin registro por inactividad confirmada.
- **Vacío:** sin barras. Cero confirmado se etiqueta en la base sin dar altura mínima. Parcial usa etiqueta/patrón, no un largo supuesto.
- **Accesibilidad:** listado equivalente; categoría, valor y estado navegables; orden visual y orden de lectura iguales.

### 11.6 Sparkline

- **Pregunta:** ¿cuál es la forma general del historial de esta métrica? Usar como contexto de Metric, nunca como única evidencia.
- **Cuándo no:** se necesita leer valores exactos, detectar un umbral crítico o hay menos de dos observaciones comparables.
- **Colores:** módulo, línea strong, sin relleno; huecos reales permanecen.
- **Labels y ejes:** sin ticks interiores, pero período, unidad y valor asociado fuera del dibujo. Las sparklines que se comparan directamente comparten escala o declaran «Escalas independientes».
- **Tooltip:** opcional; si existe, mismo contrato de Line chart. Siempre hay acceso «Ver historial» con datos exactos.
- **Vacío:** conservar métrica conocida; texto «Historial insuficiente», sin línea decorativa.
- **Accesibilidad:** resumen y vínculo a historial; gráfico redundante puede excluirse de semántica si la descripción equivalente ya existe.

### 11.7 Progress

- **Pregunta:** ¿cuánto completé de una meta explícita? Usar barra lineal por defecto; ring solo para una meta central sencilla.
- **Cuándo no:** no existe objetivo fiable, el denominador es cero/desconocido, o se pretende comunicar salud general. Meta fija de demo no es meta personal.
- **Colores:** módulo para cantidad; fondo interactive para track. El texto valor/meta es obligatorio. Success solo con criterio explícito de cumplimiento, no por estética.
- **Labels y ejes:** «Registrado / Meta» + unidad y período. Lineal empieza en cero; ring no tiene eje pero explica denominador. Más de 100% se etiqueta, por ejemplo «120% · 20% sobre la meta», y el dibujo se limita a una vuelta/barra con marca de excedente; no oculta el exceso ni repite vueltas.
- **Tooltip:** valor, objetivo, fuente de objetivo y fecha de vigencia. Si falta origen, decirlo y no mostrar una meta como personalizada.
- **Vacío:** meta inexistente → «Meta no configurada»; datos inexistentes → «Sin registros»; 0 confirmado → 0/meta. No mezclar estos casos.
- **Accesibilidad:** progreso determinado con valor y máximo cuando proceda; porcentaje, cantidad y excedente en texto. Ring siempre tiene alternativa lineal/textual.

### 11.8 Macro visualization

- **Pregunta:** ¿cuánta proteína, carbohidrato y grasa registré, y cómo se distribuyen? Usar tres filas de valores y, si aporta lectura, barras horizontales; composición apilada solo para distribución.
- **Cuándo no:** radar, proporciones de ejemplo, metas fijas incompatibles o mezcla de gramos y energía en un mismo total.
- **Colores:** protein azul, carbohydrate ámbar, fat violeta; constantes en Home, Alimentación y detalles. Etiquetas y valores siempre acompañan el color.
- **Labels y ejes:** barras individuales en g desde cero; si comparan metas, cada barra indica su denominador y el conjunto dice «% de cada meta». Composición por energía usa contribución derivada 4 kcal/g proteína, 4 carbohidrato, 9 grasa y se titula «Distribución energética estimada de estos tres macros». No equipararla silenciosamente a kcal totales de la fuente ni ocultar alcohol/fibra u otros componentes. Por gramos se titula «Distribución por gramos».
- **Tooltip:** gramos, porcentaje si está definido, base del cálculo y origen; segmentos separados con borde oscuro para distinguir colores adyacentes.
- **Vacío:** los tres desconocidos no dibujan segmentos; un macro ausente vuelve parcial la composición y evita normalizar los restantes como si fueran el total. Todos cero confirmados: «0 g registrados», sin división por cero.
- **Accesibilidad:** lista de los tres macros con valores/estado y total utilizado. Orden fijo proteína, carbohidratos, grasas, sin depender de memorizar tonos.

### 11.9 Workout volume

- **Pregunta:** ¿cómo cambió mi volumen registrado bajo un mismo criterio? Usar barras por sesión/período o línea de un ejercicio comparable.
- **Cuándo no:** sumar minutos, repeticiones sin carga y kg×rep como si fueran la misma unidad; comparar máquinas/variantes incompatibles sin aclaración; inferir esfuerzo fisiológico o recuperación.
- **Colores:** workout; referencia comparison. Sin semáforo automático de «más es mejor».
- **Labels y ejes:** X fecha/sesión; Y desde cero en kg·rep o unidad equivalente elegida. Criterio propuesto para futura validación: suma carga externa×repeticiones de series completadas incluidas por la fuente; documentar tratamiento de unilateralidad, asistencia y calentamiento. Ejercicios sin carga se muestran como series/reps/min en otra medida, sin inventar carga corporal.
- **Tooltip:** volumen, series incluidas, unidad original/convertida y exclusiones. Planificado se muestra separado y rotulado, nunca como realizado.
- **Vacío:** «Sin series con carga registradas» puede coexistir con entrenamiento completado sin carga. No declarar ausencia de entrenamiento por ausencia de volumen.
- **Accesibilidad:** tabla por sesión/ejercicio, método y resumen de cobertura. Definición final y reconciliación de fuentes son dependencias antes de implementar.

### 11.10 Muscle distribution

- **Pregunta:** ¿en qué grupos musculares se concentran las series registradas según el catálogo? Barras horizontales para comparar; mapa anatómico para localizar.
- **Cuándo no:** «recuperación», activación medida, fatiga o porcentajes fisiológicos. No mezclar distribución planificada y ejecutada ni pesos/fallbacks del radar actual.
- **Colores:** workout para barras; en mapa, músculo principal con relleno workout y secundario con contorno/patrón de ese color. Regiones no informadas quedan sin relleno, nunca «recuperadas».
- **Labels y ejes:** barras desde cero, «Series asociadas por grupo», nombres completos. Propuesta inicial: una serie completada cuenta una vez en cada grupo principal asociado; un ejercicio multigrupo puede contar en varios. Por ello la suma entre músculos puede superar series totales y **no se presenta como porcentaje del total**. Grupos secundarios se listan separados sin ponderación inventada.
- **Tooltip:** grupo, cantidad, ejercicios origen y criterio de asociación; mapa y barras coinciden en el mismo filtro.
- **Vacío:** si faltan asociaciones, «Sin clasificación muscular» con cantidad de series sin clasificar. No sustituir por una distribución planificada salvo vista explícita «Plan».
- **Accesibilidad:** lista completa de grupos y cantidades; frente/espalda identificables; regiones nunca son el único selector. Semántica final pendiente de validación del catálogo y fuentes.

### 11.11 Sleep timeline

- **Pregunta:** ¿cuándo me acosté y desperté y cómo varían esos horarios? Usar intervalo nocturno y pequeñas líneas por fecha para comparar regularidad.
- **Cuándo no:** hipnograma REM/profundo/ligero sin observaciones reales; inferir fases desde duración, ruido o plantilla.
- **Colores:** sleep para intervalo registrado, comparison para período previo; desconocido deja hueco. Una futura capa de fases requiere contrato y tokens propios aprobados.
- **Labels y ejes:** X hora local sobre un eje continuo que cruza medianoche con fecha visible; Y fecha/noche en vista semanal. Misma ventana horaria para comparación; si un intervalo cae fuera, ampliar escala común, no recortarlo sin aviso. Diferenciar tiempo entre acostarse/levantarse de tiempo efectivamente dormido según campos disponibles.
- **Tooltip:** inicio/fin con fecha, duración registrada o derivada rotulada, zona horaria si hay ambigüedad, origen y calidad. Si solo hay duración sin horarios, usar Metric o barras, no inventar un intervalo.
- **Vacío:** «Sin horarios registrados»; inicio o fin faltante produce intervalo incompleto claramente marcado, sin duración supuesta. Nunca llamar «anoche» al último registro antiguo.
- **Accesibilidad:** lista por noche con inicio, fin y duración; navegación por filas; describir cruce de fecha. No diagnosticar calidad clínica mediante esta gráfica.

### 11.12 Trend indicators

- **Pregunta:** ¿cuánto cambió una medida respecto de una referencia definida? Usar delta numérico con flecha direccional, período y unidad.
- **Cuándo no:** una sola observación sin referencia, cobertura incompatible, denominador cero para porcentaje o una tendencia estadística no calculada.
- **Colores:** text.primary/secondary por defecto; success/error solo si la dirección deseable y criterio de evaluación están documentados. ↑ duración de sueño o ↓ peso no son mejora universal.
- **Labels y ejes:** sin ejes; «+15 min frente a la semana anterior» es completo. Delta relativo = (actual−referencia)/referencia×100 solo con referencia positiva y medida compatible; si referencia=0 mostrar diferencia absoluta y «Sin base porcentual». No «+∞%».
- **Tooltip:** ambos valores, fórmula, períodos exactos y cobertura. No sustituye el período visible.
- **Vacío:** «Sin comparación disponible»; mantener el valor actual conocido. Delta cero confirmado dice «Sin cambio», sin flecha ascendente.
- **Accesibilidad:** frase «Aumentó/disminuyó/sin cambio…»; flecha decorativa cuando duplica esa frase.

### 11.13 Weekly comparison

- **Pregunta:** ¿qué cambió en un período semanal comparable? Barras agrupadas, dos métricas alineadas o pequeños múltiples según densidad.
- **Cuándo no:** semana actual parcial contra una semana completa presentada como equivalente; zonas horarias, definiciones o fuentes diferentes.
- **Colores:** actual módulo, previa comparison con patrón distinto; etiquetas «Actual» y «Anterior» con fechas, no solo leyenda cromática.
- **Labels y ejes:** fechas de inicio/fin inclusivas y regla de inicio de semana del producto/locale explícita. Comparación predeterminada propuesta: últimas dos semanas cerradas con misma cobertura. Si se muestra semana en curso, comparar hasta el mismo día/hora de la anterior y rotular ambos cortes; no declarar equivalencia cuando la cobertura difiere.
- **Tooltip:** valor, número de días/observaciones incluidos, agregación y delta. Media por día registrado solo si ambos lados lo declaran; días sin registro no se vuelven cero.
- **Vacío:** un período ausente → mostrar el otro con «Sin referencia». Cobertura desigual → valores disponibles y badge parcial, sin conclusión automática de mejora.
- **Accesibilidad:** tabla de los dos períodos y sus coberturas; escala compartida. Un total de semana parcial dice «Registrado hasta…».

### 11.14 Month-over-month

- **Pregunta:** ¿cómo cambió el volumen o promedio entre meses? Usar pares de barras/métricas y tendencia de meses cerrados.
- **Cuándo no:** equiparar meses de distinta duración sin explicar efecto en totales; mes en curso frente a completo sin corte equivalente; porcentajes con base ausente/cero.
- **Colores:** módulo para mes actual analizado; comparison para referencia.
- **Labels y ejes:** nombre y año del mes, unidad, suma o media claramente identificada. Para totales, mostrar cantidad de días del mes y cobertura; para media, denominador real. No normalizar totales por días sin cambiar título/unidad. Mes en curso compara solo fechas equivalentes disponibles en ambos meses; si falta el mismo día en el anterior, usar último día común y declarar el corte, sin extrapolar.
- **Tooltip:** fechas exactas, total/media, días con datos y denominador; diferencia absoluta y relativa solo cuando procede.
- **Vacío:** historial menor a dos períodos comparables → métrica conocida y «Historial insuficiente para comparar meses». No llenar meses previos con cero.
- **Accesibilidad:** resumen y tabla mensual; mismas reglas de teclado y calidad que Weekly comparison.

### 11.15 Límites de alcance analítico

Correlaciones, puntuaciones compuestas de salud, predicciones y fases de sueño están fuera de v0.1. No se inventa una «muestra mínima científica» global. Cada análisis futuro debe justificar observaciones, comparabilidad, incertidumbre y significado con su propio contrato. Las etiquetas de ejemplo de esta especificación son copy ilustrativo, no datos de usuario ni fixtures a publicar.

## 12. Media system

Media hereda `c.media`. Nunca es necesaria para comprender una acción crítica. Nombre, acción, unidad y estado siguen disponibles si la imagen falta. Las fotografías no se usan como fondo de métricas ni se agregan heroes decorativos a Home.

En Entrenamiento, la acción de inicio puede incluir una fotografía editorial local de personas entrenando y equipamiento. Es media decorativa dentro de `c.card`, con recorte `s.ratio.wide`, radio `s.shape.card` y texto/acción visibles también en el fallback de superficie. Usa el `s.scrim` existente para legibilidad; no presenta la foto como ejercicio, progreso ni imagen de la persona usuaria. El asset inicial `assets/images/workout/training_hero.png` fue generado para FIT_APP; no proviene de una biblioteca de ejercicios ni sustituye la cobertura de media pendiente para cada ejercicio. Home global mantiene la regla de no agregar un hero decorativo.

### 12.1 Contrato compartido

- Reservar proporción antes de descargar. Loading = bloque estático de superficie interactive con semántica breve; no foto borrosa ficticia ni shimmer continuo.
- Si existe copia local válida, conservarla durante recarga u offline. Si no existe, fallback local de categoría + texto. Un error de imagen no vacía los datos asociados.
- «Sin imagen» significa recurso ausente; «No se pudo cargar la imagen» significa fallo. No sustituir una foto privada fallida por una foto de otra persona/comida.
- Las proporciones son opciones cerradas de s.ratio. Miniaturas en filas miden s.size.target=48; ilustración de vacío máximo s.size.media-empty=96. Una imagen a ancho de contenido calcula altura a partir de su ratio, no de una cifra por pantalla.
- Evitar doble redondeo: imagen a sangre en card comparte clip del contenedor, sin margen y radio independientes. Media autónoma usa radio card; miniatura de fila usa shape.small. Una ilustración interna sin marco usa shape.none.
- Descripción alternativa basada en contenido y contexto. Decorativa redundante se excluye; foto accionable tiene nombre de acción adicional. No inferir características corporales, composición nutricional o desempeño desde una imagen.
- Guardar procedencia/licencia y vinculación exacta al registro durante futura incorporación. Una imagen generada para ambientación se usa como recurso editorial decorativo, nunca como foto real del usuario, del alimento o de una sesión concreta. Las tres imágenes locales del piloto de Entrenamiento se documentan en `assets/README.md`.

### 12.2 Tipos y variantes

Todos los tipos de esta tabla heredan loading/offline anteriores; la columna específica indica excepciones y semántica.

| Tipo | Proporción y recorte | Radio | Fallback / loading / offline | Semántica y límites |
|---|---|---|---|---|
| Exercise illustration | Landscape 4:3 en detalle, square 1:1 en fila; contain | None en contenido; small en miniatura | Icono de equipo + nombre de ejercicio; bloque reservado; asset local preferido | Mostrar postura/equipo/variante con revisión técnica. No recortar articulaciones necesarias; instrucciones textuales siguen disponibles. |
| Muscle map | Portrait 3:4 por vista; contain; frente/espalda en pareja si caben | None | Silueta neutral + lista muscular; asset local; ante fallo, lista permanece | Regiones según catálogo y criterio de §11.10. No representar lesión, activación medida ni recuperación sin datos válidos. |
| Food photography | Square 1:1; cover con foco verificable | Small en fila; card en detalle | Icono de categoría + nombre; carga estática; cache o placeholder offline | Foto vinculada exactamente al alimento; una foto de categoría se rotula «Imagen de referencia». Porción y preparación en texto, nunca deducidas de foto. |
| Meal photography | Landscape 4:3 en detalle, square en miniatura; cover | Card / small | Icono de plato + nombre de comida; no imagen aleatoria; cache o fallback | Foto real asociada a comida/plantilla. No simular alimentos ni cantidades no registrados. Captura/subida requiere trabajo funcional posterior. |
| User media | Avatar square recortado circle; progreso conserva proporción original en visor contain; square solo en miniatura | Circle en avatar, card en galería | Iniciales si existen o icono persona; recurso autorizado en cache; fallo no reemplaza identidad | No estirar cuerpo ni aplicar filtros que alteren evolución. Fecha real y descripción del usuario si existe; privacidad y acceso conservados. |
| Routine thumbnail | Wide 16:9 en preview, square en lista; contain para esquema | Card / small | Equipo o esquema muscular neutral + nombre; asset local | Ayuda a reconocer rutina, no comunica resultados prometidos. No mosaicos aleatorios de cuerpos. |
| Empty-state illustration | Square 1:1, máximo 96; contain | None | Icono large o solo texto; no exige red; loading no usa esta ilustración | Recurso sutil opcional. Nunca reemplaza «Sin datos», causa y acción. No trofeos, confeti ni culpabilización por ausencia. |
| Placeholder | Hereda proporción del slot; icono centrado default | Hereda radio del slot | Siempre local y estable, reemplazable al llegar recurso | No parece foto o gráfico real. Si duplica nombre ya visible es decorativo; si anuncia fallo lo hace una vez con texto. |

## 13. Movimiento

Tiempos de transición: fast 120 ms, normal 200 ms, slow 320 ms. Curvas registradas en s.motion.curve; no springs, rebotes, parallax ni stagger decorativo en esta versión. La respuesta de pressed empieza inmediatamente y llega al estado sin esperar operaciones de red.

| Uso | Duración / curva | Qué cambia | Reduce Motion |
|---|---|---|---|
| Micro interaction | fast / standard | Color de hover/pressed; foco aparece inmediatamente | Estado directo sin desplazamiento |
| State transition | normal / standard | Opacidad de contenido al cambiar de estado sin perder dimensiones | Reemplazo directo y anuncio textual |
| Page transition | slow / enter al entrar; normal / exit al salir | Transición sobria coherente con flujo y plataforma; máximo desplazamiento space.4 | Sin traslación, transición directa; preservar gesto de volver del sistema |
| Chart animation | normal / standard | Crossfade entre datos válidos, sin dibujo progresivo desde cero | Datos finales inmediatos; ninguna interpolación visual |
| Loading animation | loading-cycle 1000 ms / linear | Spinner solo mientras existe trabajo real; skeleton estático como preferencia | Icono estático + «Cargando…», semántica busy; no giro ni pulso |

No usar animación para ocultar latencia ni retrasar interacción. No repetir entradas al hacer scroll. No confeti por racha ni brillo pulsante durante la sesión. Progreso determinado puede actualizarse con el valor real; desconocido no simula porcentaje. Nuevos datos no reinician una animación interminable.

Si el sistema solicita reducción de movimiento o la app dispone de una preferencia equivalente, gana la opción más restrictiva. En Flutter la futura implementación consulta [MediaQuery.disableAnimationsOf](https://api.flutter.dev/flutter/widgets/MediaQuery/disableAnimationsOf.html); web debe respetar la preferencia del sistema. Un timestamp o cronómetro continúa actualizándose sin que eso obligue a anunciar cada segundo ni a animar el cambio.

## 14. Contratos de estados

Los estados describen el recurso o la operación concreta, no necesariamente toda la pantalla. No ocultar contenido válido por un fallo de otra sección. Se combinan de forma explícita: permiso determina acceso, error describe la operación, offline la conexión, stale la vigencia y partial la cobertura. Solo mostrar Empty tras una respuesta válida que confirma ausencia.

| Estado | Presentación | Texto/acción | Semántica y persistencia |
|---|---|---|---|
| Loading inicial | Skeleton estático reservado o spinner de trabajo real | «Cargando [recurso]…» | Busy; no mostrar ceros ni empty. Si falla, salir de loading hacia error. Reintentar usa operación real. |
| Loading de actualización | Conservar datos previos y pequeño indicador | «Actualizando…» junto a última actualización si conocida | No cubrir controles ajenos. Si falla, mantener snapshot y señalar error/stale. |
| Empty | Icono opcional, título, una frase y acción existente | «Todavía no registraste [dato]» / «Registrar…» | Solo después de éxito de carga. Sin métrica inventada ni animación de carga. |
| Partial data | Valores disponibles + etiqueta y cobertura | «3 de 7 días con registros», solo si esos números son conocidos | Leer parcial antes de conclusión. Completar registro o consultar detalle, sin inventar días restantes. |
| Error | Icono error + texto legible; conservar entrada/datos válidos | «No pudimos cargar [recurso]» + «Reintentar» si operable | Error inline por campo; resumen para múltiples errores. No colapsar en vacío ni mantener spinner. |
| Offline | Aviso con icono y texto information; cache si existe | «Sin conexión · Datos guardados en este dispositivo» si es cierto | Mostrar hora de sincronización conocida. No prometer guardado o sincronización que el flujo actual no soporte. |
| Success | Check + texto breve en success | «Registro guardado» solo tras confirmación correspondiente | Anuncio polite una vez; no confeti. Guardado local pendiente de sync debe decirlo. |
| Disabled | Fondo disabled, texto disabled, sin acción | Motivo visible en texto secondary fuera del control | Estado disabled real. No desactivar sin explicación la única salida. Readonly no es disabled. |
| Permission denied | Icono de acceso + mensaje neutral | «Sin permiso para acceder a [recurso]»; acción de configuración si existe | No fingir que el recurso está vacío. Alternativa manual solo si ya existe; no reabrir permiso en bucle. |
| Stale data | Dato visible, fecha y etiqueta muted/information | «Último registro: 12 sep» o fecha real; actualizar si disponible | No etiquetar como hoy. Si no hay política temporal de frescura, mostrar fecha sin inventar un vencimiento. |

Errores destructivos o de persistencia no desaparecen en un snackbar antes de que puedan leerse. Una falla de imagen se limita a media. Si la UI actual no expone estos estados, se registra la dependencia y el piloto muestra el caso definido; no se modifica lógica en Fase 2A.

## 15. Accesibilidad y validación futura

Objetivo WCAG 2.2 AA, con target interno más amplio y métricas de alto contraste. Estas son condiciones de aceptación futuras, no afirmación de conformidad de la app actual.

| Área | Requisito de FIT_APP | Verificación posterior |
|---|---|---|
| Contraste | Pares permitidos de §3; texto ≥4.5:1 y gráficos/controles esenciales ≥3:1 | Medir default, hover, pressed, selected, foco y combinaciones compuestas; no asumir que un token aislado «es accesible» |
| Texto ampliado | Escalado del sistema, sin clamp de usuario, mínimo prueba 200%; reflow a ancho 320 | Nombres largos, unidades largas, mensajes de error y métricas. No overflow, encogimiento automático ni controles cortados. Probar más allá de 200% si el sistema lo ofrece |
| Touch target | Mínimo 48×48 unidades lógicas, gap preferido mínimo 8 entre objetivos independientes | Filtros, close, limpiar búsqueda, series y toolbar. Es regla interna; no confundirla con el mínimo web de WCAG |
| Teclado | Tab/Shift+Tab lógico; Enter/Space activan; flechas en grupos/tablas según semántica | Ninguna acción solo por drag/swipe. Escape cierra overlays no destructivos; cancelación explícita cuando cerrar perdería datos |
| Foco | Anillo strong=2 con separación space.1, no oculto por sticky/teclado | Focus dentro de modal, retorno al invocador, no trampas fuera del modal; no trasladar foco por carga de datos |
| Screen reader | Nombre, rol, valor y selected/expanded/disabled correctos | Orden de lectura coincide con jerarquía; unidad expandida en números; iconos redundantes ocultos; headings consistentes |
| Gráficos | Resumen, unidad, período, cobertura y tabla/lista equivalente | Navegación sin puntero, actualización anunciada una vez, sin cientos de nodos decorativos ni lectura de cada tick |
| Movimiento | Reduce Motion de §13 | Sin giro, parallax ni desplazamiento cuando está activo; feedback comprensible estático |
| Formularios | Labels persistentes, ayuda y error asociados; conservar entrada | Error junto a campo y resumen enfocable si hay varios; permitir pegar y gestores de contraseñas en autenticación |

Escenarios mínimos futuros: anchos 320, 360, 390, 430, 600, 768, 1024 y 1440; justo antes/después de cada breakpoint; orientación horizontal/altura reducida; texto 1× y 2×; teclado; touch y mouse; lector de pantalla; Reduce Motion. Datos: 0 confirmado, ausencia, una observación, historial suficiente, parcial, estimado, antiguo, error y offline. También probar estados combinados: selected+focus y error+focus.

No se ejecutan pruebas de UI ni builds en esta fase documental. Contraste matemático no sustituye revisión del renderizado, daltonismo, foco, semántica ni accesibilidad real del árbol Flutter.

## 16. Gobernanza

### 16.1 Reglas de entrada

- Ningún color nuevo sin primitivo, rol semántico y consumidor documentado.
- Ningún tamaño tipográfico arbitrario ni familia nueva por pantalla.
- Ningún radio nuevo sin caso que no puedan resolver los cuatro radios finitos existentes.
- Ningún componente duplicado por razones visuales. Los contratos funcionales distintos pueden compartir receta sin fusionar lógica.
- Ningún gráfico sin pregunta, fuente, unidad, agregación, cobertura y estados documentados.
- Ninguna imagen ficticia presentada como información real. Fotos de referencia se identifican como tales.
- Ningún hardcode de altura para resolver contenido variable ni clearance inferior constante independiente de barras.
- Ningún permiso visual implica modificar modelos, navegación, autenticación, persistencia o integraciones.
- La ausencia de especificación no permite copiar el estilo local de una pantalla y declararlo estándar.

### 16.2 Excepciones, versión y propiedad

El usuario es el aprobador de la dirección visual. El responsable de implementación propone y verifica, no se autoaprueba cambios de significado. Los agentes consultan este archivo antes de extender el sistema.

Una excepción se registra **en este documento**, con ID `EX-###`, problema, consumidor, regla afectada, alternativas probadas, valor/token propuesto, evidencia de contraste/escala, impacto Figma–Flutter, responsable, fecha y condición de retirada. Presentarla para aprobación antes de uso en producto. Una urgencia no la convierte silenciosamente en token global. No hay excepciones aprobadas en v0.1.

No requieren nueva aprobación de identidad los cálculos de layout ya autorizados por §8 o seleccionar una variante documentada. Sí la requieren nuevos colores/estilos, cambios de significado, nuevos tipos de gráfico y ruptura de contratos. Los cambios puramente editoriales corrigen el documento sin abrir trabajo de implementación.

Versionado: patch para correcciones sin cambio visual; minor para extensiones compatibles; major para renombrar/remover tokens o cambiar significado. Registrar reemplazo y plazo de retiro de tokens obsoletos. Esta v0.1 pasa a v1.0 solo tras aprobación explícita; no hay aprobación implícita por generación del archivo.

### 16.3 Correspondencia Figma–Flutter

Nombre canónico con puntos en este documento; Figma puede mostrarlo con barras (`s/text/primary`) mediante transformación reversible. Flutter puede agrupar en propiedades tipadas con una tabla de correspondencia, pero no renombrar semántica libremente.

Primitivos y semánticos simples → variables; tipografía → estilos de texto; recetas compuestas → componentes/variantes documentados. Curvas y contratos de datos → anotaciones; no todo objeto se representa como una variable nativa. Auto Layout expresa min/max, padding y wrap; no demuestra text scaling del sistema ni semántica de lector.

Figma y Flutter deben registrar la versión del documento utilizada. Un cambio comienza aquí, actualiza las representaciones después de autorización y se comprueba por valores resueltos y capturas. No mantener dos paletas manuales divergentes. Tokens compuestos son una especificación legible, **no un archivo DTCG/JSON ejecutable**; el formato de intercambio futuro se definirá sin cambiar sus valores.

## 17. Migración posterior — no ejecutar en Fase 2A

### 17.1 Etapas y puertas de salida

| Etapa futura | Trabajo | Criterio para avanzar |
|---|---|---|
| 1. Aprobar especificación | Resolver decisiones de §19 y versionar v1.0 | Aprobación explícita del usuario |
| 2. Pilotos Figma autorizados | Home, Entrenamiento y Perfil; sesión y búsqueda prueban densidad | Frames con datos reales/identificados, estados y ancho pequeño; aprobación visual |
| 3. Preparar foundations Flutter | Mapeo tipado, tema local del piloto, estados e iconos equivalentes | Tokens contrastados, sin cambio global de módulos todavía no migrados |
| 4. Componentes piloto | Construir familias necesarias y previews aisladas | Estados y texto ampliado; revisión visual además de pruebas |
| 5. Un flujo completo por vez | Home/entrenamiento según alcance aprobado, luego alimentación, sueño, hábitos y restantes | Navegación, sesión, borradores y persistencia conservados; revisión focalizada |
| 6. Convergencia | Extender adapters, retirar estilos viejos donde no existan consumidores | Búsqueda sin referencias pendientes, paridad funcional y visual; tema claro atendido antes de alcance global |

La lista no ejecuta ni preautoriza esas etapas. No se crea Figma ni se altera Flutter al entregar este documento.

### 17.2 Mapeo de la base actual

| Origen actual | Destino conceptual | Estrategia incremental / riesgo |
|---|---|---|
| `AppColors.background/card/surface` | `s.background`, `s.surface`, `s.surface.interactive` según función | No mapear «surface» por nombre sin mirar el uso. Adapter por piloto; conservar consumidores legacy hasta migrarlos |
| `AppColors.accent/accentSecondary` y azul del tema | Roles `s.action.*` | Acción primaria turquesa en ámbito migrado. No reemplazo global de hexadecimal que recoloree series o estados |
| `AppColors.accentTraining/Food/Sleep` | `s.module.workout/nutrition/sleep` | Verificar si uso es dato o CTA; los CTA pasan al rol de acción |
| `ThemeData` actual | ColorScheme/TextTheme + extensiones para módulos, métricas y geometría | Alcance local primero; roles Material no cubren toda la semántica. No invertir ni eliminar tema claro |
| `SummaryCard` | `c.card` o Section sin superficie según propósito | Elegir por contenido; retirar minHeight 140/glass solo en instancias migradas. No cambiar el widget global y alterar todas las pantallas de golpe |
| Cards locales y métricas | `c.card`, `c.metric`, `c.list-row`, `c.section-header` | Unificar presentación manteniendo contratos/controladores existentes; no fusionar dos ExerciseCard funcionalmente distintas sin análisis propio |
| Estilos hardcodeados | Token/receta con función equivalente | Buscar, clasificar y migrar por flujo; si no hay equivalencia, documentar excepción, no añadir otro número |
| Radar/barras/progress actuales | `c.chart` y contrato analítico específico | Validar fuentes antes del styling; no conservar gráficos falsos para «mantener la forma» |

Mapeo Material futuro orientativo: primary→s.action.primary, onPrimary→s.action.on-primary, surface→s.surface, onSurface→s.text.primary, outline→s.border.control, error→s.status.error; scaffold background→s.background. Métricas, módulo y calidad se mantienen como roles propios; no sobrecargar primary/secondary para representarlos.

Flutter permite extensiones de ThemeData para roles adicionales ([ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html)). Layout se basa en constraints locales ([LayoutBuilder](https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html)); texto conserva el escalador ([MediaQuery.textScalerOf](https://api.flutter.dev/flutter/widgets/MediaQuery/textScalerOf.html)). Son puntos de viabilidad, no una librería ya implementada ni una promesa de exportación automática desde Figma.

### 17.3 Verificación y reversibilidad

Antes de migrar un flujo: fotografiar su estado real, registrar operaciones y calidad de datos, y aislar cambios locales preexistentes del repositorio. Después: pruebas focalizadas sobre registro/continuidad afectados, capturas comparables y texto ampliado. Goldens antiguos o rutas alternativas no sustituyen la ruta activa. Revertir solo el lote migrado si falla; mantener estado y datos de usuario. No reformatear ni tocar archivos ajenos a la migración.

Dependencias funcionales separadas: metas nutricionales fiables y comunes; reconciliación de fuentes de totales; Perfil/Grupos con datos reales o estados explícitos; calidad/cobertura temporal; volumen y asociación muscular; incorporación persistente de nuevas fotos. Mientras no se resuelvan, usar estados honestos ya permitidos, no inventar una capa de datos para satisfacer un diseño.

## 18. Autoauditoría de la especificación

**Resultado: revisión documental completada, sin iniciar implementación.** La conformidad visual y accesible del producto sigue pendiente de los pilotos y pruebas renderizadas.

### 18.1 Inventario y consistencia

Conteo realizado sobre IDs declarados en la primera columna de las tablas del registro, no sobre menciones en prosa:

| Revisión | Resultado |
|---|---|
| Tokens primitivos | 51 entradas: 24 colores y 27 escalas/estilos/configuraciones |
| Tokens semánticos | 66 entradas: 37 colores/roles de color, 12 estilos de texto y 17 roles geométricos/configuraciones |
| Tokens de componente | 22 recetas: base común, variantes y familias; cubren las 16 familias requeridas, gráfico y media |
| Total de registro | 139 IDs únicos; los campos internos de tokens compuestos no se cuentan como IDs independientes |
| Colores duplicados | 24 valores distintos en 24 primitivos. Coincidencias entre roles son aliases intencionales, no otra paleta |
| Nombres duplicados | Ninguno en el registro; nombres de propiedades se resuelven por ID exacto/prefijo más largo |
| Referencias | Revisión de IDs y propiedades contra el registro; los comodines de familias son explicativos, no tokens sin resolver |
| Jerarquía | Primitivos → semánticos → recetas; las herencias de recetas y aliases no tienen ciclos |
| Tipografía | 12 roles, 9 tamaños distintos, pesos 400/500/600/700; coincidencia de tamaño no implica el mismo uso |
| Radio y espacio | Cuatro radios finitos positivos: 8/12/16/24, más none/pill/circle geométrico; diez pasos espaciales positivos y cero |
| Cobertura solicitada | 17 áreas, 16 familias UI, 12 tipos de visualización y 8 tipos de media; estados comunes y específicos documentados |

No interpretar «139 tokens» como 139 variables escalares a exportar: los compuestos se desglosarán en estilos/propiedades de plataforma. Este agrupamiento evita una tabla repetida por estado y pantalla, pero no autoriza crecimiento oculto de sus propiedades. Una nueva hoja del compuesto se revisa igual que un nuevo ID. No se crean escalas cromáticas sin uso, sombras, gradientes o radios por módulo.

La revisión detectó que el muted inicialmente considerado no alcanzaba 4.5:1 sobre pressed y que el borde funcional necesitaba más luminancia; se corrigieron antes de entregar a slate-300 y slate-400 de este registro. También se explicitó el prefijo más largo para evitar ambigüedad entre tokens simples y propiedades. En el cierre de Fase 2A se retiraron tres valores internos derivados —`p.opacity.none`, `p.opacity.full` y `p.duration.none`— porque representan cero/uno sin consumidor semántico. Se eliminaron además dos IDs semánticos: `s.action.secondary` y `s.action.on-secondary`, que solo renombraban `s.surface.interactive` y `s.text.primary` para un único botón. El conteo de IDs baja de 141 a 139; las tres primeras simplificaciones reducen propiedades, no IDs.

### 18.2 Contraste calculado

Cálculo sRGB: linearizar cada canal con umbral 0.04045, obtener luminancia relativa `0.2126R + 0.7152G + 0.0722B` y ratio `(Lmayor+0.05)/(Lmenor+0.05)`. Se probaron **80 pares**: once colores de texto/acento/borde sobre siete fondos oscuros permitidos, más on-primary sobre tres estados sólidos. Comparación contra umbrales con precisión completa; valores siguientes redondeados solo para lectura.

El peor fondo oscuro es surface.pressed (`#344963`). Los fondos de reposo, elevated, hover y selected obtuvieron contraste mayor:

| Frente / fondo más exigente | Ratio | Evaluación |
|---|---:|---|
| Text primary / pressed | 8.13:1 | Supera 4.5 |
| Text secondary / pressed | 6.03:1 | Supera 4.5 |
| Text muted / pressed | 4.68:1 | Supera 4.5 |
| Border control / pressed | 3.41:1 | Supera 3 para contorno esencial |
| Action/workout / pressed | 5.52:1 | Supera 4.5 |
| Success / pressed | 5.29:1 | Supera 4.5 |
| Warning/nutrition / pressed | 5.86:1 | Supera 4.5 |
| Error / pressed | 4.56:1 | Supera 4.5; margen pequeño, no reducir opacidad |
| Information/protein / pressed | 4.83:1 | Supera 4.5 |
| Sleep/fat / pressed | 4.64:1 | Supera 4.5 |
| Habits / pressed | 4.97:1 | Supera 4.5 |
| On-primary / primary default | 10.87:1 | Supera 4.5 |
| On-primary / primary hover | 12.40:1 | Supera 4.5 |
| On-primary / primary pressed | 8.48:1 | Supera 4.5 |

Foco usa el mismo color de text.primary sobre gap oscuro. La evaluación no atribuye cumplimiento a bordes sutiles, tracks/áreas de baja opacidad o texto disabled; sus restricciones están documentadas. El scrim no lleva contenido legible ni controles de fondo activos: el contenido modal utiliza elevated opaco, ya evaluado. No se aprobaron pares entre acentos adyacentes ni texto sobre imágenes; se exige separador oscuro/etiqueta o superficie opaca.

### 18.3 Viabilidad, escalabilidad y límites

| Criterio | Conclusión | Pendiente antes de producción |
|---|---|---|
| Flutter feasibility | Tamaños lógicos, mínimos flexibles, temas/extensiones, estados y curvas trasladables; no exige modificar modelos para definir el lenguaje | Confirmar versión del SDK y equivalencias de iconos; implementar y probar TextScaler, foco, semántica y charts |
| Figma feasibility | Variables simples, estilos tipográficos, Auto Layout y variantes expresan foundations/recetas | No se ha creado ni inspeccionado un archivo Figma en esta fase; tokens compuestos requieren mapeo, semántica/motion quedan anotados |
| Escalabilidad | Un modo Dark completo; aliases por intención; receta compartida sin nombres de pantalla; límites de ancho y densidad | Especificar Light antes de migración global; cambios de dimensión/calidad pueden requerir trabajo funcional separado |
| Duplicaciones | Display y Metric Large comparten tamaño por ritmo, pero difieren en tracking/cifras/uso; radios de card y contenedor grande se fusionan | No fusionar funciones de dominio solo por parecido visual |
| Datos | Los doce gráficos incluyen pregunta, uso/no uso, colores, labels, ejes, tooltip, ausencia y acceso equivalente | Verificar fuentes, metas y agregaciones; ningún gráfico nuevo está habilitado solo por estar especificado |
| Alcance | Un único archivo entregado en outputs; sin cambios de app, lógica, rutas, modelos, Firebase/Hive o Figma | Aprobación del usuario antes de la siguiente fase |

No se ejecutaron builds, tests Flutter ni tests de accesibilidad sobre la app, porque no hubo implementación. El chequeo matemático y la inspección documental no certifican renders ni comportamiento de tecnologías asistivas.

## 19. Decisiones para aprobación y preguntas abiertas

### Decisiones propuestas que requieren aprobación

1. **Dirección visual:** oscuro azul grisáceo, turquesa moderado como única acción principal y acentos semánticos por módulo; reemplaza la competencia azul/turquesa del estado actual.
2. **Foundations:** conservar Inter, adoptar la escala tipográfica de 12 roles, radios 8/12/16/24, superficies sin glass/gradientes/sombras y separación por espacio.
3. **Iconografía:** Material Symbols Outlined con ejes fijos y selección por indicador + etiqueta.
4. **Contratos analíticos propuestos:** semanas cerradas como referencia predeterminada; comparación de períodos parciales solo con cortes explícitos; volumen homogéneo y distribución muscular por series asociadas en lugar de radar ambiguo. Aprobación conceptual no sustituye validar los datos.

### Riesgos y cuestiones que necesitan resolución antes de implementar

- ¿Cuál es la fuente canónica de metas nutricionales y qué vistas comparten sus valores? No asumir que 2000 o 2400 kcal actuales son una meta personal.
- ¿Qué historial y timestamp son autoridad para entrenamiento, nutrición y sueño? Si los totales no se reconcilian, no se puede prometer igualdad entre resumen y detalle.
- ¿El catálogo permite contar grupos musculares principales consistentemente y separar planificado/realizado? El criterio aquí propuesto debe contrastarse con datos reales; no estima fatiga.
- ¿Qué política de frescura y origen estará disponible por métrica? Hasta definirla, mostrar fecha conocida sin un umbral universal inventado.
- ¿Qué contenidos reales y licencias habrá para media e iconos? Nuevas cargas de fotos, permisos y almacenamiento son alcance funcional posterior.
- El tema claro no está especificado aquí. Antes de migrar componentes globales, necesita cobertura equivalente o aislamiento explícito del piloto oscuro.
- Contraste nominal está comprobado; tamaño 320, texto ampliado, ajuste de navegación y tablas de series requieren prueba renderizada posterior. El documento no certifica la app actual.
- Permisos del archivo Figma, librería final de gráficos y estrategia de assets se verifican cuando se autorice esa fase; no bloquean la especificación documental.

**Punto de parada:** entregar este documento, esperar aprobación y no iniciar Figma, componentes, pantallas ni migración Flutter.

## Aplicación autorizada · Entrenamiento, 2026-10-12

El prompt maestro posterior del usuario autoriza el rediseño Flutter de sesión,
descanso, resumen, historial y detalle. El punto de parada anterior correspondía
a la Fase 2A documental y no limita este encargo posterior.

Se reutilizan Inter, Dark Premium, acento de Entrenamiento, spacing 4/8/12/16/24/32,
radios 8/12/16/24, área de chart al 12%, scrim al 64% y movimiento normal 200 ms.
`lib/features/common/theme/app_layout.dart` expone estos valores registrados;
no añade una segunda paleta ni nuevos IDs al registro de tokens.

La autorización concreta incorpora un hero decorativo de 200 unidades en el
resumen/detalle guardado, dentro del intervalo 180–220 indicado por el usuario.
Usa escultura deportiva 3D local y no representa anatomía, activación o resultados
del usuario. Métrica, unidad y fecha provienen del registro. Con texto ampliado,
la métrica pasa debajo de la imagen y el grid se reorganiza en una columna compacta.
Las miniaturas de historial usan target=48, shape.small y el vacío media-empty=96.
Los gráficos mantienen unidades separadas, cero real, alternativas semánticas,
etiquetas y metodología explícita. El movimiento se desactiva con la preferencia
del sistema. El inventario y los prompts están en `WORKOUT_ASSETS_2026_10_12.json`
y `WORKOUT_ASSET_PROMPTS_2026_10_12.json`.

Figma no se modifica en este encargo. La validación móvil y el tema claro siguen
sin certificación; las capturas de Windows no los sustituyen.
