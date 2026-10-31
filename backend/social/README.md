# Identidad social · corte local

Extiende el UID de Firebase que ya utiliza FIT_APP. No crea cuentas ni un motor de
estadísticas paralelo. No migra ni publica sesiones, fotos o datos de salud.

## Ejecución verificable sin producción

Desde la raíz, con Node, Java 21, Flutter y Firebase CLI instalados:

```powershell
npm --prefix backend/social ci --ignore-scripts
firebase emulators:exec --project demo-fit-social --config firebase.social.json --only 'auth,firestore,functions' 'npm --prefix backend/social test && flutter test --no-pub --dart-define=FIT_SOCIAL_TEST_EMULATORS=true test/features/profile/social_emulator_contract_test.dart --reporter expanded'
```

Los destinos están fijados a loopback y a un proyecto `demo-`. Las pruebas no
pueden escribir producción; los fixtures se crean solo dentro del emulador.
Las pruebas Node usan JWT reales del Auth Emulator, callable HTTP, transacciones
Firestore y las reglas existentes de la raíz, no un repositorio en memoria.
El contrato Flutter también usa estos servicios reales. Runtime de despliegue
declarado: Node 22; la ejecución local realizada usa Node 24, según advertencia
del emulador. Falta repetir el gate bajo Node 22 antes de habilitar producción.

## Acceso y datos

`socialIdentity` acepta únicamente cuentas autenticadas no anónimas. Verifica
disponibilidad del actor, revocación, UID del token y App Check; este último se omite solo en
el emulador real de Functions. Todas las colecciones sociales permanecen
denegadas al cliente Firestore: solo el servidor aplica autorización.

- `socialProfiles/{uid}`: esquema v1; rechaza sobrescribir versiones futuras. Proyección explícita de identidad y contadores, sin email,
  fotos privadas, peso, sueño, alimentación, sesiones completas o métricas.
- `socialHandles/{handle}`: reserva transaccional; los aliases anteriores conservan
  el UID. NFKC/case normalizan handles ASCII; longitud 3–24, nombres reservados.
  Máximo tres cambios de handle por día; no se reasignan aliases a otra cuenta.
- `socialFollows/{hash(from,to)}`: pendiente/aceptado, independiente de los grupos.
  Solicitudes, aceptación/rechazo, cancelación y unfollow son idempotentes.
- `socialBlocks/{hash(from,to)}`: bloqueo en ambas direcciones de acceso; elimina
  relaciones y ajusta contadores transaccionalmente. Unblock no restaura relaciones.
- `socialQuotas/{hash(uid,lane)}`: ventanas de minuto, 90 lecturas/40 escrituras por
  cuenta. No sustituye monitorización/controles operativos de abuso.

Búsqueda por prefijo de nombre completo, palabra o @handle; nombres normalizados
por acentos/case. Sugerencias deterministas: perfiles públicos elegibles ordenados
por UID. No hay algoritmo de IA. Páginas de 20, lectura acotada de 60 candidatos,
cursor ligado a usuario/consulta/lista. Puede haber una página vacía con cursor
si los candidatos están ocultos; Cargar más continúa sin una lectura ilimitada.
Opt-out y bloqueados no aparecen; cuentas eliminadas/deshabilitadas se excluyen.
Opt-out afecta búsqueda/sugerencias: una identidad declarada pública continúa
accesible por su enlace/handle conocido para cuentas autenticadas no bloqueadas.
Un perfil privado descubrible expone solo nombre/@handle antes de la aprobación;
biografía/enlace/disciplina/contadores requieren autorización. Nada autoriza salud.

## Habilitación pendiente

La app conserva la navegación y añade Mis grupos/Descubrir dentro de Grupos.
Perfil conserva Fotos/Estadísticas/PRs; su editor abre identidad/privacidad social.
Sin habilitación, muestra estado no disponible y no envía datos al backend.

Antes de habilitar `FIT_SOCIAL_ENABLED=true` se necesita:

1. Revisión y autorización de despliegue de Function, reglas e índices. Este corte
   no ejecutó despliegue, cambió IAM ni abrió acceso público en Firebase.
2. Registrar las apps reales en App Check: Play Integrity y App Attest con fallback
   DeviceCheck; registrar dominio web y `FIT_SOCIAL_RECAPTCHA_SITE_KEY` público.
   El cliente usa el SDK oficial; no hay tokens estáticos, secretos ni proveedores
   debug en producción. La atestación real en dispositivo sigue sin verificarse.
3. Validación Node 22, Android/iPhone y procedimiento de eliminación de cuenta.
   Los perfiles de cuentas deshabilitadas/eliminadas dejan de ser accesibles por
   autorización; no se borran automáticamente datos históricos ni aliases. El
   saneamiento de relaciones/counters tras eliminación es un pendiente explícito.
4. Gate de moderación/retención antes de UGC y multimedia. Este corte implementa
   identidad, relaciones y bloqueo; no feeds, reportes, push, fotos públicas o PRs.

Fuentes: [callables](https://firebase.google.com/docs/functions/callable-reference),
[transacciones](https://firebase.google.com/docs/firestore/manage-data/transactions),
[App Check Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers).
