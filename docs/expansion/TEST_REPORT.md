# Evidencia de pruebas
Línea base de entrada: 270 tests, análisis estricto limpio, web release/APK debug;
pertenecen a 90167e7 y NO certifican funcionalidades sociales nuevas.

## Matriz nueva requerida
- Grupos: persistencia al recrear servicio, IDs, invitado/cuentas, cambios de sesión,
  concurrencia, fallo/corrupción sin sobreescritura y ausencia de métricas ficticias.
- Identidad/social: unicidad Unicode, paginación, cancelación, público/privado,
  bloqueos, doble follow, autorización y concurrencia en backend/emulador.
- Feed: snapshots permitidos, retirada, privacidad, media validada, cursor, rollback.
- Cuerpo: fechas/unidades opcionales, no inferencia, privacidad/propiedad, CRUD.
- Integraciones: estados honestos, ningún último-sync inventado, fallo de permisos,
  desconexión y contrato real. Mocks solo de prueba, no evidencia de conexión real.
- Datos: versiones, archivo corrupto, preview, duplicados/conflictos y secretos.
- UI: oscuro/claro, 320 px/200%, movimiento reducido, lectura/teclado; capturas.

## Corte ejecutado
Suite: 293/293 aprobadas; análisis estricto sin incidencias. Superficie: host
Flutter/unit/widget/goldens; SharedPreferences de pruebas, no backend desplegado.
9 pruebas de persistencia de grupos + 3 de UI + 2 de readiness de integraciones +
7 de Perfil privado + 2 casos golden nuevos. Capturas de Perfil actualizadas por
retirada de @fit_user/objetivo fijo, sin cambiar su motor de métricas.
Logs locales: `build/social_foundation_tests.log`, `private_profile_tests.log`,
`social_expansion_final_tests.log`, `social_expansion_analyze.log`.
Los fixtures de contactos y avatares existen únicamente en test/.
Migraciones: colisiones de IDs, recuperación de campos alternativos, idempotencia
del archivo de conflictos y conservación ante corrupción.
`flutter build web --no-pub` y `flutter build apk --debug --no-pub`: aprobados
tras la última corrección. Logs: `build/social_expansion_web.log` y
`build/social_expansion_apk.log`. APK compilado, no ejecutado en dispositivo.
La suite corresponde a la carpeta local con WIP anterior conservado; no certifica
un checkout limpio ni permisos sociales remotos que todavía no existen.

Android físico/iPhone, lectores nativos, HealthKit/
Health Connect y backend desplegado no disponibles/verificados en esta sesión.

## Identidad social · 24/10/2026
- Suite Flutter completa: **333 aprobadas, 1 omitida**. La omitida requiere
  emuladores y se ejecutó por separado: **1 contrato Flutter real aprobado**.
- Backend: **13 pruebas aprobadas** con Auth, Firestore y Functions locales,
  tokens reales de cuentas de prueba, transacciones y reglas. Ninguna cuenta de
  producción. Comando reproducible en `backend/social/README.md`.
- Incluye identidad/Unicode/reserva concurrente, solicitudes, contadores,
  revocación/bloqueos, paginación, cambio de privacidad, sesiones revocadas y
  rechazo de lecturas/escrituras directas. Cliente: cancelación, debounce,
  cambio de cuenta, timeout, respuesta obsoleta, errores y reintento de follow.
- UI: navegación interna conservada, consentimiento explícito, error distinto
  de lista vacía; tres capturas revisadas con Inter/íconos reales: oscuro,
  claro privado y 320 px/200%/movimiento reducido. Fixtures solo en `test/`.
- `flutter analyze --no-pub --fatal-infos`: **0 problemas**.
- `flutter build web --no-pub` y `flutter build apk --debug --no-pub`:
  aprobados; no ejecución nativa. Logs `build/social_identity_{analyze,
  full_tests,web,apk}.log` y `build/social_full_emulator_contract.log`.
- `npm audit --omit=dev`: 0 vulnerabilidades reportadas. Backend declara Node
  22; emuladores utilizaron Node 24 instalado. Gate Node 22 aún pendiente.
- Un build Android frío mostró fallo del caché incremental de Kotlin y terminó
  por fallback; el siguiente compiló correctamente. Aviso de futura retirada de
  soporte KGP/Gradle pendiente del trabajo de plataforma, sin migrarlo aquí.

El error de `exercise_performance.dart` se comprobó contra disco: el controlador
ya importaba `workout_analytics.dart`, biblioteca propietaria del `part`. No se
quitó `part of` ni se modificaron las mejoras de Entrenamiento. Compilación DDC
debug aprobada (`build/expansion_chrome_debug.log`), además del build release.

Límites: `FIT_SOCIAL_ENABLED=false` por defecto; no despliegue ni App Check real
registrado/verificado, push, Storage o prueba Android/iPhone. Limpieza social al
eliminar cuenta y administración de bloqueados siguen pendientes. Pasar estos
tests no certifica todos los criterios de la expansión ni un checkout limpio:
se verificó la carpeta local con avances previos conservados.
