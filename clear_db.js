const mysql = require('mysql2/promise');

async function clearDatabase() {
  try {
    const connection = await mysql.createConnection({
      host: 'localhost',
      user: 'root',
      password: '',
      database: 'markt_db'
    });

    console.log('🔌 Conectado a MySQL markt_db...');

    await connection.query('SET FOREIGN_KEY_CHECKS = 0;');

    await connection.query('TRUNCATE TABLE comprobante_items;');
    await connection.query('TRUNCATE TABLE comprobantes;');
    await connection.query('TRUNCATE TABLE clientes;');
    await connection.query('TRUNCATE TABLE productos;');
    await connection.query('TRUNCATE TABLE empresa;');

    await connection.query('SET FOREIGN_KEY_CHECKS = 1;');

    console.log('✅ Base de Datos markt_db limpiada exitosamente. Todas las tablas vaciadas.');
    await connection.end();
    process.exit(0);

  } catch (error) {
    console.error('❌ Error al limpiar la BD:', error.message);
    process.exit(1);
  }
}

clearDatabase();
