# MARKT POS - Sistema de Facturación & POS Web Móvil (v2.1.0)

**MARKT** es un sistema web de Punto de Venta (POS) y emisión de facturas electrónicas, recibos de caja y comprobantes de egreso diseñado para comercios en Venezuela. Opera en modo **100% Autónomo (Serverless / Standalone)**: no requiere instalar ni configurar bases de datos MySQL, permitiendo su uso instantáneo en computadoras y **teléfonos móviles**.

## ✨ Características Principales

- **100% Sin Base de Datos**: Funciona de forma inmediata en el navegador del usuario utilizando `localStorage`.
- **Optimizado para Teléfonos Móviles (PWA & Responsive)**: Interfaz adaptada a pantallas táctiles, barra de navegación inferior móvil y soporte para agregar como App a la pantalla de inicio en Android e iOS.
- **Múltiples Documentos**: Factura de Venta, Recibo de Caja (Ingreso) y Comprobante de Egreso con numeración correlativa automática.
- **Dualidad Monetaria ($ USD / Bs. BCV)**: Entrada de precios en dólares ($ USD) con cálculo y conversión automática a Bolívares usando la tasa oficial del día de **DolarApi / BCV** en tiempo real.
- **Directorio de Clientes Inteligente**: Búsqueda por número de Cédula o RIF y **auto-registro automático** de clientes al emitir cada factura.
- **Catálogo de Productos y Servicios**: Registro de productos con precios en USD e IVA que pueden agregarse a la factura en un clic.
- **Generación de Código QR Suiche 7B**: Creación de cadenas Pago Móvil interbancario de Venezuela con banco receptor, RIF, teléfono y monto ajustado en Bolívares.
- **Formatos de Salida**: Descarga de comprobantes en formato de imagen PNG, impresión limpia adaptada a impresoras térmicas y envío estructurado por WhatsApp.
- **Respaldo y Migración (JSON)**: Exporta e importa copias de seguridad de todos tus datos para transferirlos entre tu computadora y tu teléfono.

## Estructura del Proyecto

- `index.html`: Estructura principal de la interfaz web y soporte PWA móvil.
- `styles.css`: Sistema de diseño visual sobrio, corporativo y táctil.
- `app.js`: Lógica cliente en JavaScript 100% autónoma (`localStorage`, DolarApi BCV, Suiche 7B y respaldo JSON).
- `server.js`: Servidor web ligero opcional en Node.js que detecta la IP local para acceso desde el teléfono en la red Wi-Fi.
- `CHANGELOG.md`: Historial de versiones y releases.
- `schema.sql`: Esquema SQL de referencia.

## Instrucciones de Instalación y Uso

### 1. Clonar el Repositorio

```bash
git clone https://github.com/eizy-c/MARKT.git
cd MARKT
```

### 2. Instalar Dependencias

```bash
npm install
```

### Opción 1: Abrir directamente (Sin instalar nada)
Simplemente haz doble clic en `index.html` en tu computadora para empezar a facturar de inmediato.

### Opción 2: Iniciar servidor local y conectar con el Teléfono Móvil
Si deseas compartir la aplicación con tu teléfono móvil en la misma red Wi-Fi:

```bash
# 1. Instalar dependencias
npm install

# 2. Iniciar servidor
npm start
```

La consola te mostrará dos enlaces:
- `http://localhost:5000` para abrir en tu computadora.
- `http://192.168.X.X:5000` para abrir en el navegador de tu **teléfono móvil** conectado al mismo Wi-Fi.

### Opción 3: Despliegue en la Web (Landing Page / Hosting Gratuito)
Al ser una aplicación web estática autónoma, puedes subirla con 1 clic a:
- **GitHub Pages**: Sube los archivos al repositorio `https://github.com/eizy-c/MARKT` y activa GitHub Pages en *Settings > Pages*.
- **Vercel** o **Netlify**: Conecta tu repositorio para tener un enlace público HTTPS accesible desde cualquier teléfono en cualquier lugar.

## Desarrollado Por

Desarrollado por **EIZY SYSTEM** (@eizy-c) para el sistema **MARTK Admin POS**.
Repositorio oficial: [https://github.com/eizy-c/MARKT](https://github.com/eizy-c/MARKT)