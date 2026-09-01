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

    const [localDb] = await pool.query(
      `SELECT cliente_nombre, cliente_telefono, cliente_direccion FROM comprobantes 
       WHERE UPPER(REPLACE(REPLACE(cliente_identificacion, '-', ''), '.', '')) LIKE ? 
         AND cliente_nombre IS NOT NULL 
         AND UPPER(cliente_nombre) NOT LIKE '%RIF%'
         AND UPPER(cliente_nombre) NOT LIKE '%CEDULA%'
         AND UPPER(cliente_nombre) NOT LIKE '%PASAPORTE%'
         AND UPPER(cliente_nombre) NOT LIKE '%NBSP%'
       ORDER BY id DESC LIMIT 1`,
      [`%${numStr}%`]
    );

    if (localDb.length > 0 && localDb[0].cliente_nombre) {
      let nameStr = localDb[0].cliente_nombre.replace(/&nbsp;/gi, '').trim();
      if (nameStr.length > 2) {
        return res.json({
          success: true,
          nombre: nameStr,
          telefono: localDb[0].cliente_telefono || '',
          direccion: localDb[0].cliente_direccion || '',
          doc: formattedCedulaDisplay,
          fuente: 'Historial MySQL'
        });
      }
    }

    return res.json({
      success: false,
      message: 'Cliente nuevo. Ingresa el nombre para guardarlo en tu directorio MySQL.',
      doc: formattedCedulaDisplay
    });

  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// GET /api/comprobantes - Listar historial de comprobantes desde MySQL
app.get('/api/comprobantes', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM comprobantes ORDER BY id DESC');
    res.json(rows);
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
        total_equivalente_usd
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

    // Guardar cliente automáticamente en la tabla clientes de MySQL
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

    const { empresa, productos, clientes, comprobantes, comprobante_items } = req.body;

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
