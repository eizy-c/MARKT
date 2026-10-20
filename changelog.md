# Registro de Cambios (Changelog) - MARKT POS

Todos los cambios notables en este proyecto serán documentados en este archivo.
El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [2.1.0] - 2026-09-04
### 🚀 Edición Web Standalone & Mobile (Sin Base de Datos)
Esta versión transforma a MARKT en una aplicación **100% Client-Side** diseñada para funcionar de forma autónoma desde cualquier navegador de teléfono móvil o computadora sin necesidad de instalar o configurar servidores MySQL.

#### Añadido
- **Persistencia 100% en Navegador (localStorage)**: Almacenamiento local e instantáneo para Catálogo de Productos, Directorio de Clientes, Historial de Comprobantes, Ajustes de Empresa y Contador de Folio.
- **Auto-registro de Clientes**: Al emitir una factura con una cédula o RIF nuevo, el cliente se guarda automáticamente en el directorio sin pasos adicionales.
- **Copia de Seguridad y Migración (JSON)**:
  - Función de exportación de todos los datos a un archivo .json (MARTK_Respaldo_YYYY-MM-DD.json).
  - Función de importación para restaurar y transferir datos fácilmente entre la computadora y el teléfono móvil.
  - Opción de restablecimiento a valores de fábrica en la pestaña de Ajustes.
- **Optimización para Teléfonos Móviles (PWA & Mobile-First)**:
  - Etiquetas meta para PWA que permiten instalar la web como una App en la pantalla de inicio de Android y iPhone.
  - Adaptación táctil y responsiva del visor del ticket para pantallas estrechas.
  - Botón de eliminación directa de clientes en la tabla del directorio.
- **Servidor Web Estático Ultra-ligero**: server.js detecta la IP local de tu computadora en la red Wi-Fi y muestra el enlace exacto para abrir la web directamente en tu teléfono móvil.

#### Modificado
- Desacopladas todas las llamadas bloqueantes a endpoints de MySQL.
- Consulta directa de tasas oficiales del Banco Central de Venezuela (BCV) para Dólar y Euro vía API pública HTTPS (dolarapi.com).

---

## [2.0.0] - 2026-09-01
### 🏢 Panel de Administración POS & Integración MySQL
- Interfaz renovada tipo Admin Panel con barra de navegación lateral y vistas dedicadas (POS, Productos, Clientes, Historial, Ajustes).
- Dualidad monetaria automática ($ USD / Bs. BCV).
- Generador de códigos QR bajo el estándar Pago Móvil Suiche 7B.
- Formato de impresión térmica de tickets y descarga de comprobantes en imagen PNG.

---

## [1.0.0] - 2026-08-15
### 🐣 Versión Inicial (FacturaExpress)
- Prototipo inicial de facturación rápida con vista previa de tickets e impresión básica.
