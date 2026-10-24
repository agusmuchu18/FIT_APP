# Estado incremental
Fecha: 24/10/2026. Estados: Pendiente / En desarrollo / Implementada / Probada / Bloqueada.

| Etapa/capacidad | Estado | Evidencia o condición |
|---|---|---|
| 1 Auditoría/arquitectura/modelo privacidad | Implementada | FEATURE_AUDIT, ARCHITECTURE, PRIVACY_MODEL; inspección estática, no pentest |
| 1 Grupos durables sin demo ni acceso implícito | Probada | persistencia local por cuenta, cola de escrituras, IDs preservados, errores y formularios probados; no son grupos remotos |
| 2 Identidad propia privada durable | Probada | mismo ProfileController; nombre/avatar por cuenta, guardado verificado y rechazo de controlador anterior |
| 2 Perfil público/handles/búsqueda/follow/solicitudes | En desarrollo | backend real y UI integrados, pruebas Auth/Firestore/Functions + contrato Flutter en emulador aprobados; falta habilitación/configuración externa y gate móvil/Node 22 |
| 3 Posts/feeds/media/likes/comentarios/menciones | Pendiente | depende identidad, consentimiento, Storage y moderación reales |
| 4 Grupos remotos/roles/invitaciones/entrenador | Pendiente | contactos locales no son miembros autenticados |
| 5 Notificaciones internas/moderación | Pendiente | no hay infraestructura push ni cola de moderación |
| 6 Fotos propias/comparación/medidas | Pendiente | se retiraron solo las URLs picsum; galería conservada, no hay todavía CRUD de fotos ni medidas |
| 7 Estados reales de integraciones | Probada | 18 accesos sin conexión verificada; preferencias antiguas no muestran conectado ni última sync ficticia |
| 7 Conexiones reales Apple/Android/terceros | Bloqueada | faltan implementación nativa, hardware y credenciales/aprobaciones; sin inventar conexión |
| 8 Datos JSON/CSV/importación/QA | Pendiente | backup versionado/preview/no sobrescritura; no cambiar entrenamiento |
| Despliegue social/Rules/Storage/Functions | Bloqueada | no autorizado despliegue; no se afirma infraestructura activa |

La expansión no cambia Entrenamiento. Hay mejoras locales posteriores de ese módulo
aportadas durante la sesión que se preservan aparte. Navegación principal e IDs
históricos se conservan. Leer esta tabla y último commit local antes de continuar.

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

## Corte de identidad social
Backend en `backend/social`, configuración aislada `firebase.social.json`; incorpora
las reglas existentes sin abrir lecturas sociales. API con UID verificado, reserva
transaccional de handles/aliases, búsqueda por cursor/acentos/case, follow/solicitud,
aceptar/rechazar/cancelar, listas, bloqueo/unblock y contadores seguros.
UI dentro de Grupos y editor de Perfil; default privado/opt-out, consentimiento al
ampliar visibilidad. El mismo ProfileController recibe el nombre confirmado.
Avatar privado no se sube ni se hace público. Ningún endpoint devuelve salud.

Flutter usa tokens reales de Firebase y SDK App Check; debounce, cancelación,
timeouts y cambio de cuenta se verifican. `FIT_SOCIAL_ENABLED` permanece false por
defecto: falta autorización/configuración de producción, no hay perfiles ficticios.
Backend y contrato Flutter probados en emulador; ver TEST_REPORT y README backend.
Pendientes: registro App Check real, Node 22, dispositivos móviles, limpieza de
relaciones/contadores ante eliminación de cuenta y UI de lista de bloqueados.
Continuar luego con publicación voluntaria/feeds, sin ampliar permisos de salud.

Corte UI local: 333 pruebas Flutter aprobadas y 1 contrato omitido en la suite
normal, aprobado separadamente con emuladores; 13 casos backend, análisis
estricto limpio y builds web/APK debug aprobados. Tres capturas de identidad
revisadas, incluyendo 320 px/200%. El servicio permanece deshabilitado por
defecto hasta resolver los gates externos y de ciclo de cuenta. Backend:
`89c33dd`; commits de fundamentos `133997d`, `0f08d7a`, `4e79df6`.
