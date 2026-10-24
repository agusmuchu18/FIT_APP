# Privacidad y autorización
Privado por defecto: entrenamientos, fotos, medidas, alimentación, sueño, hábitos,
notas e integraciones. Hacer público un perfil no publica ninguno de esos recursos.

| Contexto | Condición necesaria |
|---|---|
| Dueño | UID autenticado coincide con propietario; local: scope capturado vigente |
| Público | Proyección publicada voluntariamente con campos permitidos; cuenta elegible |
| Seguidor | Relación aceptada + consentimiento de categoría y recurso, sin bloqueo |
| Grupo/entrenador | Membresía y rol efectivos + consentimiento vigente de categoría |

Seguir != pertenecer a grupo != autorización. El rol actual de Grupos es texto libre
de disciplina; no convertirlo en privilegio de administrador. No exponer métricas
centrales para rellenar huecos de otros miembros. Cero != no compartido.

Bloqueo: impedir relación, búsqueda, comentario y mención; grupos compartidos no
eluden bloqueo ni conceden nuevas lecturas. Revocación invalida proyecciones y cachés;
URLs multimedia privadas no son persistentes compartibles. Denegar por defecto.
Backend debe aplicar estas reglas; preferencias y widgets no son controles efectivos.

Fotos públicas deben perder EXIF de ubicación y referencias privadas. Exportaciones
privadas requieren advertencia/selección, sin contraseñas, tokens ni secretos. Política
de eliminación/retención y revisión operativa de reportes requieren implementación
antes de habilitar UGC. No se cambia política de producción en este corte.

Identidad/relaciones: el callable verifica actor real, cuenta disponible, UID y
atestación. Sus proyecciones incluyen solo campos explícitos de identidad; todas
las colecciones sociales siguen denegadas al cliente directo. Get/search/listas
comprueban bloqueos y disponibilidad del destinatario. Seguimiento pendiente no
autoriza biografía/enlace/contadores privados. Sugerencias solo de perfiles públicos
descubribles, sin fotos privadas ni estadísticas. Revisión de emulador no equivale
a App Check verificado en dispositivo ni a reglas desplegadas.
