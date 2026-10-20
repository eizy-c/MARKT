const express = require('express');
const cors = require('cors');
const path = require('path');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Servir archivos estáticos del frontend (index.html, styles.css, app.js)
app.use(express.static(__dirname));

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    app: 'MARTK Admin POS Web & Mobile',
    version: '2.1.0',
    mode: 'Standalone (Zero-DB / LocalStorage)',
    timestamp: new Date().toISOString()
  });
});

// Fallback para SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Obtener IP local de la red para acceso directo desde el teléfono móvil
function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const net of interfaces[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  return addresses;
}

app.listen(PORT, '0.0.0.0', () => {
  const localIps = getLocalIpAddresses();
  console.log('\n======================================================');
  console.log('🚀 MARKT POS - Web Standalone & Mobile Edition (v2.1.0)');
  console.log('======================================================');
  console.log(`💻 Acceso en tu PC:        http://localhost:${PORT}`);
  if (localIps.length > 0) {
    localIps.forEach(ip => {
      console.log(`📱 Acceso en tu Teléfono:  http://${ip}:${PORT}`);
    });
    console.log('   (Conecta tu teléfono a la misma red Wi-Fi)');
  }
  console.log('⚡ Modo 100% Autónomo: Sin base de datos MySQL requerida');
  console.log('======================================================\n');
});
