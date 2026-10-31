# Estado de Nutrition 2.0

Actualizado: 31/10/2026. Corte activo: B–H incremental, **verificado en host y navegador**.
QA global: 435 tests aprobados + 1 omitido; análisis limpio; web y APK debug compilados.
No confundir código añadido con aprobación completa de todos los bloques.

| Área | Estado actual | Evidencia / pendiente |
|---|---|---|
| A · diario, cuentas y migración | Probada previamente | Hive v2, UUID, legado preservado; se amplía sin reset |
| B · nutrientes opcionales y decimales | Probada en host | Null se propaga en sumas; gramos/ml independientes |
| B · fuente y micros | Implementada | 424 Foundation oficiales; 50 energías no disponibles; IDs, porciones, métodos y micros reportados |
| B · catálogo español/regional | Parcial | 16 traducciones exactas por ID y alias regionales; resta curación amplia y fuente argentina verificada |
| B · Open Food Facts | Pendiente | API/licencias oficiales consultadas; aún no se incorporan datos OFF |
| C · diario por fecha, edición y borrado recuperable | Probada en host | IDs, snapshots, tombstones y proyección; registro, receta, plan confirmado y borrado/deshacer comprobados en navegador |
| C · favoritos, frecuentes y modos | Implementada | IDs privados, frecuencia de 90 días, misma fuente de datos Lite/Pro |
| C · accesibilidad | Parcialmente probada | 320 px / texto 200 % / claro-oscuro / movimiento reducido; 5 widget tests nuevos pasan |
| D · texto con cantidades explícitas | Probada en host | Parseo local, coincidencias confirmables; no es reconocimiento IA |
| D · código manual GTIN | Probada en host | 6 tests; checksum, coincidencia exacta y caché; transporte de prueba no equivale a llamada de producción |
| D · escáner de cámara | Pendiente | No hay cámara/plugin implementado; no se muestra como escáner funcional |
| D · foto/voz/IA | Bloqueada por infraestructura | Falta proveedor/backend/credenciales; consulta al usuario pendiente; no se envían datos |
| E · recetas y raciones | Probada en host | Se amplían MealTemplate y el selector existente; sin factores de cocción inventados |
| E · planes y compras | Probada en host | Plan != consumo, snapshot e idempotencia; copia semanal probada, idempotente incluso tras consumo; sin solapar semanas |
| E · plan automático/sustituciones | Pendiente | No hay recomendaciones automáticas ni inferencias de dieta |
| F · metas manuales/historia | Probada en host | Vigencia por fecha y revisiones del mismo día; Inicio consulta la misma fuente; sin inventar metas históricas |
| F · Analytics por período | Probada en host y navegador | 7/30/90 días, tabla exacta; cero real/ausencia/desconocido separados; gráfico semanal corregido en 320 px |
| F · cálculo inicial/ajustes/informes | Pendiente | Sin prescripción ni ajustes silenciosos |
| G · notas y suplementos declarados | Probada en host | Privados y separados por cuenta; no prescripción |
| G · ayuno opcional | Probada en host | Desactivado por defecto; ventana, duración e historial durables; sin recordatorios aún |
| G · agua | Integración de acceso | Enlace al seguimiento existente de Hábitos; no se crea otro contador ni se supone equivalencia vaso/ml |
| G · asistente contextual IA | Bloqueada por infraestructura | Mismo bloqueo de proveedor/consentimiento; sin asistente simulado |
| H · copia e importación completas locales | Probada en host | 6 tests; comidas/recetas/propios/favoritos/metas/planes/notas/ventanas; aditiva y sin sobrescribir conflictos |
| H · sincronización rica | Pendiente / depende del backend | Proyección local no equivale a sincronizar recetas, planes o snapshots entre dispositivos |
| H · rendimiento | Parcial | Recuperación ahora lee proyecciones una vez por lote; sin perfilado móvil aún |
| H · validación global y móvil | Host/web probada; móvil bloqueada | 435 + 1 omitida; 5 tests Worker; analyze limpio; web/APK debug; sin dispositivos Android/iPhone ni Mac |

Evidencia de A y del corte B–H: QA_REPORT. **B–H no están terminados al 100 %**: los pendientes de esta matriz siguen vigentes. Sin push, despliegues ni reset.

La prueba manual de copiar/pegar JSON no pudo completarse por el portapapeles virtual del navegador automatizado; no se contabiliza como aprobada. Los tests del coordinador sí validan restauración, versiones, conflictos y reintentos. La copia incluye estado vigente y revisiones de metas, no el archivo interno de revisiones de comidas. Resta validar localización de controles Material, CSV/PDF y scanner/IA.
