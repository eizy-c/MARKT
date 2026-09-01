# MARTK - Sistema POS & Panel de Administración

MARTK es un sistema web de Punto de Venta (POS) y administración integral diseñado para negocios en Venezuela. Ofrece emisión de facturas electrónicas de venta, recibos de caja (ingresos), comprobantes de egreso, catálogo de productos, directorio de clientes y cálculo automático de montos con la tasa de referencia del Banco Central de Venezuela (BCV).

## Características Principales

- **Panel de Administración POS**: Interfaz sobria y profesional con navegación lateral y soporte responsivo para dispositivos móviles.
- **Múltiples Documentos**: Factura de Venta, Recibo de Caja (Ingreso) y Comprobante de Egreso.
- **Dualidad Monetaria ($ USD / Bs. BCV)**: Entrada de precios en dólares ($ USD) con cálculo y conversión automática a Bolívares (Bs.) usando la tasa oficial del día de DolarApi / BCV.
- **Directorio de Clientes**: Búsqueda por número de Cédula o RIF con autocompletado y guardado directo en base de datos.
- **Catálogo de Productos y Servicios**: Registro de productos con precios en USD e IVA que pueden agregarse a la factura en un clic.
- **Generación de Código QR Suiche 7B**: Creación de cadenas Pago Móvil interbancario de Venezuela con banco receptor, RIF, teléfono y monto ajustado en Bolívares.
- **Formatos de Salida**: Descarga de comprobantes en formato de imagen PNG, impresión limpia adaptada a impresoras térmicas y envío estructurado por WhatsApp.
- **Persistencia en MySQL (`markt_db`)**: Almacenamiento directo de datos de empresa, productos, clientes, historial de facturas y preferencias de formato.

## Estructura del Proyecto

- `server.js`: Servidor REST API en Node.js y Express con conexión a MySQL.
- `schema.sql`: Script de creación y estructura de tablas para la base de datos `markt_db`.
- `index.html`: Estructura principal de la interfaz web.
- `styles.css`: Sistema de diseño visual sobrio y corporativo.
- `app.js`: Lógica cliente en JavaScript para gestión de estado, eventos y previsualización.
- `create_db.js`: Script auxiliar para creación inicial de la base de datos `markt_db`.
- `clear_db.js`: Script auxiliar para limpieza de registros en MySQL.

## Requisitos del Sistema

- **Node.js** v16.0 o superior.
- **MySQL Server** (u otro servidor MariaDB compatible) escuchando en `localhost:3306`.
- Navegador web moderno (Chrome, Edge, Firefox, Safari).

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

### 3. Configurar la Base de Datos MySQL

Verifica que tu servicio MySQL se encuentre en ejecución y ejecuta el script de inicialización de la base de datos:

```bash
node create_db.js
```

O bien, importa directamente la estructura desde la consola de MySQL:

```bash
mysql -u root -p < schema.sql
```

### 4. Iniciar el Servidor Backend

```bash
node server.js
```

El servidor indicará que está escuchando en `http://localhost:5000`.

### 5. Iniciar la Interfaz de Usuario

Abre `index.html` directamente en tu navegador o ejecuta un servidor web local:

```bash
python -m http.server 3000
```

Accede a `http://localhost:3000` en tu navegador.

## Desarrollado Por

Desarrollado por **EIZY SYSTEM** (@eizy-c) para el sistema **MARTK Admin POS**.
Repositorio oficial: [https://github.com/eizy-c/MARKT](https://github.com/eizy-c/MARKT)