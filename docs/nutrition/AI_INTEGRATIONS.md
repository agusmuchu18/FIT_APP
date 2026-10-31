# Integraciones IA y captura

Estado al cerrar el primer corte: **Pendiente**. No se implementaron reconocedores
de foto/voz/texto, cámara ni lector de códigos. Los accesos existentes no prueban
una integración real. No se envían diarios, imágenes o audio para IA en este lote.

Contrato previsto D: entrada → candidatos → resolución de catálogo → cantidades
editables → vista previa → confirmación → diario canónico. Una foto no mide
gramos con exactitud; ingredientes ocultos y porciones deben señalarse como
estimados. Fallar no debe borrar el borrador ni impedir la vía manual.

Antes de habilitar: proveedor/API oficial, backend sin secretos en Flutter,
consentimiento granular, contenido mínimo, cuotas/coste, retención/eliminación,
permisos móviles y tests reales. No se presentan mocks como IA de producción.

## Avance D · 30/10

Texto estructurado local y entrada manual de códigos implementados. No son IA
ni escaneo de cámara. El texto requiere cantidad/unidad; las coincidencias ambiguas
se confirman. Los errores conservan la entrada y nada se consume automáticamente.

Se consultó al usuario si ya dispone de proveedor/backend IA. No hay una respuesta
ni credenciales configuradas para este corte. Foto, voz, asistente, sugerencias IA
y escáner de cámara siguen pendientes; no se habilitan botones que aparenten
reconocimiento real. La imagen editorial de recetas es un asset generado, no un
reconocedor de fotografías del usuario.
