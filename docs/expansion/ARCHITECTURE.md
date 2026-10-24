# Arquitectura de ampliación
No cambia la estructura principal descrita en docs/ARCHITECTURE.md.

## Dueños y límites
- UID de Firebase: identidad remota; AccountStorageScope: contenedor local.
- Grupos actuales: contactos locales; un contacto escrito a mano no equivale a un
  usuario autenticado, a una invitación aceptada ni a un permiso sobre sus métricas.
- PerfilController/componentes de Perfil se extienden; no otro sistema de cuentas.
- Datos corporales/fotos privados: namespace por dueño; no incluidos en sync ni
  export público hasta tener contrato y controles expresos.
- Social remoto debe usar un servicio confiable con autorización de cada operación,
  autenticación verificada, transacciones, límites e índices paginados. Las reglas
  vigentes permanecen cerradas; no permitir reads globales de users/*.

## Identidad social implementada localmente
`backend/social/src/index.js` expone callable, verifica Auth y App Check. Servicio
`social_identity.js` aplica autorización, rate limits y transacciones; colecciones
sociales denegadas para lectura/escritura Firestore directa. El SDK Admin exige
estos controles explícitos. Registros se crean solo al guardar voluntariamente.
`SocialIdentityClient` usa el protocolo callable con token, atestación oficial,
captura de scope/UID y cancelación. `ProfileDiscoveryController` es dueño de cada
consulta y cursor; descarta resultados obsoletos. No hay caché pública persistente.
Descubrir se integra en Grupos; formularios reutilizan identidad y persistencia del
Perfil. Ninguna vista ajena usa el controlador de estadísticas privadas del dueño.

## Identidad y contratos restantes
Proyección PublicProfile mínima (uid, handle normalizado, nombre/biografía públicos,
disciplina, avatar público saneado). Nada de email, medidas, sueño, nutrición o notas.
Handle único reservado en transacción, aliases históricos → UID; no reasignar enlaces
silenciosamente. Relaciones dirigidas separadas de membresías y consentimientos.
Follow público inmediato o petición privada. Repetición idempotente; cuentas bloqueadas
o eliminadas no elegibles. Contadores derivados/actualizados en servidor.

SocialPost contiene solo campos seleccionados, referencia a sesión y versión de
snapshot. No serializar WorkoutSession completo. Retirar proyección si se elimina
original o se reduce visibilidad. Feeds recientes por cursor fecha+ID; búsqueda por
prefijo/normalización con filtrado autorizado en servidor. Reglas no son filtros.
Storage privado; thumbnails públicos solo tras consentimiento/saneado EXIF y política
de retirada. Backend verifica UID, bloqueos, contexto y consentimientos antes de leer.

La API de identidad funciona en emulador; no está desplegada ni habilitada en la
app por defecto. Los contratos de publicaciones/media/grupos remotos anteriores
siguen pendientes. No devolver datos ficticios si falta infraestructura.

## Medidas corporales privadas
`BodyMeasurementRepository` reutiliza Hive: caja `fit_body_measurements_v1` con
el namespace existente por cuenta/invitado, metadato `schema=1` y una fila JSON
versionada por UUID. No usa preferencias para los registros ni modifica cajas
históricas. Solo la preferencia pequeña de perímetros cm/in va en ScopedPreferences.
Cada observación incluye fecha de calendario, creación, fuente manual, notas y
mapa de medidas con valor/unidad originales. Reutiliza WeightUnit para kg/lb;
cm/in se convierten solo al presentar. No calcula grasa ni masa magra.
Cola por dueño entre instancias; lectura estricta de formato y revisión optimista
para edición/borrado. Corrupción o versión futura impiden escritura sin borrar
datos. No hay migración destructiva, sincronización ni endpoint público de medidas.
Pantalla/formulario en Perfil; gráfico usa días reales, no intervalos uniformes
entre muestras; historial por bloques y comparación explícita de dos registros.
