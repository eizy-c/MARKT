const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json({ limit: '50mb' }));

// Configuración de Conexión a MySQL markt_db
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'markt_db',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

const pool = mysql.createPool(dbConfig);

// --- SECURITY & INPUT SANITIZATION HELPERS ---

/**
 * Sanitiza y limpia cualquier cadena de texto evitando inyecciones o caracteres de control no deseados.
 */
function sanitizeString(str, maxLen = 255) {
  if (str === null || str === undefined) return '';
  let clean = String(str).trim();
  // Eliminar caracteres de control ASCII invisibles excepto saltos de línea y tabuladores
  clean = clean.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');
  // Normalizar espacios múltiples
  clean = clean.replace(/[ \t]+/g, ' ');
  return clean.slice(0, maxLen);
}

/**
 * Formatea y limpia identificaciones, Cédulas y RIF (Ej: ' v-12.345.678 ' -> 'V-12345678')
 */
function formatIdentificacion(idStr) {
  if (!idStr) return '';
  let clean = String(idStr).trim().toUpperCase();
  clean = clean.replace(/[^A-Z0-9-]/g, '');
  return clean.replace(/-+/g, '-').slice(0, 50);
}

/**
 * Formatea y limpia números telefónicos (Ej: '+58 (414) 123-4567' -> '584141234567')
 */
function formatPhone(phoneStr) {
  if (!phoneStr) return '';
  let clean = String(phoneStr).replace(/[^0-9]/g, '');
  return clean.slice(0, 20);
}

/**
 * Valida y desinfecta números flotantes (previene NaN, Infinity e Inyecciones de tipo)
 */
function sanitizeFloat(val, defaultVal = 0, min = 0, max = 999999999) {
  const parsed = parseFloat(val);
  if (isNaN(parsed) || !isFinite(parsed)) return defaultVal;
  return Math.min(Math.max(parsed, min), max);
}

/**
 * Valida y desinfecta números enteros
 */
function sanitizeInt(val, defaultVal = 0, min = 0, max = 2147483647) {
  const parsed = parseInt(val, 10);
  if (isNaN(parsed) || !isFinite(parsed)) return defaultVal;
  return Math.min(Math.max(parsed, min), max);
}

// Auto-Migración Inteligente del Esquema de MySQL al Iniciar
async function autoMigrateSchema() {
  try {
    const conn = await pool.getConnection();

    await conn.query(`
      CREATE TABLE IF NOT EXISTS productos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        codigo VARCHAR(100) UNIQUE,
        nombre VARCHAR(255) NOT NULL,
        precio_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        iva_porcentaje DECIMAL(5,2) DEFAULT 0.00,
        subtexto VARCHAR(255),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);

    const [prodCols] = await conn.query('SHOW COLUMNS FROM productos');
    const prodColNames = prodCols.map(c => c.Field);
    if (!prodColNames.includes('precio_usd')) await conn.query('ALTER TABLE productos ADD COLUMN precio_usd DECIMAL(10,2) NOT NULL DEFAULT 0.00');
    if (!prodColNames.includes('iva_porcentaje')) await conn.query('ALTER TABLE productos ADD COLUMN iva_porcentaje DECIMAL(5,2) DEFAULT 0.00');
    if (!prodColNames.includes('subtexto')) await conn.query('ALTER TABLE productos ADD COLUMN subtexto VARCHAR(255)');

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
        show_tax_table TINYINT(1) DEFAULT 0,
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
    if (!empColNames.includes('show_tax_table')) await conn.query('ALTER TABLE empresa ADD COLUMN show_tax_table TINYINT(1) DEFAULT 0');
    if (!empColNames.includes('theme')) await conn.query("ALTER TABLE empresa ADD COLUMN theme VARCHAR(50) DEFAULT 'theme-thermal'");

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

    conn.release();
    console.log('✅ Esquema MySQL markt_db auto-migrado, blindado y sincronizado.');
  } catch (err) {
    console.error('⚠️ Error durante auto-migración MySQL:', err.message);
  }
}

autoMigrateSchema();

// Health Check Endpoint
app.get('/api/health', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT 1 + 1 AS result');
    res.json({ status: 'OK', message: 'Servidor MARTK en línea, seguro y conectado a MySQL', db: rows[0].result === 2 });
  } catch (error) {
    res.status(500).json({ status: 'ERROR', message: 'Error en la conexión a la base de datos' });
  }
});

// GET /api/empresa - Obtener perfil de la empresa desde MySQL
app.get('/api/empresa', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM empresa ORDER BY id DESC LIMIT 1');
    if (rows.length === 0) return res.json(null);
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ error: 'Error al consultar datos de empresa' });
  }
});

// POST /api/empresa - Guardar / Actualizar perfil y preferencias en MySQL
app.post('/api/empresa', async (req, res) => {
  try {
    const nombre = sanitizeString(req.body.nombre, 255);
    const identificacion = formatIdentificacion(req.body.identificacion);
    const direccion = sanitizeString(req.body.direccion, 1000);
    const telefono = formatPhone(req.body.telefono);
    const doc_titulo = sanitizeString(req.body.doc_titulo, 255);
    const moneda = sanitizeString(req.body.moneda, 20);
    const tasa_cambio = sanitizeFloat(req.body.tasa_cambio, 798.33);
    const mostrar_doble_moneda = req.body.mostrar_doble_moneda ? 1 : 0;
    const logo_base64 = req.body.logo_base64 || null;
    const logo_size = sanitizeInt(req.body.logo_size, 220, 50, 600);
    const show_qr = req.body.show_qr ? 1 : 0;
    const show_barcode = req.body.show_barcode ? 1 : 0;
    const show_signature = req.body.show_signature ? 1 : 0;
    const show_tax_table = req.body.show_tax_table ? 1 : 0;
    const theme = sanitizeString(req.body.theme, 50) || 'theme-thermal';
    const notas_pie = sanitizeString(req.body.notas_pie, 2000);

    const [rows] = await pool.query('SELECT id FROM empresa LIMIT 1');
    if (rows.length > 0) {
      const id = rows[0].id;
      await pool.query(
        `UPDATE empresa SET 
          nombre=?, identificacion=?, direccion=?, telefono=?, doc_titulo=?, moneda=?, 
          tasa_cambio=?, mostrar_doble_moneda=?, logo_base64=?, logo_size=?, show_qr=?, 
          show_barcode=?, show_signature=?, show_tax_table=?, theme=?, notas_pie=? 
         WHERE id=?`,
        [
          nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, 
          mostrar_doble_moneda, logo_base64, logo_size, show_qr, show_barcode, 
          show_signature, show_tax_table, theme, notas_pie, id
        ]
      );
      res.json({ message: 'Perfil y preferencias actualizados de forma segura' });
    } else {
      await pool.query(
        `INSERT INTO empresa (
          nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, 
          mostrar_doble_moneda, logo_base64, logo_size, show_qr, show_barcode, 
          show_signature, show_tax_table, theme, notas_pie
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, 
          mostrar_doble_moneda, logo_base64, logo_size, show_qr, show_barcode, 
          show_signature, show_tax_table, theme, notas_pie
        ]
      );
      res.json({ message: 'Perfil y preferencias registrados de forma segura' });
    }
  } catch (error) {
    res.status(500).json({ error: 'Error al procesar perfil de empresa' });
  }
});

// GET /api/productos - Listar catálogo de productos
app.get('/api/productos', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM productos ORDER BY nombre ASC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: 'Error al consultar productos' });
  }
});

// POST /api/productos - Agregar / Actualizar producto desinfectado en MySQL
app.post('/api/productos', async (req, res) => {
  try {
    const id = req.body.id ? sanitizeInt(req.body.id) : null;
    const codigo = sanitizeString(req.body.codigo, 100).toUpperCase() || `PRD-${Date.now().toString().slice(-4)}`;
    const nombre = sanitizeString(req.body.nombre, 255);
    const precio_usd = sanitizeFloat(req.body.precio_usd, 0);
    const iva_porcentaje = sanitizeFloat(req.body.iva_porcentaje, 0, 0, 100);
    const subtexto = sanitizeString(req.body.subtexto, 255);

    if (!nombre) {
      return res.status(400).json({ error: 'El nombre del producto es obligatorio.' });
    }

    if (id && id > 0) {
      await pool.query(
        `UPDATE productos SET codigo=?, nombre=?, precio_usd=?, iva_porcentaje=?, subtexto=? WHERE id=?`,
        [codigo, nombre, precio_usd, iva_porcentaje, subtexto, id]
      );
      res.json({ message: 'Producto actualizado exitosamente' });
    } else {
      const [result] = await pool.query(
        `INSERT INTO productos (codigo, nombre, precio_usd, iva_porcentaje, subtexto) VALUES (?, ?, ?, ?, ?)`,
        [codigo, nombre, precio_usd, iva_porcentaje, subtexto]
      );
      res.status(201).json({ message: 'Producto creado exitosamente', id: result.insertId });
    }
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar el producto' });
  }
});

// DELETE /api/productos/:id - Eliminar producto por ID parametrizado
app.delete('/api/productos/:id', async (req, res) => {
  try {
    const id = sanitizeInt(req.params.id);
    if (!id || id <= 0) return res.status(400).json({ error: 'ID de producto inválido' });

    await pool.query('DELETE FROM productos WHERE id = ?', [id]);
    res.json({ message: 'Producto eliminado exitosamente' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar el producto' });
  }
});

// GET /api/clientes - Listar directorio de clientes
app.get('/api/clientes', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM clientes ORDER BY nombre ASC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: 'Error al consultar clientes' });
  }
});

// POST /api/clientes - Registrar / Actualizar cliente formateado en MySQL
app.post('/api/clientes', async (req, res) => {
  try {
    const identificacion = formatIdentificacion(req.body.identificacion);
    const nombre = sanitizeString(req.body.nombre, 255);
    const telefono = formatPhone(req.body.telefono);
    const direccion = sanitizeString(req.body.direccion, 500);

    if (!identificacion || !nombre) {
      return res.status(400).json({ error: 'La identificación y el nombre son obligatorios.' });
    }

    const [existing] = await pool.query('SELECT id FROM clientes WHERE identificacion = ?', [identificacion]);
    if (existing.length > 0) {
      await pool.query(
        `UPDATE clientes SET nombre=?, telefono=?, direccion=? WHERE id=?`,
        [nombre, telefono, direccion, existing[0].id]
      );
      res.json({ message: 'Cliente actualizado exitosamente' });
    } else {
      const [result] = await pool.query(
        `INSERT INTO clientes (identificacion, nombre, telefono, direccion) VALUES (?, ?, ?, ?)`,
        [identificacion, nombre, telefono, direccion]
      );
      res.status(201).json({ message: 'Cliente registrado exitosamente', id: result.insertId });
    }
  } catch (error) {
    res.status(500).json({ error: 'Error al guardar cliente' });
  }
});

// GET /api/consultar-cedula/:doc - Consulta segura de Cédula / RIF con consulta preparada
app.get('/api/consultar-cedula/:doc', async (req, res) => {
  const cleanDoc = formatIdentificacion(req.params.doc);

  if (!cleanDoc || cleanDoc.length < 3) {
    return res.status(400).json({ success: false, message: 'Número de cédula o RIF inválido.' });
  }

  let letter = cleanDoc.charAt(0);
  let numStr = cleanDoc;
  if (['V', 'E', 'J', 'G', 'P'].includes(letter)) {
    numStr = cleanDoc.substring(1).replace(/[^0-9]/g, '');
  } else {
    letter = 'V';
    numStr = cleanDoc.replace(/[^0-9]/g, '');
  }

  const formattedCedulaDisplay = `${letter}-${numStr.replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;

  try {
    const [clientRows] = await pool.query(
      `SELECT * FROM clientes WHERE UPPER(REPLACE(REPLACE(identificacion, '-', ''), '.', '')) LIKE ? LIMIT 1`,
      [`%${numStr}%`]
    );

    if (clientRows.length > 0) {
      return res.json({
        success: true,
        nombre: clientRows[0].nombre,
        telefono: clientRows[0].telefono || '',
        direccion: clientRows[0].direccion || '',
        doc: formattedCedulaDisplay,
        fuente: 'Catálogo de Clientes MySQL'
      });
    }

    return res.json({
      success: false,
      message: 'Cédula / RIF no registrado en directorio.'
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: 'Error en la consulta' });
  }
});

// GET /api/comprobantes - Listar historial de comprobantes
app.get('/api/comprobantes', async (req, res) => {
  try {
    const [comprobantes] = await pool.query('SELECT * FROM comprobantes ORDER BY id DESC');
    const [items] = await pool.query('SELECT * FROM comprobante_items');

    const result = comprobantes.map(c => {
      const cItems = items.filter(i => i.comprobante_id === c.id).map(i => ({
        id: i.id.toString(),
        cant: i.cantidad,
        desc: i.descripcion,
        subtext: i.subtexto,
        taxRate: i.tarifa_iva,
        unitPrice: i.precio_unitario
      }));

      return {
        uuid: c.uuid,
        doc_type: c.doc_type,
        doc_title: c.doc_title,
        doc_number: c.doc_number,
        doc_date: c.doc_date,
        doc_time: c.doc_time,
        cliente_nombre: c.cliente_nombre,
        cliente_identificacion: c.cliente_identificacion,
        cliente_telefono: c.cliente_telefono,
        cliente_direccion: c.cliente_direccion,
        forma_pago: c.forma_pago,
        vendedor: c.vendedor,
        concepto: c.concepto,
        referencia: c.referencia,
        saldo_anterior: c.saldo_anterior,
        nuevo_saldo: c.nuevo_saldo,
        subtotal: c.subtotal,
        impuesto_porcentaje: c.impuesto_porcentaje,
        impuesto_monto: c.impuesto_monto,
        descuento: c.descuento,
        total_principal: c.total_principal,
        total_bs_bcv: c.total_bs_bcv,
        moneda: c.moneda,
        tasa_ref: c.tasa_ref,
        target_currency: c.target_currency,
        suiche_bank: c.suiche_bank,
        suiche_doc: c.suiche_doc,
        suiche_phone: c.suiche_phone,
        items: cItems
      };
    });

    res.json(result);
  } catch (error) {
    res.status(500).json({ error: 'Error al consultar historial de comprobantes' });
  }
});

// POST /api/comprobantes - Registrar nuevo comprobante con desinfección total en MySQL
app.post('/api/comprobantes', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const uuid = sanitizeString(req.body.uuid, 100) || Date.now().toString();
    const doc_type = ['venta', 'ingreso', 'egreso'].includes(req.body.doc_type) ? req.body.doc_type : 'venta';
    const doc_title = sanitizeString(req.body.doc_title, 255);
    const doc_number = sanitizeString(req.body.doc_number, 100);
    const doc_date = sanitizeString(req.body.doc_date, 20);
    const doc_time = sanitizeString(req.body.doc_time, 20);

    const cliente_nombre = sanitizeString(req.body.cliente_nombre, 255) || 'Cliente Mostrador';
    const cliente_identificacion = formatIdentificacion(req.body.cliente_identificacion);
    const cliente_telefono = formatPhone(req.body.cliente_telefono);
    const cliente_direccion = sanitizeString(req.body.cliente_direccion, 500);

    const forma_pago = sanitizeString(req.body.forma_pago, 100);
    const vendedor = sanitizeString(req.body.vendedor, 100);
    const concepto = sanitizeString(req.body.concepto, 1000);
    const referencia = sanitizeString(req.body.referencia, 100);

    const saldo_anterior = sanitizeFloat(req.body.saldo_anterior);
    const nuevo_saldo = sanitizeFloat(req.body.nuevo_saldo);
    const subtotal = sanitizeFloat(req.body.subtotal);
    const impuesto_porcentaje = sanitizeFloat(req.body.impuesto_porcentaje);
    const impuesto_monto = sanitizeFloat(req.body.impuesto_monto);
    const descuento = sanitizeFloat(req.body.descuento);
    const total_principal = sanitizeFloat(req.body.total_principal);
    const total_bs_bcv = sanitizeFloat(req.body.total_bs_bcv);

    const moneda = sanitizeString(req.body.moneda, 20) || '$';
    const tasa_ref = sanitizeFloat(req.body.tasa_ref, 1);
    const target_currency = sanitizeString(req.body.target_currency, 10) || 'USD';
    const suiche_bank = sanitizeString(req.body.suiche_bank, 20);
    const suiche_doc = formatIdentificacion(req.body.suiche_doc);
    const suiche_phone = formatPhone(req.body.suiche_phone);

    const [result] = await connection.query(
      `INSERT INTO comprobantes (
        uuid, doc_type, doc_title, doc_number, doc_date, doc_time,
        cliente_nombre, cliente_identificacion, cliente_telefono, cliente_direccion,
        forma_pago, vendedor, concepto, referencia, saldo_anterior, nuevo_saldo,
        subtotal, impuesto_porcentaje, impuesto_monto, descuento, total_principal,
        moneda, tasa_ref, target_currency, suiche_bank, suiche_doc, suiche_phone,
        total_bs_bcv
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        uuid, doc_type, doc_title, doc_number, doc_date, doc_time,
        cliente_nombre, cliente_identificacion, cliente_telefono, cliente_direccion,
        forma_pago, vendedor, concepto, referencia, saldo_anterior, nuevo_saldo,
        subtotal, impuesto_porcentaje, impuesto_monto, descuento, total_principal,
        moneda, tasa_ref, target_currency, suiche_bank, suiche_doc, suiche_phone,
        total_bs_bcv
      ]
    );

    const comprobanteId = result.insertId;

    if (Array.isArray(req.body.items) && req.body.items.length > 0) {
      for (const item of req.body.items) {
        const cantidad = sanitizeInt(item.cant, 1);
        const descripcion = sanitizeString(item.desc, 255);
        const subtexto = sanitizeString(item.subtext, 255);
        const tarifa_iva = sanitizeFloat(item.taxRate, 0);
        const precio_unitario = sanitizeFloat(item.unitPrice, 0);
        const subtotal_linea = cantidad * precio_unitario;

        await connection.query(
          `INSERT INTO comprobante_items (comprobante_id, cantidad, descripcion, subtexto, tarifa_iva, precio_unitario, subtotal_linea) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [comprobanteId, cantidad, descripcion, subtexto, tarifa_iva, precio_unitario, subtotal_linea]
        );
      }
    }

    if (cliente_identificacion && cliente_nombre && cliente_nombre.trim() !== '') {
      await connection.query(
        `INSERT INTO clientes (identificacion, nombre, telefono, direccion) 
         VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE nombre=?, telefono=?, direccion=?`,
        [cliente_identificacion, cliente_nombre, cliente_telefono, cliente_direccion, cliente_nombre, cliente_telefono, cliente_direccion]
      ).catch(() => {});
    }

    await connection.commit();
    res.status(201).json({ message: 'Comprobante registrado con éxito y seguridad', id: comprobanteId, uuid });

  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: 'Error al registrar comprobante' });
  } finally {
    connection.release();
  }
});

// DELETE /api/comprobantes/:uuid - Eliminar comprobante por UUID
app.delete('/api/comprobantes/:uuid', async (req, res) => {
  try {
    const uuid = sanitizeString(req.params.uuid, 100);
    if (!uuid) return res.status(400).json({ error: 'UUID de comprobante inválido' });

    await pool.query('DELETE FROM comprobantes WHERE uuid = ?', [uuid]);
    res.json({ message: 'Comprobante eliminado exitosamente' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar comprobante' });
  }
});

// DELETE /api/admin/clear-db - Vaciar base de datos de forma segura
app.delete('/api/admin/clear-db', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.query('SET FOREIGN_KEY_CHECKS = 0;');
    await connection.query('TRUNCATE TABLE comprobante_items;');
    await connection.query('TRUNCATE TABLE comprobantes;');
    await connection.query('TRUNCATE TABLE clientes;');
    await connection.query('TRUNCATE TABLE productos;');
    await connection.query('TRUNCATE TABLE empresa;');
    await connection.query('SET FOREIGN_KEY_CHECKS = 1;');

    res.json({ message: 'Base de datos MARTK vaciada de forma segura.' });
  } catch (error) {
    res.status(500).json({ error: 'Error al limpiar la base de datos' });
  } finally {
    connection.release();
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Servidor MARTK seguro corriendo en http://localhost:${PORT}`);
});
