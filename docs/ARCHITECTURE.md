# Architecture

## Forma actual

FIT_APP es una aplicación Flutter monolítica organizada por features, con un
núcleo compartido para entidades, almacenamiento, estadísticas, sincronización e
integraciones.

```text
Widgets / screens
  -> ChangeNotifier, Provider, controladores o estado local
  -> repositorios del feature o FitnessRepository
  -> Hive / SharedPreferences
  -> RemoteSyncService -> Firestore (si hay sesión y backend)
```

## Arranque

`lib/main.dart` realiza en orden:

1. inicialización Flutter y locale español;
2. inicialización Firebase;
3. fallback explícito a transporte remoto nulo si Firebase falla;
4. inicialización Hive y cola de sincronización;
5. construcción de `FitnessRepository` y adaptadores por entidad;
6. montaje de `RepositoryScope` y `MaterialApp`.

Desde 2026-10-01, `AccountSessionGate` observa la identidad de Firebase y restaura
un repositorio por cuenta antes de montar su Navigator. Los anónimos y el modo
local usan el espacio de invitado, separado según la decisión del usuario.
`AccountStorageScope` conserva los nombres antiguos para invitado y añade un
namespace a las cajas centrales, sesiones ricas y cola de cada cuenta.
`ScopedPreferences` aplica esa propiedad a todas las claves de Entrenamiento.
El repositorio captura dueño y el transporte usa un `SyncSession` estable;
respuestas de restauración antiguas no reemplazan la sesión nueva.
Al restaurar, `recoverCompletedWorkouts` repara proyecciones ausentes de Home y
limpia únicamente un cierre pendiente que ya está en el historial.

La ruta inicial muestra `MainShell` si Firebase conserva un usuario, incluido el
anónimo; en otro caso muestra login. El modo local puede navegar sin backend.

## Capas y estado

- **Presentación:** pantallas y widgets dentro de cada feature.
- **Aplicación:** controladores para búsquedas, borradores y sesiones.
- **Dominio:** modelos específicos y entidades centrales sincronizables.
- **Datos:** repositorios de feature, Hive, preferencias, red y Firebase.

No existe un único contenedor de dependencias. `FitnessRepository` se inyecta con
`RepositoryScope`, varias pantallas usan `Provider`, y algunos flujos dependen de
singletons (`AuthService`, perfil, sesión activa y overlay). Al modificar un
flujo, buscar primero dónde se crea y quién posee su ciclo de vida.

## Escritura y sincronización

Las entidades centrales implementan `SyncEntity`. `FitnessRepository` coordina
la persistencia local y entrega operaciones a `RemoteSyncService`. El servicio
usa adaptadores por tipo, un `SyncSession` para obtener el usuario y una cola
Hive para reintentos. Firestore almacena documentos bajo:

```text
users/{uid}/workouts/{id}
users/{uid}/meals/{id}
users/{uid}/sleep/{id}
users/{uid}/preferences/{id}
```

Las reglas versionadas limitan esas rutas al propietario. No asumir que están
desplegadas: comprobar `docs/CURRENT_STATUS.md`.

## Límites arquitectónicos vigentes

Las notas previas sobre `DeviceAccountBinding` y modernización transaccional de
sync pertenecen a otra continuidad de trabajo y no certifican este checkout.
Aquí, el aislamiento comprobado es el de Entrenamiento y las cajas centrales;
todavía se requiere recorrido Firebase real y auditoría de otros singletons.

Nutrición web consulta USDA mediante una Cloud Function HTTPS que custodia el
secreto. `FoodRepository` funciona offline-first: catálogo Foundation empaquetado,
alimentos USDA ya abiertos y alimentos personalizados; la red sólo amplía resultados.

- Las preferencias y singletons de otros features requieren su propia revisión
  de propiedad; no asumir aislamiento global por haber cerrado Entrenamiento.
- Los modelos centrales y los modelos avanzados de workout/nutrition se
  superponen parcialmente; verificar el tipo exacto antes de reutilizarlo.
- Las integraciones de salud declaran canales Dart, pero faltan handlers nativos.
- Algunas rutas conducen deliberadamente a placeholders.
- El fallback local y la sesión Firebase son modos distintos; probar ambos al
  tocar arranque, autenticación o sync.

## Reglas para cambios transversales

Antes de cambiar entidades, autenticación, navegación o persistencia:

1. buscar todos los constructores, serializadores y consumidores;
2. definir compatibilidad/migración de datos existentes;
3. validar primero el feature y después sync, arranque y suite completa;
4. actualizar los mapas sólo si cambian los límites descritos aquí.
