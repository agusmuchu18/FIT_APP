# Expansión complementaria de FIT_APP
Fecha: 23/10/2026. Base local validada: `90167e7`, 270 tests. Prevalece la carpeta
local; hay WIP previo en Perfil/Grupos/Ajustes y otros módulos. No push/despliegue.

## Invariantes
Inicio, Hábitos, Grupos y Perfil conservan su navegación. Fotos/Estadísticas/PRs
se conservan. Entrenamiento no se modifica; se consume su índice cuando corresponda.
Invitado separado de cuentas; UID autenticado estable, nunca @usuario como clave.
Datos sensibles privados por defecto. No simular personas, métricas, permisos,
notificaciones push, pagos o conexiones. No borrar ni reinicializar datos.

## Secuencia verificable
1. Auditoría y arquitectura; corregir generación de datos ficticios de Grupos,
   persistencia/aislamiento y estados de integración engañosos.
2. Identidad social/descubrimiento: perfil propio durable, handle único reservado
   transaccionalmente, backend autorizado de búsqueda, follow/solicitudes, bloqueos.
3. Publicaciones: snapshot permitido explícito, feeds por cursor, multimedia privada,
   likes/comentarios/menciones. Publicación nunca automática.
4. Grupos remotos: identidad de miembros, invitaciones, roles y consentimientos
   independientes por categoría; reutilizar el motor de entrenamiento.
5. Notificaciones internas y moderación: idempotencia, preferencias existentes,
   reportes con cola real de revisión; push solo con infraestructura probada.
6. Perfil/cuerpo: fotos privadas propias, comparación; medidas opcionales por fecha,
   fuente y unidad. Sin inferencias de grasa/masa magra a partir del peso.
7. Integraciones oficiales: capacidades verificadas, permisos por plataforma,
   procedencia/id externo, sincronización incremental y revocación.
8. Datos/calidad: copia JSON versionada, preview/conflictos/importación no destructiva,
   CSV, temas/accesibilidad, ayuda y comprobaciones de plataforma.

Cada corte: contrato/modelo → persistencia/autorización → UI → pruebas → revisión
acotada → evidencia → commit local independiente. No declarar completada una etapa
por crear contratos ni esconder un acceso con Flutter. Bloqueos no frenan trabajo
independiente; estado granular en IMPLEMENTATION_STATUS.md.

## Puertas de aceptación por etapa
| Etapa | Implementación necesaria para completarla | Evidencia mínima |
|---|---|---|
| 1 | Identidad local separada de miembro autenticado; retirar semillas/métricas inventadas; Grupos/Perfil durables por dueño, IDs preservados; inventario backend/conectores | Persistencia, invitado/A/B, concurrencia, corrupción/versiones, errores/reintento, conservación de rutas |
| 2 | Extender Perfil con handle/biografía/enlace/opt-in; reserva normalizada/aliases en servidor; búsqueda con cursor/cancelación; follow/solicitud/aceptar/rechazar/unfollow; privado/bloqueado/no disponible | Emulador con tres usuarios: unicidad, acentos/case/reservados, contadores concurrentes, idempotencia, denegación de escrituras ajenas; búsqueda sin privados/bloqueados |
| 3 | Snapshot autorizado de sesión; publicar voluntariamente; feeds Siguiendo/Descubrir/Grupos por cursor; medios privados/miniaturas; likes con rollback; comentarios/menciones resueltas y enlaces | Reducir privacidad/borrar original retira publicación; lectura ajena denegada; fallos de red, repetición, media y paginación; no alterar motor de entrenamiento |
| 4 | Contacto→UID solo mediante aceptación; roles mínimos/permisos; invitaciones revocables/expirables, salir; consentimiento independiente por categoría; panel usa métricas existentes | Conservar grupos/IDs; propietario/admin/entrenador/atleta ajenos, revocación, invitación repetida/vencida, escalada denegada; follow no amplía acceso |
| 5 | Centro interno y preferencias existentes; eventos idempotentes; bloqueo/ocultar; reportes con cola y decisión de revisión autorizada; límites de acciones; push solo si proveedor real | Reintentos/duplicación, bloqueado, contenido borrado/privado, notificación sin exposición; reporte revisable con estados, no solo confirmación visual |
| 6 | Galería propia privada durable, fecha/descripción/borrar/comparar; medidas opcionales/bilaterales con fecha/fuente/unidad/notas, historial/gráfico/CRUD/comparación | Datos incompletos, precisión y unidades, edición/borrado/fechas, dos cuentas, EXIF/acceso; no inferir composición; conservar Fotos/Estadísticas/PRs |
| 7 | OAuth/permisos/capacidades/revocación por plataforma; import incremental con origen+ID+fechas+cursor, dedupe/reintento; contratos oficiales | Mocks solo para contratos; revocación/proveedor caído/doble import/plataforma incompatible; hardware y proveedor real para certificar conexión |
| 8 | Backup JSON versionado sin secretos, CSV/medios; preview/validación/versiones/duplicados/conflictos sin sobrescribir; ayuda/temas/semántica/texto/contraste/rendimiento | Archivos corruptos/futuros/incompletos, import repetido y errores; permisos de recursos nuevos; suite/análisis/builds; Android/iPhone cuando disponibles |

## Dependencias y continuidad
La etapa 2 remota exige servicio confiable y pruebas de autorización; se puede
desarrollar y probar en emulador antes de desplegar. Despliegue, dominios, secretos
y acceso a proveedores se preparan para revisión separada. No abrir lecturas
globales de users/* para habilitar búsqueda: Rules no filtra consultas y el SDK
Admin exige verificar explícitamente UID, bloqueos y consentimientos.
Fotos/medidas y exportación local pueden progresar sin credenciales de terceros;
esto no autoriza su publicación. Cada etapa mantiene evidencia y estado propios.
El próximo corte extiende la identidad existente y el backend de búsqueda antes
de añadir resultados a Descubrir. No usar perfiles de ejemplo en producción.
