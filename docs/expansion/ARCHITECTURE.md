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

## Contratos remotos previstos
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

Los nuevos contratos no habilitan endpoints ni significan backend desplegado. No
inventar transporte que devuelva datos falsos cuando falta infraestructura.
