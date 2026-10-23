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
