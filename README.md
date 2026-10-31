# FIT App

Aplicación Flutter multiplataforma para registrar entrenamientos, nutrición,
hábitos, sueño y métricas de bienestar. El proyecto funciona con almacenamiento
local y puede sincronizar datos por usuario mediante Firebase Authentication y
Cloud Firestore.

## Estado del proyecto

- Android, iOS, web, Windows, macOS y Linux están presentes como plataformas.
- El modo local permite entrar sin una cuenta y continúa funcionando si Firebase
  no está disponible.
- El acceso con email y el modo invitado utilizan Firebase Authentication.
- La sincronización remota guarda datos bajo `users/{uid}/...`.
- Algunas pantallas secundarias siguen marcadas como "Próximamente" y no deben
  considerarse terminadas para una publicación comercial.

## Requisitos

- Flutter 3.47.2 estable o posterior.
- Dart incluido con Flutter.
- Un proyecto Firebase configurado para las plataformas que se publicarán.

## Puesta en marcha

```bash
flutter pub get --enforce-lockfile
flutter run
```

La configuración generada por FlutterFire está en `lib/firebase_options.dart`.
Antes de usar cuentas o sincronización en producción hay que habilitar Email/
Password y Anonymous en Firebase Authentication, revisar el proyecto Firebase y
desplegar las reglas versionadas en este repositorio:

```bash
firebase deploy --only firestore:rules
```

Si Firebase no puede inicializarse, la aplicación informa el problema en el log
y arranca en modo exclusivamente local.

## Catálogo USDA

La búsqueda remota de FoodData Central es opcional. En aplicaciones nativas se
habilita pasando una clave sólo durante la ejecución o el build:

```bash
flutter run --dart-define=USDA_API_KEY=TU_CLAVE
flutter build apk --dart-define=USDA_API_KEY=TU_CLAVE
```

No se debe pasar `USDA_API_KEY` a un build web: cualquier valor incluido con
`--dart-define` queda dentro del bundle descargable. En web, FIT App deshabilita
la consulta directa y usa el catálogo local hasta que exista un proxy/backend
que custodie la clave.

## Controles de calidad

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
flutter build web --release --base-href "/FIT_APP/"
```

La automatización de GitHub ejecuta formato, análisis y pruebas en cada cambio.
La publicación de GitHub Pages construye la web sin secretos y sólo desde la
rama `master`. Dependabot revisa mensualmente paquetes Dart y GitHub Actions.

## Antes de publicar en tiendas

Todavía son decisiones obligatorias de producto/distribución:

1. Elegir identificadores definitivos de paquete y bundle; aún existen valores
   `com.example` en las plataformas nativas.
2. Crear y custodiar la firma de release de Android; la configuración actual de
   desarrollo no sirve para Play Store.
3. Confirmar y probar las reglas desplegadas de Firestore con el emulador.
4. Configurar los archivos nativos de Firebase y App Check para cada plataforma.
5. Separar y migrar por `uid` el almacenamiento local compartido antes de
   habilitar varias cuentas en un mismo dispositivo.
6. Definir privacidad, eliminación/exportación de cuenta y completar las
   pantallas que todavía aparecen como "Próximamente".

No se cambian automáticamente los identificadores ni las firmas porque deben
coincidir con Firebase y con las fichas definitivas de las tiendas.
