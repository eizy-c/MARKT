-- ==========================================================================
-- MARTK - Esquema de Base de Datos MySQL (markt_db)
-- ==========================================================================

CREATE DATABASE IF NOT EXISTS markt_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE markt_db;

-- 1. Tabla de Perfil de Empresa y Preferencias por Defecto
CREATE TABLE IF NOT EXISTS empresa (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  identificacion VARCHAR(100),
  direccion TEXT,
  telefono VARCHAR(100),
  doc_titulo VARCHAR(255) DEFAULT 'FACTURA ELECTRÓNICA DE VENTA',
  moneda VARCHAR(20) DEFAULT '$',
  tasa_cambio DECIMAL(10,4) DEFAULT 798.3300,
  mostrar_doble_moneda TINYINT(1) DEFAULT 1,
  logo_base64 LONGTEXT,
  logo_size INT DEFAULT 220,
  show_qr TINYINT(1) DEFAULT 1,
  show_barcode TINYINT(1) DEFAULT 1,
  show_signature TINYINT(1) DEFAULT 1,
  show_tax_table TINYINT(1) DEFAULT 1,
  theme VARCHAR(50) DEFAULT 'theme-thermal',
  notas_pie TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Tabla del Catálogo de Productos / Servicios
CREATE TABLE IF NOT EXISTS productos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(100) UNIQUE,
  nombre VARCHAR(255) NOT NULL,
  precio_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  iva_porcentaje DECIMAL(5,2) DEFAULT 16.00,
  subtexto VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Tabla del Directorio de Clientes
CREATE TABLE IF NOT EXISTS clientes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  identificacion VARCHAR(100) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  telefono VARCHAR(100),
  direccion TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Tabla Principal de Comprobantes Emitidos
CREATE TABLE IF NOT EXISTS comprobantes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  uuid VARCHAR(100) UNIQUE NOT NULL,
  doc_type VARCHAR(50) NOT NULL DEFAULT 'venta', -- 'venta', 'ingreso', 'egreso'
  doc_title VARCHAR(255) NOT NULL,
  doc_number VARCHAR(100) NOT NULL,
  doc_date DATE NOT NULL,
  doc_time VARCHAR(50),
  cliente_nombre VARCHAR(255) NOT NULL,
  cliente_identificacion VARCHAR(100),
  cliente_telefono VARCHAR(100),
  cliente_direccion TEXT,
  forma_pago VARCHAR(100) NOT NULL DEFAULT 'Pago Móvil',
  vendedor VARCHAR(100),
  concepto TEXT,
  referencia VARCHAR(100),
  saldo_anterior DECIMAL(12,2) DEFAULT 0.00,
  nuevo_saldo DECIMAL(12,2) DEFAULT 0.00,
  subtotal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  impuesto_porcentaje DECIMAL(5,2) DEFAULT 0.00,
  impuesto_monto DECIMAL(12,2) DEFAULT 0.00,
  descuento DECIMAL(12,2) DEFAULT 0.00,
  total_principal DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  total_bs_bcv DECIMAL(12,2) DEFAULT 0.00,
  moneda VARCHAR(20) DEFAULT '$',
  tasa_ref DECIMAL(10,4) DEFAULT 1.0000,
  target_currency VARCHAR(10) DEFAULT 'USD',
  suiche_bank VARCHAR(20),
  suiche_doc VARCHAR(50),
  suiche_phone VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Tabla de Detalle de Ítems del Comprobante
CREATE TABLE IF NOT EXISTS comprobante_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  comprobante_id INT NOT NULL,
  cantidad INT NOT NULL DEFAULT 1,
  descripcion VARCHAR(255) NOT NULL,
  subtexto VARCHAR(255),
  tarifa_iva DECIMAL(5,2) DEFAULT 0.00,
  precio_unitario DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  subtotal_linea DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  FOREIGN KEY (comprobante_id) REFERENCES comprobantes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
