# Diseño visual de la app

Esta guía define la identidad visual, arquitectura de pantallas y lineamientos de interacción para el modo Lite y Profesional, así como el onboarding y la visualización de integraciones con wearables. El objetivo es asegurar una experiencia premium, minimalista y científica en línea con referentes como Apple Health, Oura y Whoop.

## 1. Identidad visual

### Paleta oscura (preferida)
- Fondo principal: `#0A0A0A`
- Fondo tarjetas: `#111111`
- Acento bienestar: `#00DFA2`
- Acento datos: `#4ECDC4`
- Texto principal: `#FFFFFF`
- Texto secundario: `#B3B3B3`
- Líneas/bordes: `#1F1F1F`

### Paleta clara
- Fondo principal: `#FFFFFF`
- Fondo secciones: `#F2F2F2`
- Acento bienestar: `#00BFA6`
- Texto principal: `#1A1A1A`
- Texto secundario: `#4D4D4D`
- Líneas/bordes: `#E6E6E6`

### Tipografía y estilo
- Tipos: **Inter** para textos y números; **Poppins** para títulos y titulares.
- Bordes redondeados: 12–16 px.
- Sombras: suaves, difusas, opacidad baja; sin elevaciones abruptas.
- Iconografía: línea fina estilo iOS; usar un set consistente para salud y fitness.
- Animaciones: 200–250 ms, sutiles (fade/slide) sin rebotes.
- Gráficos: estilo Apple Fitness/Oura (líneas limpias, barras finas, gradients mínimos).
- Espacio en blanco/negro generoso para transmitir lujo y claridad.

## 2. Arquitectura visual de pantallas

### A. Dashboard principal (Home)
- **Hero superior** con resumen del día y estado de sincronización de wearables.
- **Tarjetas métricas** (grid 2x2 en mobile):
  - Calorías consumidas vs objetivo (progreso circular).
  - Macros (prote/carbos/grasas) en barras horizontales apiladas.
  - Tiempo de entrenamiento (barra de progreso diaria).
  - Calidad del sueño (puntaje + badge de tendencia).
  - HRV y pasos/gasto calórico si hay wearable.
- **Entrenamiento/Comidas/Sueño registrados**: chips con estado (✔️/⚠️) y CTA rápido.
- **Integraciones**: fila de tarjetas pequeñas con iconos (Apple Watch, Fitbit, Garmin) y tiempo de última sincronización.
- **Tendencias**: carrusel con gráficos semanales (entrenos, sueño, calorías) en tarjetas horizontales.

### B. Pantalla de registro diario
Una sola vista con tabs o sección anclada para Entrenamiento, Comidas y Sueño.

- **Selector de modo**: interruptor "Lite / Profesional" en la parte superior, persistente.

#### Entrenamiento
- Lite: selector de plantilla rápida, duración, intensidad (chips baja/media/alta), notas opcionales.
- Profesional: lista de ejercicios con filas tipo tabla (ejercicio, series, reps, carga, RPE); soporte de video/notas.

#### Comidas
- Lite: botones grandes por comida (Desayuno/Almuerzo/Cena/Snack), campo breve, adjuntar foto, plantillas rápidas.
- Profesional: buscador estilo MyFitnessPal con macros y micros, cantidad en gramos, comidas personalizadas, importar/editar dietas, automatizar desde apps externas.

#### Sueño
- Lite: horas dormidas, calidad (1–5), hora de dormir/despertar opcional.
- Profesional: fases de sueño (hipnograma si disponible), HRV nocturna, FC promedio, interrupciones, comentarios.

### C. Estadísticas avanzadas
- **Progreso general**: gráfico semanal/mensual con calorías quemadas, tiempo total de entrenamiento y variación de nutrientes.
- **Estadísticas cruzadas**: vistas comparativas “sueño vs rendimiento”, “calidad de dieta vs energía”, con correlogramas simples o cards con insights.
- **Perfil fisiológico**: HRV, FC en reposo, stress score y recuperación estimada en tarjetas con badges de estado.

### D. Módulo de grupos / entrenadores
- **Pantalla de grupo**: lista con filtros (mejor rendimiento, menor sueño, alertas). Dashboard grupal con gráficos agregados.
- **Detalle de atleta**: métricas diarias, curva de progreso, adherencia a dieta/entreno y comparativas rápidas. Estilo panel pro (referencia STRAVA/Whoop Coach).

### E. Perfil y configuración
- Objetivos del usuario y preferencia de detalle (Lite vs Profesional por módulo).
- Conexiones (Apple Health, Fitbit, Garmin), idioma, integraciones externas, exportación de datos, privacidad y compartir con entrenador.

## 3. Diferencias UI: modo Lite vs Profesional

- **Selector**: conmutador con estado destacado; se muestra en las pantallas de registro y puede ser global en perfil.
- **Lite**: botones grandes, texto mínimo, iconos prominentes, formularios cortos que se completan en 30–60 s, resumen simplificado.
- **Profesional**: formularios detallados, tablas, inputs específicos (peso, series, macros), gráficos más profundos y editores avanzados.
- Mantener coherencia visual: mismas tarjetas, tipografía y espaciados; cambia la densidad y nivel de detalle.

## 4. Onboarding

- Diseño limpio con pasos breves (progreso en la parte superior).
- Preguntas: objetivo principal (salud/entrenamiento/peso/rendimiento), nivel de detalle (Lite/Profesional), edad, estatura, peso, horas promedio de sueño, dispositivos usados, conectar wearable.
- Pantalla final: mensaje “Tu app está lista. Tus métricas te acompañarán día a día.” con CTA para ir al dashboard y opción de ver tutorial corto.

## 5. Integraciones con wearables

- Banner premium cuando hay conexión activa: “Datos sincronizados automáticamente desde: Apple Watch / Fitbit / Garmin”.
- Tarjetas pequeñas por dispositivo con icono, “Última sincronización: hace X minutos” y datos recogidos (pasos, FC, HRV, sueño, kcal).
- Indicadores de estado: verde cuando la sync es reciente, ámbar si está pendiente.

## 6. Componentes reutilizables

- **Tarjetas**: variantes compacta (métrica única) y expandida (gráfico + detalle). Fondo `#111111` en oscuro o `#F2F2F2` en claro.
- **Chips**: estados (éxito/alerta), filtros y selección de intensidad.
- **Gráficos**: líneas suavizadas para tendencias, barras delgadas con esquinas redondeadas, donuts para objetivos.
- **Inputs**: campos con bordes suaves y foco con acento; en Profesional incluir validaciones visibles.
- **CTAs**: botones llenos con acento bienestar; secundarios con borde sutil.

## 7. Microinteracciones y feedback

- Haptics/sonidos discretos (opcional) al registrar actividades.
- Skeletons o shimmers al cargar datos de wearables.
- Badges de tendencia (↑/↓) con color de acento datos.

## 8. Accesibilidad y consistencia

- Contraste AA en ambos temas.
- Tamaños de toque mínimos de 44 px.
- Uso consistente de iconografía y espaciados (8 px grid base).
- Modo oscuro por defecto, con opción clara en perfil.

## 9. Entregables sugeridos

- Mockups de dashboard, entrenamiento, comidas y panel de entrenadores siguiendo esta guía.
- Biblioteca de componentes (tarjetas, chips, gráficos, tablas pro).
- Tokens de color y tipografía exportables para Flutter (ThemeData) y diseño (Figma).
