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

    const [itemCols] = await conn.query('SHOW COLUMNS FROM comprobante_items');
    const itemColNames = itemCols.map(c => c.Field);
    if (!itemColNames.includes('tarifa_iva')) await conn.query('ALTER TABLE comprobante_items ADD COLUMN tarifa_iva DECIMAL(5,2) DEFAULT 0.00');
    if (!itemColNames.includes('subtotal_linea')) await conn.query('ALTER TABLE comprobante_items ADD COLUMN subtotal_linea DECIMAL(12,2) DEFAULT 0.00');

    conn.release();
    console.log('✅ Esquema MySQL markt_db auto-migrado y sincronizado.');
  } catch (err) {
    console.error('⚠️ Error durante auto-migración MySQL:', err.message);
  }
}

autoMigrateSchema();

// Health Check
app.get('/api/health', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT 1 + 1 AS result');
    res.json({ status: 'OK', message: 'Servidor MARTK en línea y conectado a MySQL', db: rows[0].result === 2 });
  } catch (error) {
    res.status(500).json({ status: 'ERROR', message: error.message });
  }
});

// GET /api/empresa - Obtener perfil de la empresa y preferencias desde MySQL
app.get('/api/empresa', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM empresa ORDER BY id DESC LIMIT 1');
    if (rows.length === 0) return res.json(null);
    res.json(rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/empresa - Guardar / Actualizar perfil de empresa y preferencias en MySQL
app.post('/api/empresa', async (req, res) => {
  try {
    const { 
      nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, 
      mostrar_doble_moneda, logo_base64, logo_size, show_qr, show_barcode, 
      show_signature, show_tax_table, theme, notas_pie 
    } = req.body;
    
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
          mostrar_doble_moneda ? 1 : 0, logo_base64, logo_size || 220, show_qr ? 1 : 0, 
          show_barcode ? 1 : 0, show_signature ? 1 : 0, show_tax_table ? 1 : 0, 
          theme || 'theme-thermal', notas_pie, id
        ]
      );
      res.json({ message: 'Perfil y preferencias de empresa actualizados en MySQL' });
    } else {
      await pool.query(
        `INSERT INTO empresa (
          nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, 
          mostrar_doble_moneda, logo_base64, logo_size, show_qr, show_barcode, 
          show_signature, show_tax_table, theme, notas_pie
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, 
          mostrar_doble_moneda ? 1 : 0, logo_base64, logo_size || 220, show_qr ? 1 : 0, 
          show_barcode ? 1 : 0, show_signature ? 1 : 0, show_tax_table ? 1 : 0, 
          theme || 'theme-thermal', notas_pie
        ]
      );
      res.json({ message: 'Perfil y preferencias de empresa creados en MySQL' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/productos - Listar catálogo de productos desde MySQL
app.get('/api/productos', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM productos ORDER BY nombre ASC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/productos - Agregar / Actualizar producto en MySQL
app.post('/api/productos', async (req, res) => {
  try {
    const { id, codigo, nombre, precio_usd, iva_porcentaje, subtexto } = req.body;
    if (id && !isNaN(id)) {
      await pool.query(
        `UPDATE productos SET codigo=?, nombre=?, precio_usd=?, iva_porcentaje=?, subtexto=? WHERE id=?`,
        [codigo, nombre, precio_usd, iva_porcentaje, subtexto, id]
      );
      res.json({ message: 'Producto actualizado en MySQL' });
    } else {
      const [result] = await pool.query(
        `INSERT INTO productos (codigo, nombre, precio_usd, iva_porcentaje, subtexto) VALUES (?, ?, ?, ?, ?)`,
        [codigo || `PRD-${Date.now()}`, nombre, precio_usd || 0, iva_porcentaje || 16, subtexto || '']
      );
      res.status(201).json({ message: 'Producto creado en MySQL', id: result.insertId });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// DELETE /api/productos/:id - Eliminar producto en MySQL
app.delete('/api/productos/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM productos WHERE id = ?', [req.params.id]);
    res.json({ message: 'Producto eliminado en MySQL' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/clientes - Listar clientes desde MySQL
app.get('/api/clientes', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM clientes ORDER BY nombre ASC');
    res.json(rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/clientes - Registrar / Actualizar cliente en MySQL
app.post('/api/clientes', async (req, res) => {
  try {
    const { identificacion, nombre, telefono, direccion } = req.body;
    const [existing] = await pool.query('SELECT id FROM clientes WHERE identificacion = ?', [identificacion]);
    if (existing.length > 0) {
      await pool.query(
        `UPDATE clientes SET nombre=?, telefono=?, direccion=? WHERE id=?`,
        [nombre, telefono, direccion, existing[0].id]
      );
      res.json({ message: 'Cliente actualizado en MySQL' });
    } else {
      const [result] = await pool.query(
        `INSERT INTO clientes (identificacion, nombre, telefono, direccion) VALUES (?, ?, ?, ?)`,
        [identificacion, nombre, telefono || '', direccion || '']
      );
      res.status(201).json({ message: 'Cliente registrado en MySQL', id: result.insertId });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/consultar-cedula/:doc - Consulta Cédula / RIF en BD Local MySQL
app.get('/api/consultar-cedula/:doc', async (req, res) => {
  const rawDoc = req.params.doc || '';
  const cleanDoc = rawDoc.toUpperCase().replace(/[^A-Z0-9]/g, '');

  if (!cleanDoc || cleanDoc.length < 4) {
    return res.status(400).json({ success: false, message: 'Número de cédula o RIF inválido.' });
  }

  let letter = cleanDoc.charAt(0);
  let numStr = cleanDoc;
  if (['V', 'E', 'J', 'G', 'P'].includes(letter)) {
    numStr = cleanDoc.substring(1);
  } else {
    letter = 'V';
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
      message: 'Cédula / RIF no registrado en directorio MySQL.'
    });
  } catch (error) {
    return res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/comprobantes - Listar historial de comprobantes de MySQL
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
    res.status(500).json({ error: error.message });
  }
});

// POST /api/comprobantes - Guardar nuevo comprobante con ítems en MySQL
app.post('/api/comprobantes', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const {
      uuid, doc_type, doc_title, doc_number, doc_date, doc_time,
      cliente_nombre, cliente_identificacion, cliente_telefono, cliente_direccion,
      forma_pago, vendedor, concepto, referencia, saldo_anterior, nuevo_saldo,
      subtotal, impuesto_porcentaje, impuesto_monto, descuento, total_principal,
      total_bs_bcv, moneda, tasa_ref, target_currency, suiche_bank, suiche_doc, suiche_phone,
      items
    } = req.body;

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
        forma_pago, vendedor, concepto, referencia, saldo_anterior || 0, nuevo_saldo || 0,
        subtotal || 0, impuesto_porcentaje || 0, impuesto_monto || 0, descuento || 0, total_principal,
        moneda, tasa_ref, target_currency, suiche_bank, suiche_doc, suiche_phone,
        total_bs_bcv || 0
      ]
    );

    const comprobanteId = result.insertId;

    if (Array.isArray(items) && items.length > 0) {
      for (const item of items) {
        await connection.query(
          `INSERT INTO comprobante_items (comprobante_id, cantidad, descripcion, subtexto, tarifa_iva, precio_unitario, subtotal_linea) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [comprobanteId, item.cant || 1, item.desc || '', item.subtext || '', item.taxRate || 0, item.unitPrice || 0, (item.cant || 1) * (item.unitPrice || 0)]
        );
      }
    }

    if (cliente_identificacion && cliente_nombre && cliente_nombre.trim() !== '') {
      await connection.query(
        `INSERT INTO clientes (identificacion, nombre, telefono, direccion) 
         VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE nombre=?, telefono=?, direccion=?`,
        [cliente_identificacion, cliente_nombre, cliente_telefono || '', cliente_direccion || '', cliente_nombre, cliente_telefono || '', cliente_direccion || '']
      ).catch(() => {});
    }

    await connection.commit();
    res.status(201).json({ message: 'Comprobante guardado con éxito en MySQL', id: comprobanteId, uuid });

  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

// DELETE /api/comprobantes/:uuid - Eliminar un comprobante de MySQL
app.delete('/api/comprobantes/:uuid', async (req, res) => {
  try {
    const { uuid } = req.params;
    await pool.query('DELETE FROM comprobantes WHERE uuid = ?', [uuid]);
    res.json({ message: 'Comprobante eliminado de MySQL' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/admin/export-db - Exportar volcado de todas las tablas de MySQL
app.get('/api/admin/export-db', async (req, res) => {
  try {
    const [empresa] = await pool.query('SELECT * FROM empresa');
    const [productos] = await pool.query('SELECT * FROM productos');
    const [clientes] = await pool.query('SELECT * FROM clientes');
    const [comprobantes] = await pool.query('SELECT * FROM comprobantes');
    const [items] = await pool.query('SELECT * FROM comprobante_items');

    const dumpData = {
      app: 'MARTK POS',
      database: 'markt_db',
      exportedAt: new Date().toISOString(),
      empresa: empresa[0] || null,
      productos,
      clientes,
      comprobantes,
      comprobante_items: items
    };

    res.json(dumpData);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/admin/import-db - Restaurar volcado en MySQL markt_db
app.post('/api/admin/import-db', async (req, res) => {
  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    const { empresa, productos, clientes } = req.body;

    if (Array.isArray(productos)) {
      for (const p of productos) {
        await connection.query(
          `INSERT INTO productos (codigo, nombre, precio_usd, iva_porcentaje, subtexto) 
           VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE nombre=?, precio_usd=?, iva_porcentaje=?, subtexto=?`,
          [p.codigo, p.nombre, p.precio_usd, p.iva_porcentaje, p.subtexto || '', p.nombre, p.precio_usd, p.iva_porcentaje, p.subtexto || '']
        );
      }
    }

    if (Array.isArray(clientes)) {
      for (const c of clientes) {
        await connection.query(
          `INSERT INTO clientes (identificacion, nombre, telefono, direccion) 
           VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE nombre=?, telefono=?, direccion=?`,
          [c.identificacion, c.nombre, c.telefono || '', c.direccion || '', c.nombre, c.telefono || '', c.direccion || '']
        );
      }
    }

    await connection.commit();
    res.json({ message: 'Respaldo importado y restaurado en MySQL markt_db con éxito.' });
  } catch (error) {
    await connection.rollback();
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

// DELETE /api/admin/clear-db - Vaciar / Limpiar toda la base de datos MySQL
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

    res.json({ message: 'Base de datos MARTK (markt_db) en MySQL vaciada y limpiada exitosamente.' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  } finally {
    connection.release();
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Servidor MARTK corriendo en http://localhost:${PORT}`);
});
