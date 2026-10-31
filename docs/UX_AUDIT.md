# Auditoría visual incremental

Evidencia: app Flutter web renderizada a 390×844, modo oscuro, durante esta tarea.
Las capturas se mostraron en la conversación; no hay paquete local persistente.
No repetir auditoría global: recapturar las zonas modificadas y los tres pilotos.

| Vista | Hallazgo | Estado |
|---|---|---|
| Acceso | Texto oscuro sobre botón azul; borrador visible encima del acceso | onPrimary blanco revisado; barra corregida y probada por navegación, recaptura pendiente |
| Home | Racha vacía domina, poco foco en iniciar; nutrición usa meta fija 2000 | Jerarquía pendiente del piloto; no interpretar meta fija como personalizada |
| Home | Entrenamiento vacío decía En rango | Corregido a Sin registros; animación de entrada respeta reduced motion |
| Navegación | Iconos sin etiquetas y contenido inferior solapado | Pendiente |
| Perfil visible | Fotos aleatorias y cifras ficticias | Retiradas; no conectado se muestra explícitamente, recaptura pendiente |
| Perfil visible | Pestañas ocultan parte del resumen superior | Pendiente del piloto |
| Entrenamiento | CTA truncado, iconos ambiguos, gran vacío | Pendiente del piloto |
| Sesión | Título y timer truncados; radar vacío consume ancho | Título acortado; timer/radar pendientes |
| Registro de alimentos | Aviso USDA parecía error; chips cortados, selector ocultaba opciones y CTA inferior ambiguo | Corregido y revisado a 390×844; registro y persistencia tras recarga verificados |

La barra conserva un borrador al navegar: no eliminarlo como arreglo visual.
Su separación inferior asume barra de navegación en demasiadas rutas: revisar
por ruta real al resolver el layout. Los tests no sustituyen la revisión visual.
