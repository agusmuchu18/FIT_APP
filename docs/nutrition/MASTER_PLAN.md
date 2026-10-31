# Nutrition 2.0

Solicitud maestra recibida el 29/10/2026. Fuente visual: `../design/DESIGN_SYSTEM.md`.
Auditoría canónica: [NUTRITION_AUDIT.md](NUTRITION_AUDIT.md); no mantener otra
auditoría independiente con datos distintos.

| Lote | Resultado exigido | Dependencias / cierre |
|---|---|---|
| A · datos seguros | Diario canónico, aislamiento, migración, repetición sin pérdida, proyección a Inicio/Analytics, metas honestas | Persistencia tras reapertura, concurrencia, errores y cuentas; ver QA_REPORT |
| B · motor/alimentos | Nutrientes nullable con fuente/unidad/calidad; decimales; porciones fiables; normalización española; USDA y fuentes regionales | Revisar semillas actuales, fuentes/licencias, ausencia vs cero, crudo/cocido, caché y ranking verificable |
| C · experiencia visual | Home por fecha, diario editable, búsqueda/ficha, recientes/frecuentes/favoritos; Lite/Pro como profundidad | Auditar grabación Fitia identificada; tokens existentes; revisión 320/390 px, texto grande, todos los temas y recorridos |
| D · registro avanzado | Código, foto/texto/voz con candidatos editables y confirmación | Proveedores oficiales/backend, consentimiento, cuotas, cámara/mic reales, errores sin perder borrador |
| E · recetas/planes | Ingredientes/raciones/rendimiento, planes separados de consumo, sustituciones y compras | Ningún factor de cocción inventado; conversiones compatibles; confirmar antes de registrar planes |
| F · metas/estadísticas | Metas manuales e históricas, propuestas confirmadas, períodos/ausencias/informes | Reutilizar preferencias y motor existente; no recomendaciones médicas ni ajuste silencioso |
| G · complementos | Agua, suplementos declarados, actividad, notas, ayuno/asistente opcionales | No duplicar hábitos/actividad; sin prescripción; IA privada con acceso mínimo |
| H · entrega | Integraciones, accesibilidad, rendimiento medido, sincronización/importación/exportación y QA móvil | Android/iPhone reales, revisión de permisos y pruebas de fallos; no confundir compilación con dispositivo |

Cada lote debe producir código, regresiones, evidencia y estado explícito.
No se cambia la navegación principal ni Entrenamiento. No se despliega, publica
ni hace push sin autorización. La paridad global con Fitia **no está completada**
por terminar el lote A.

El árbol de partida ya tenía cambios locales extensos. Se conserva una copia de
51 archivos previa al corte; las diferencias del trabajo deben revisarse contra
esa copia, además de Git, para no atribuir cambios anteriores a Nutrition 2.0.


Avance del 31/10: B–H tienen implementaciones incrementales en el repositorio;
el estado por capacidad está en IMPLEMENTATION_STATUS y las verificaciones en
QA_REPORT. La aprobación global de B–H sigue pendiente de capacidades señaladas
allí; no se exige repetir A ni rehacer funciones terminadas en próximas sesiones.
