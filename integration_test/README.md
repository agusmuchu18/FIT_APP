# Recorrido local de Entrenamiento

Preparado y compilado para Android debug el 2026-10-02.
Recorrido actualizado y ensayado en host el 2026-10-12: confirmación previa,
resumen persistido, vuelta al inicio e historial filtrado. El APK de integración
anterior no acredita este corte; ejecutar de nuevo en un dispositivo disponible.
**Todavía no ejecutado en Android/iPhone.**

Usa `integration_test` del SDK Flutter y las pantallas reales del módulo. No
inicia Firebase ni usa cuentas de producción. Preferencias y Hive son reales
en el dispositivo, bajo un namespace único que se elimina al terminar. Nunca
limpia datos de invitado ni de cuentas existentes.

## Ejecutar

Desde la raíz del repositorio, resolver dependencias y seleccionar explícitamente
un dispositivo listado por Flutter:

```powershell
flutter pub get
flutter devices
flutter test integration_test/workout_local_journey_test.dart -d <device-id>
```

Android necesita equipo autorizado por USB o un AVD preparado. iPhone/simulador
necesita macOS, Xcode y la configuración/firma del proyecto. No se instala ni se
borra un emulador automáticamente. Usar un equipo de prueba; la ejecución
instala el build de integración con la identidad de aplicación del proyecto.

## Afirmaciones

1. Nueva rutina permite seleccionar un ejercicio del catálogo inicial y guardarlo.
2. La rutina inicia una sesión; una edición se conserva al volver y reabrir.
3. Pausar persiste el estado y permite reanudar.
4. Finalizar muestra confirmación, guarda una sesión y abre el resumen por ID;
   volver al inicio permite comprobar el estado registrado.
5. Historial rico y proyección central tienen el mismo ID, sin duplicados.
6. Entrenamiento muestra sesión registrada y el historial contiene la rutina.

El repositorio de proyección de esta prueba delega en `LocalStorageService`
real. Autenticación, sincronización remota, el bootstrap de `main`, mini-barra,
permisos nativos, cierre forzado, accesibilidad de plataforma y rendimiento
no forman parte de este recorrido.

## Ensayo del recorrido en host

```powershell
flutter test test/features/workout/workout_device_journey_rehearsal_test.dart
```

Este ensayo comparte exactamente las acciones y afirmaciones del recorrido,
pero simula preferencias y usa Hive en una carpeta temporal; no verifica
plugins nativos. Pasó a 390×844. La matriz pendiente completa está en
`docs/plans/WORKOUT_READINESS_2026_10_01.md`.
