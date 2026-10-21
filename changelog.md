# Registro de Cambios (Changelog) - MARKT POS & Business OS

Todos los cambios notables en este proyecto son documentados en este archivo.
El formato esta basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [4.0.0] - 2026-10-20
### Plataforma Universal de Negocios & Almacenamiento Fisico Nativo

Esta version marca la transformacion de MARKT en un Sistema Operativo de Negocios Universal aplicable a cualquier tipo de comercio, taller, tienda minorista, servicios profesionales o industria.

#### Anadido
- **Almacenamiento Fisico Nativo en Telefono (`MarktNativeStorage`)**:
  - Canal bidireccional Flutter-JavaScript via `path_provider` en Android/iOS.
  - Almacenamiento directo en archivos fisicos `.json` en memoria interna sin limites de 5-10MB.
  - Persistencia blindada: la informacion no se borra al limpiar el navegador o la cache del sistema.
- **Catálogos Universales con Costos y Márgenes (Fase 1)**:
  - Catálogo de Productos con Costo ($ USD), Margen Estimado %, Stock Actual y Stock Mínimo.
  - Catálogo de Servicios Profesionales con tarifa por hora/fija y costo operativo estimado.
  - Catálogo de Materiales e Inventario de Reposición.
  - Directorio de Proveedores con RIF/Cédula, contacto y rubro.
  - Directorio de Vendedores & Empleados con % de comisión asignable por venta.
- **Libro de Caja & Movimientos Ilimitados (Fase 2)**:
  - Saldo en tiempo real: Ingresos, Gastos y Saldo Neto ($ USD y Bs. al cambio BCV).
  - Desglose por método de pago: Efectivo USD, Efectivo Bs, Pago Móvil, Transferencia, Punto de Venta, Zelle.
  - Integración automática con Terminal POS: cada comprobante emitido alimenta la caja al instante.
  - Compartir Arqueo de Caja diario o por período por WhatsApp o portapapeles.
- **Cuentas por Cobrar & Deudores - "Quién me debe" (Fase 3)**:
  - Control de ventas a crédito con fecha de vencimiento y estado (Al día, Vencida, Saldada).
  - Registro de Abonos parciales con recálculo de saldo en vivo e impacto automático en el Libro de Caja.
  - Botón de cobro con Recordatorio amable formateado para enviar por WhatsApp en 1 clic.
- **Analítica Financiera & Reportes Gerenciales (Fase 5)**:
  - Filtro por fecha: Hoy, Esta Semana, Este Mes, Mes Anterior, Histórico Completo.
  - Métricas clave: Ventas Facturadas, Costo de Mercancía (COGS), Gastos Operativos de Caja y Utilidad Neta Real del Negocio con Margen %.
  - Ranking de Productos más vendidos y Rendimiento de Vendedores con Comisiones Ganadas.
  - Exportación de resumen financiero a WhatsApp.
- **Escáner Inteligente de Facturas con Cámara / OCR (Fase 6)**:
  - Captura directa desde la cámara del teléfono para digitalizar facturas y comprobantes físicos.
  - Extracción automática de Monto, Proveedor y RIF para registrar gastos de caja al instante.
- **Políticas de Privacidad Integradas**:
  - Sección dedicada accesible desde Ajustes y lista para publicaciones en Google Play Store / Apple App Store.
  - Declaración explícita de Cero Rastreo (Zero Analytics, Zero Telemetry, 100% privacidad en el dispositivo).
- **Visor de Registro de Cambios (Changelog) en la App**:
  - Visualización interactiva de las novedades de cada versión directamente en Ajustes.
- **Generalización Universal**:
  - Selector de rubro comercial (Comercio, Servicios, Taller, Retail, Alimentos, General).

#### Modificado
- Purgado definitivo del directorio `vista-stich` y archivos web sueltos en raiz: el proyecto ahora es exclusivamente la aplicacion Flutter `markt_app/`.
- Sincronizacion de tasa oficial BCV blindada a 881.88 Bs./$ con fallback anti-tasas obsoletas.

---

## [3.0.0] - 2026-10-20
### Interfaz Des-encajonada (Unboxed) & Cero Modales en Movil

#### Anadido
- Vistas dedicadas de pantalla completa para el Ticket (`view-ticket`) y Detalle de Cotizaciones (`view-cotizacion-detalle`) con scroll tactil natural, eliminando modales flotantes bloqueantes.
- Selector de comprobante con cambio dinamico: Factura de Venta, Recibo de Caja (Cobro) y Comprobante de Egreso.
- Panel en linea para edicion rapida de clientes en el Punto de Venta.

#### Modificado
- Diseno unboxed de 1 solo nivel de superficie inspirado en Material You / Stitch sin anidamiento de cajas.
- 0 emojis unicode en toda la aplicacion; iconos vectoriales limpios via Material Symbols Outlined.

---

## [2.1.0] - 2026-09-04
### Edicion Standalone & Mobile

- Modo autonomo sin base de datos externa obligatoria.
- Exportacion e importacion de respaldos en formato JSON.
- Integracion de Suiche 7B para cobros con Pago Movil mediante codigo QR interoperable.

---

## [2.0.0] - 2026-09-01
### Panel de Administracion & Multimoneda

- Soporte dual USD ($) y Bolivares (Bs.) con tasa oficial BCV.
- Formato de impresion termica y descarga en imagen PNG.

---

## [1.0.0] - 2026-08-15
### Version Inicial
- Prototipo inicial de facturacion rapida y emision de tickets.
