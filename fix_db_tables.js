const mysql = require('mysql2/promise');
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'markt_db'
};

async function fixDatabase() {
  console.log('🔄 Sincronizando todas las tablas y columnas en MySQL markt_db...');
  try {
    const conn = await mysql.createConnection(dbConfig);

    // 1. Productos
    await conn.query(`
      CREATE TABLE IF NOT EXISTS productos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        codigo VARCHAR(100) UNIQUE,
        nombre VARCHAR(255) NOT NULL,
        precio_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        iva_porcentaje DECIMAL(5,2) DEFAULT 16.00,
        subtexto VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    const [prodCols] = await conn.query('SHOW COLUMNS FROM productos');
    const prodColNames = prodCols.map(c => c.Field);
    if (!prodColNames.includes('precio_usd')) await conn.query('ALTER TABLE productos ADD COLUMN precio_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00');
    if (!prodColNames.includes('iva_porcentaje')) await conn.query('ALTER TABLE productos ADD COLUMN iva_porcentaje DECIMAL(5,2) DEFAULT 16.00');
    if (!prodColNames.includes('subtexto')) await conn.query('ALTER TABLE productos ADD COLUMN subtexto VARCHAR(255)');

    // 2. Clientes
    await conn.query(`
      CREATE TABLE IF NOT EXISTS clientes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        identificacion VARCHAR(100) UNIQUE NOT NULL,
        nombre VARCHAR(255) NOT NULL,
        telefono VARCHAR(100),
        direccion TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    // 3. Empresa
    await conn.query(`
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
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    const [empCols] = await conn.query('SHOW COLUMNS FROM empresa');
    const empColNames = empCols.map(c => c.Field);
    if (!empColNames.includes('logo_size')) await conn.query('ALTER TABLE empresa ADD COLUMN logo_size INT DEFAULT 220');
    if (!empColNames.includes('show_qr')) await conn.query('ALTER TABLE empresa ADD COLUMN show_qr TINYINT(1) DEFAULT 1');
    if (!empColNames.includes('show_barcode')) await conn.query('ALTER TABLE empresa ADD COLUMN show_barcode TINYINT(1) DEFAULT 1');
    if (!empColNames.includes('show_signature')) await conn.query('ALTER TABLE empresa ADD COLUMN show_signature TINYINT(1) DEFAULT 1');
    if (!empColNames.includes('show_tax_table')) await conn.query('ALTER TABLE empresa ADD COLUMN show_tax_table TINYINT(1) DEFAULT 1');
    if (!empColNames.includes('theme')) await conn.query("ALTER TABLE empresa ADD COLUMN theme VARCHAR(50) DEFAULT 'theme-thermal'");

    // 4. Comprobantes
    await conn.query(`
      CREATE TABLE IF NOT EXISTS comprobantes (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(100) UNIQUE NOT NULL,
        doc_type VARCHAR(50) NOT NULL DEFAULT 'venta',
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
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    const [compCols] = await conn.query('SHOW COLUMNS FROM comprobantes');
    const compColNames = compCols.map(c => c.Field);
    if (!compColNames.includes('total_bs_bcv')) await conn.query('ALTER TABLE comprobantes ADD COLUMN total_bs_bcv DECIMAL(12,2) DEFAULT 0.00');
    if (!compColNames.includes('target_currency')) await conn.query("ALTER TABLE comprobantes ADD COLUMN target_currency VARCHAR(10) DEFAULT 'USD'");
    if (!compColNames.includes('suiche_bank')) await conn.query('ALTER TABLE comprobantes ADD COLUMN suiche_bank VARCHAR(20)');
    if (!compColNames.includes('suiche_doc')) await conn.query('ALTER TABLE comprobantes ADD COLUMN suiche_doc VARCHAR(50)');
    if (!compColNames.includes('suiche_phone')) await conn.query('ALTER TABLE comprobantes ADD COLUMN suiche_phone VARCHAR(50)');

    // 5. Comprobante Items
    await conn.query(`
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
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    const [itemCols] = await conn.query('SHOW COLUMNS FROM comprobante_items');
    const itemColNames = itemCols.map(c => c.Field);
    if (!itemColNames.includes('tarifa_iva')) await conn.query('ALTER TABLE comprobante_items ADD COLUMN tarifa_iva DECIMAL(5,2) DEFAULT 0.00');
    if (!itemColNames.includes('subtotal_linea')) await conn.query('ALTER TABLE comprobante_items ADD COLUMN subtotal_linea DECIMAL(12,2) DEFAULT 0.00');

    console.log('🎉 Base de datos MySQL `markt_db` 100% sincronizada.');
    await conn.end();
  } catch (err) {
    console.error('❌ Error migrando MySQL:', err.message);
  }
}

fixDatabase();
