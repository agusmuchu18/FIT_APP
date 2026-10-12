# Assets visuales de FIT_APP

- `images/workout/session_strength.webp`: imagen editorial generada para la entrada a Entrenamiento libre. Persona adulta haciendo sentadilla con barra. Es decorativa; no representa una sesión ni un usuario real.
- `images/workout/equipment_detail.webp`: imagen editorial generada para la búsqueda de rutinas. Manos y mancuernas en gimnasio. Es decorativa; no representa una rutina concreta.
- `images/workout/routine_builder.webp`: imagen editorial generada para la entrada a Nueva rutina. Persona adulta preparando discos y mancuernas. Es decorativa; no representa un ejercicio guardado.
- Las tres imágenes se generaron para FIT_APP el 2026-09-29 y se optimizaron a WebP: las dos horizontales a 1279×720 y `routine_builder.webp` a 960×960. Se empaquetan localmente para uso offline. Mantener texto/acciones fuera de la imagen y un fallback de superficie si falla la carga.
- `fonts/Inter-Variable.ttf`: fuente Inter obtenida de [Google Fonts](https://github.com/google/fonts/tree/main/ofl/inter). Su licencia SIL Open Font License está en `fonts/OFL-Inter.txt`.

La iconografía propia es código vectorial en `lib/features/common/widgets/fit_glyph.dart`.

## Informes de Entrenamiento · 2026-10-12

Diez imágenes generadas mediante `image_gen` integrado: `summary_hero.webp`,
`history_empty.webp` y `history_{push,pull,legs,fullBody,arms,cardio,mobility,mixed}.webp`.
Esculturas deportivas 3D completamente vestidas y equipo, navy/turquesa. Son
decorativas; las categorías proceden de datos del catálogo y no de las imágenes.
No representan sesiones/personas reales ni un mapa de activación muscular.

WebP calidad 82: hero máximo 960, vacío 640, categorías 384; 88.294 bytes en total.
Originales conservados fuera del repositorio en el destino del generador; todos los
assets consumidos están empaquetados dentro del proyecto. Inventario, dimensiones,
procedencia y prompts exactos en `docs/design/WORKOUT_ASSETS_2026_10_12.json` y
`docs/design/WORKOUT_ASSET_PROMPTS_2026_10_12.json`. `tools/encode_workout_art.py`
codifica originales sin reemplazar ficheros existentes. El fallback conserva
texto, acciones y datos aun si la imagen falla. No se cargan desde Internet.
