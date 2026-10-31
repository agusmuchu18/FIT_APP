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

## Medidas corporales locales · 24/10/2026
12 pruebas nuevas con Hive temporal real: reapertura, IDs/unidades originales,
registro parcial sin inferencias, aislamiento invitado/A/B, repositorio obsoleto,
12 escrituras concurrentes, revisiones de edición/borrado, fallo/reintento,
corrupción/versiones futuras, fechas/valores inválidos, formularios e historial.
Tres capturas revisadas: formulario claro normal, formulario claro 320 px/200%
con error completo y tendencia oscura 320 px/200%/movimiento reducido.
Se corrigió truncamiento en etiquetas largas y errores; acciones nuevas usan el
turquesa existente y altura mínima de 48. Estadísticas del Perfil conserva sus
cálculos y suma un acceso: se actualizaron solo dos goldens de esa pestaña.
El test de guardado del editor ahora espera el frame de desplazamiento antes
de pulsar Guardar (antes tocaba fuera del viewport tras añadir el nuevo acceso).

Suite final: **345 aprobadas + 1 omitida**, después de las correcciones visuales
y de semántica. Análisis estricto: 0 incidencias. La omitida requiere emuladores
y ya pasó separadamente en el corte social.
Logs `build/body_measurements_{tests,full_tests,analyze,web,apk}.log`.
El contrato omitido y las 13 pruebas backend conservan la evidencia del corte
social anterior: este bloque no cambia servidor, Rules ni App Check.

Límites específicos: manual/local; no importación ni sincronización de medidas,
sin nueva publicación/compartición, fuentes de dispositivos pendientes. La
galería no tiene todavía CRUD/comparación durable. No hubo benchmark móvil ni
pruebas de miles de mediciones: el historial renderiza bloques de 30, mientras
la consulta local de tendencia lee los registros de esta caja. No afirmar
rendimiento certificado para tienda ni validación Android/iPhone.

Builds finales aprobados: web release (45,4 s) y APK debug (14,0 s).
Recorrido real en navegador local a 390×844: Perfil → Estadísticas → Medidas →
guardar solo peso con nota de prueba → recarga completa → volver al historial.
El registro sintético se restauró; no se utilizaron datos personales. Se comprobó
también Grupos → Descubrir con servicio deshabilitado, sin resultados ficticios.
Evidencia: [historial restaurado](evidence/body-measurements-persisted.png),
[estado real de Descubrir](evidence/discovery-service-disabled.png).
El recorrido detectó y permitió corregir etiqueta duplicada para lector de
pantalla, contraste del tooltip y rango degenerado con un único punto.

Validación manual: desde Estadísticas o edición del Perfil abrir Medidas;
guardar una o varias métricas, cambiar período/medida, comparar dos registros,
editar notas y revisar unidades originales. Eliminar exige confirmación.
Para repetir la prueba automatizada local: `flutter test --no-pub
test/features/profile/body_measurements_test.dart`; los registros sintéticos
de ese test viven en una caja Hive temporal, nunca en datos de producción.
No se alteraron motores de entrenamiento, reglas desplegadas ni navegación.
