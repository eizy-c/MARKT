/* ==========================================================================
   MARKT - Script Inteligente de Creación e Inicialización de BD MySQL
   ========================================================================== */

const mysql = require('mysql2/promise');

async function tryConnect(config) {
  try {
    const conn = await mysql.createConnection(config);
    return conn;
  } catch (err) {
    return null;
  }
}

async function createMarktDatabase() {
  console.log('🚀 Conectando al servidor MySQL para crear `markt_db`...');

  // Intentar credenciales comunes en entornos locales (XAMPP, WAMP, Laragon, MySQL Server)
  const credentialsToTry = [
    { host: 'localhost', user: 'root', password: '', port: 3306 },
    { host: '127.0.0.1', user: 'root', password: '', port: 3306 },
    { host: 'localhost', user: 'root', password: 'root', port: 3306 },
    { host: 'localhost', user: 'root', password: '123456', port: 3306 },
    { host: 'localhost', user: 'root', password: 'admin', port: 3306 },
    { host: 'localhost', user: 'root', password: '', port: 3307 }
  ];

  let connection = null;
  let activeConfig = null;

  for (const cred of credentialsToTry) {
    console.log(`📡 Probando conexión en ${cred.host}:${cred.port} (usuario: ${cred.user})...`);
    connection = await tryConnect(cred);
    if (connection) {
      activeConfig = cred;
      break;
    }
  }

  if (!connection) {
    console.log('\n⚠️ [Servidor MySQL No Detectado]');
    console.log('No se pudo conectar a un servidor MySQL en ejecucion en el puerto 3306 o 3307.');
    console.log('Asegúrate de iniciar XAMPP, WampServer, Laragon o el servicio de MySQL.');
    console.log('FacturaExpress continuara funcionando normalmente en modo Auto-guardado LocalStorage/Offline.');
    return;
  }

  console.log(`\n✅ ¡Conectado a MySQL exitosamente en ${activeConfig.host}:${activeConfig.port}!`);

  const dbName = 'markt_db';

  try {
    // 1. Crear Base de Datos
    await connection.query(`CREATE DATABASE IF NOT EXISTS \`${dbName}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;`);
    console.log(`✅ Base de datos '${dbName}' creada / verificada con exito.`);

    await connection.changeUser({ database: dbName });

    // 2. Crear Tablas de MARKT
    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`empresa\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`nombre\` VARCHAR(255) NOT NULL,
        \`identificacion\` VARCHAR(100),
        \`direccion\` TEXT,
        \`telefono\` VARCHAR(100),
        \`doc_titulo\` VARCHAR(150) DEFAULT 'FACTURA ELECTRÓNICA DE VENTA',
        \`moneda\` VARCHAR(10) DEFAULT 'Bs.',
        \`tasa_cambio\` DECIMAL(12,4) DEFAULT 36.5000,
        \`mostrar_doble_moneda\` TINYINT(1) DEFAULT 1,
        \`logo_base64\` LONGTEXT,
        \`notas_pie\` TEXT,
        \`actualizado_en\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    console.log('  ├─ Tabla `empresa` lista.');

    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`clientes\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`nombre\` VARCHAR(255) NOT NULL,
        \`identificacion\` VARCHAR(100),
        \`telefono\` VARCHAR(100),
        \`direccion\` VARCHAR(255),
        \`email\` VARCHAR(150),
        \`creado_en\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    console.log('  ├─ Tabla `clientes` lista.');

    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`productos\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`codigo\` VARCHAR(50),
        \`nombre\` VARCHAR(255) NOT NULL,
        \`precio\` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        \`impuesto_porcentaje\` DECIMAL(5,2) DEFAULT 0.00,
        \`creado_en\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    console.log('  ├─ Tabla `productos` lista.');

    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`comprobantes\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`uuid\` VARCHAR(64) UNIQUE NOT NULL,
        \`doc_type\` ENUM('venta', 'ingreso', 'egreso') DEFAULT 'venta',
        \`doc_title\` VARCHAR(150) NOT NULL,
        \`doc_number\` VARCHAR(100) NOT NULL,
        \`doc_date\` DATE NOT NULL,
        \`doc_time\` VARCHAR(50),
        \`cliente_nombre\` VARCHAR(255) NOT NULL,
        \`cliente_identificacion\` VARCHAR(100),
        \`cliente_telefono\` VARCHAR(100),
        \`cliente_direccion\` VARCHAR(255),
        \`forma_pago\` VARCHAR(100),
        \`vendedor\` VARCHAR(100),
        \`concepto\` TEXT,
        \`referencia\` VARCHAR(150),
        \`saldo_anterior\` DECIMAL(15,2) DEFAULT 0.00,
        \`nuevo_saldo\` DECIMAL(15,2) DEFAULT 0.00,
        \`subtotal\` DECIMAL(15,2) DEFAULT 0.00,
        \`impuesto_porcentaje\` DECIMAL(5,2) DEFAULT 0.00,
        \`impuesto_monto\` DECIMAL(15,2) DEFAULT 0.00,
        \`descuento\` DECIMAL(15,2) DEFAULT 0.00,
        \`total_principal\` DECIMAL(15,2) NOT NULL,
        \`moneda\` VARCHAR(10) DEFAULT 'Bs.',
        \`tasa_ref\` DECIMAL(12,4) DEFAULT 36.5000,
        \`total_equivalente_usd\` DECIMAL(15,2) DEFAULT 0.00,
        \`creado_en\` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    console.log('  ├─ Tabla `comprobantes` lista.');

    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`comprobante_items\` (
        \`id\` INT AUTO_INCREMENT PRIMARY KEY,
        \`comprobante_id\` INT NOT NULL,
        \`cantidad\` DECIMAL(10,2) NOT NULL DEFAULT 1.00,
        \`descripcion\` VARCHAR(255) NOT NULL,
        \`subtexto\` VARCHAR(255),
        \`precio_unitario\` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        \`total_item\` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
        FOREIGN KEY (\`comprobante_id\`) REFERENCES \`comprobantes\`(\`id\`) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    `);
    console.log('  └─ Tabla `comprobante_items` lista.');

    // 3. Insertar perfil por defecto de MARKT
    const [existingBiz] = await connection.query('SELECT id FROM empresa LIMIT 1');
    if (existingBiz.length === 0) {
      await connection.query(`
        INSERT INTO empresa (nombre, identificacion, direccion, telefono, doc_titulo, moneda, tasa_cambio, mostrar_doble_moneda, notas_pie)
        VALUES ('MARKT SERVICIOS', 'RIF: J-901414566-2', 'Av. Principal, Bucaramanga', 'Tels: 0414-1234567', 'FACTURA ELECTRÓNICA DE VENTA', 'Bs.', 36.5000, 1, 'Montos calculados según tasa oficial de referencia BCV.\\n¡Gracias por su compra en MARKT!');
      `);
      console.log('\n🌟 Perfil de la empresa MARKT guardado en la BD.');
    }

    await connection.end();
    console.log('\n🎉 ¡La base de datos `markt_db` ha sido creada e inicializada en MySQL con éxito!');

  } catch (err) {
    console.error('❌ Error ejecutando consultas MySQL:', err.message);
  }
}

createMarktDatabase();
