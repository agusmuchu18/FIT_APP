# Auditoría funcional · 23/10/2026
Inspección estática de la carpeta local antes de editar esta fase. Estado previo;
la evidencia nueva se añade a IMPLEMENTATION_STATUS/TEST_REPORT, sin reescribir
esta línea base. IMPLEMENTADA no significa certificada en teléfono/producción.

| Capacidad | Estado | Evidencia / límite / siguiente comprobación |
|---|---|---|
| Navegación y Home configurable | IMPLEMENTADA | navigation/main_shell.dart, home/home_summary_screen.dart, core/data/home_modules_controller.dart; conservar 4 destinos y acción + |
| Auth UID / invitado / cambio cuenta | IMPLEMENTADA | auth/data/auth_service.dart, core/data/account_session_gate.dart, account_storage_scope.dart; Firebase real + fallback; revisar singletons ajenos |
| Cajas locales / sync | PARCIAL | core/data/repositories.dart, remote_sync_service.dart; Hive por cuenta; cuatro tipos remotos, no social |
| Grupos / crear / agregar miembro | SOLO VISUAL | groups/domain/groups_service.dart: mapa en memoria, _seed, Random, IDs sin Firebase; grupos creados se pierden al reiniciar |
| Métricas de miembros | SOLO VISUAL | _generateSampleActivity/_averageCaloriesPerDay/_averageSleepHours escriben ejemplos a StatisticsService; riesgo de contaminar estadísticas, no autorización real |
| Roles/permisos/invitaciones | AUSENTE | GroupMember.role es texto de disciplina, no RBAC; IDs member-* no son UID; no solicitudes ni consentimiento |
| Descubrir / búsqueda / sugerencias | AUSENTE | no repositorio/índice social ni consulta remota autorizada |
| Follow / solicitudes / contadores | AUSENTE | no relaciones, transacciones o backend social |
| Perfil / avatar / nombre | PARCIAL | profile_controller.dart: singleton RAM global; editor usa image_picker, sin persistencia ni dueño |
| @usuario / biografía / enlace | SOLO VISUAL | profile_social_screen.dart usa @fit_user y En definición; sin unicidad ni modelo público |
| Fotos / galería | SOLO VISUAL | ProfileProgressPhoto contiene URL/dateLabel; seis picsum.photos; sin CRUD, privacidad ni almacenamiento propio |
| Estadísticas y PRs propios | IMPLEMENTADA | integración validada en 4cc13df, índice único; no ampliar motor de Entrenamiento |
| Perfil ajeno / visibilidad | AUSENTE | no proyección pública ni endpoint autorizado |
| Publicaciones / feeds / publicación de sesiones | AUSENTE | no SocialPost ni representación pública permitida |
| Likes / comentarios / menciones | AUSENTE | sin modelos/persistencia/antiabuso |
| Compartir visual propio | IMPLEMENTADA | workout/domain/training_export.dart, presentation/training_export_screen.dart; PNG/share_plus; no publicaciones ni enlaces sociales |
| Bloqueos / reportes / revisión | AUSENTE | sin moderación operativa |
| Notificaciones / preferencias | PARCIAL | settings_subscreens.dart + AppPreferences, switches guardados globalmente; UI dice push pendiente; no eventos/centro ni proveedor push |
| Privacidad / biometría | SOLO VISUAL | privateOnly/groupShared y biometricLock en prefs; no autenticación biométrica ni autorización por recurso |
| Peso de onboarding | PARCIAL | onboarding_screen.dart TextEditingController; no historial corporal verificado |
| Medidas / bilaterales / grasa / masa magra | AUSENTE | búsqueda acotada lib fuera de workout/nutrition no encuentra modelo equivalente durable |
| Historial/gráficos corporales | AUSENTE | gráficos existentes no constituyen seguimiento corporal |
| Integraciones (18 accesos) | PARCIAL | ver INTEGRATIONS.md; canales Dart sin handlers nativos; tres flags disponibles no prueban conexión |
| Export/import general | SOLO VISUAL | settings_subscreens.dart DataSettingsScreen: TODO/onTap vacío y diálogo Próximamente; no backup real |
| Cuenta / logout / eliminación | PARCIAL | auth real y logout; no flujo verificado de eliminación/retención/social cleanup |
| Unidades | PARCIAL | entrenamiento implementado por cuenta; no configuración corporal común todavía |
| Idioma / temas / accesibilidad | PARCIAL | Inter local y temas; raíz fija oscuro, variantes/prefs no conectadas integralmente; no gen_l10n global verificado |
| Suscripción | SOLO VISUAL | settings_screen.dart muestra Premium activo; no compras/entitlements reales ni facturación |
| Reglas backend | PARCIAL | firestore.rules: solo propietario workouts/meals/sleep/preferences; resto denegado. Despliegue y emulador NO VERIFICADOS |
| Seguridad multimedia | AUSENTE | no Storage Rules, URLs firmadas, EXIF/miniaturas o control de archivos propios |
| Pruebas sociales/backend | AUSENTE | base 270 incluye entrenamiento y otros features; no autoriza afirmar QA social |

Inventario Hevy suministrado por el usuario: referencia de capacidades, no evidencia
de comportamiento observado. La grabación previa no se ha reproducido en este corte.
Feeds/menús/video/menciones/suscripciones de la referencia: NO VERIFICADA su ejecución;
se diseña solución propia y no se copian assets ni estructuras propietarias.

Las notas antiguas de docs/ARCHITECTURE e INTEGRATIONS distinguen otra continuidad.
Los hallazgos anteriores se contrastaron con código local, no con la rama remota.
