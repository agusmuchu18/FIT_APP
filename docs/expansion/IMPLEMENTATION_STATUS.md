# Estado incremental
Fecha: 23/10/2026. Estados: Pendiente / En desarrollo / Implementada / Probada / Bloqueada.

| Etapa/capacidad | Estado | Evidencia o condición |
|---|---|---|
| 1 Auditoría/arquitectura/modelo privacidad | Implementada | FEATURE_AUDIT, ARCHITECTURE, PRIVACY_MODEL; inspección estática, no pentest |
| 1 Grupos durables sin demo ni acceso implícito | Probada | persistencia local por cuenta, cola de escrituras, IDs preservados, errores y formularios probados; no son grupos remotos |
| 2 Identidad propia privada durable | Probada | mismo ProfileController; nombre/avatar por cuenta, guardado verificado y rechazo de controlador anterior |
| 2 Perfil público/handles/búsqueda/follow/solicitudes | Pendiente | necesita backend autorizado y pruebas multiusuario antes de exposición |
| 3 Posts/feeds/media/likes/comentarios/menciones | Pendiente | depende identidad, consentimiento, Storage y moderación reales |
| 4 Grupos remotos/roles/invitaciones/entrenador | Pendiente | contactos locales no son miembros autenticados |
| 5 Notificaciones internas/moderación | Pendiente | no hay infraestructura push ni cola de moderación |
| 6 Fotos propias/comparación/medidas | Pendiente | se retiraron solo las URLs picsum; galería conservada, no hay todavía CRUD de fotos ni medidas |
| 7 Estados reales de integraciones | Probada | 18 accesos sin conexión verificada; preferencias antiguas no muestran conectado ni última sync ficticia |
| 7 Conexiones reales Apple/Android/terceros | Bloqueada | faltan implementación nativa, hardware y credenciales/aprobaciones; sin inventar conexión |
| 8 Datos JSON/CSV/importación/QA | Pendiente | backup versionado/preview/no sobrescritura; no cambiar entrenamiento |
| Despliegue social/Rules/Storage/Functions | Bloqueada | no autorizado despliegue; no se afirma infraestructura activa |

Entrenamiento permanece en 90167e7 sin nuevas modificaciones. Navegación principal
e IDs históricos se preservan. Leer esta tabla y último commit local antes de continuar.

## Entrega inicial y límites de migración
Claves nuevas y privadas: `groups.private.v1`, `profile.private.v1` bajo
ScopedPreferences. No se cambia una base previa ni se añaden proyecciones públicas.
Grupos antiguos disponibles en memoria pueden importarse a invitado conservando
sus IDs; se excluye únicamente la demostración conocida exacta. No se atribuyen
registros sin dueño a la primera cuenta. No existía un archivo histórico de grupos.
Si un ID legado coincide con datos guardados distintos, se mantienen los valores
guardados y se incorporan contactos faltantes. La variante anterior queda en
`groups.private.legacy_conflicts.v1`, privada de invitado y sin métricas generadas;
no se pierde ninguna identidad. Un archivo de conflictos ilegible impide la
migración sin descartar entradas y permite reintentar tras recuperar el archivo.
Las ediciones antiguas de nombre/avatar solo en RAM no son recuperables después
de cerrar aquella ejecución; no se afirma haber migrado datos que nunca persistían.

No se borran las estadísticas anteriores: el código viejo pudo escribir muestras
de ejemplo en StatisticsService y no hay procedencia suficiente para distinguirlas
de registros reales con seguridad. Se detienen escrituras nuevas; reparación de
datos antiguos requiere un procedimiento verificable, no limpieza automática.
La etiqueta Premium activo se retiró: no existe un sistema comercial verificado.

Siguiente etapa: backend de identidad/handles, búsqueda autorizada y relaciones;
emulador y pruebas con varios usuarios antes de habilitar Descubrir. No crear
una pestaña con perfiles de ejemplo mientras falta ese flujo real.
