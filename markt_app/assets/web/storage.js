// ==========================================================================
// MARKT NATIVE STORAGE ENGINE (Puente a Memoria Física del Teléfono)
// ==========================================================================

const MarktNativeStorage = {
  _callbacks: {},
  _isNativeAvailable: null,

  isNative() {
    if (this._isNativeAvailable !== null) return this._isNativeAvailable;
    this._isNativeAvailable = typeof window.MarktNativeStorageChannel !== 'undefined';
    return this._isNativeAvailable;
  },

  _callNative(action, key, data = null) {
    return new Promise((resolve) => {
      if (!this.isNative()) {
        resolve(null);
        return;
      }
      const requestId = 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 6);
      this._callbacks[requestId] = resolve;

      try {
        window.MarktNativeStorageChannel.postMessage(JSON.stringify({
          action,
          key,
          data,
          requestId
        }));
      } catch (err) {
        console.warn('Error al enviar mensaje a Flutter NativeStorage:', err);
        delete this._callbacks[requestId];
        resolve(null);
      }
    });
  },

  _onNativeResponse(rawJson) {
    try {
      const parsed = typeof rawJson === 'string' ? JSON.parse(rawJson) : rawJson;
      const { requestId, success, data } = parsed;
      if (this._callbacks[requestId]) {
        this._callbacks[requestId](success ? data : null);
        delete this._callbacks[requestId];
      }
    } catch (e) {
      console.warn('Error al procesar respuesta nativa:', e);
    }
  },

  async setItem(key, val) {
    if (this.isNative()) {
      await this._callNative('save', key, val);
    }
    // Mantener sincronizado localStorage como fallback
    try {
      localStorage.setItem(key, typeof val === 'string' ? val : JSON.stringify(val));
    } catch (_) {}
  },

  async getItem(key) {
    if (this.isNative()) {
      const nativeVal = await this._callNative('load', key);
      if (nativeVal !== null && nativeVal !== undefined) {
        return typeof nativeVal === 'string' ? nativeVal : JSON.stringify(nativeVal);
      }
    }
    try {
      return localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  },

  async removeItem(key) {
    if (this.isNative()) {
      await this._callNative('delete', key);
    }
    try {
      localStorage.removeItem(key);
    } catch (_) {}
  },

  async exportFullBackup() {
    if (this.isNative()) {
      const backup = await this._callNative('export_backup', 'all');
      if (backup) return backup;
    }
    // Fallback localStorage
    const full = {};
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      try {
        full[k] = JSON.parse(localStorage.getItem(k));
      } catch (_) {
        full[k] = localStorage.getItem(k);
      }
    }
    return full;
  },

  async importFullBackup(backupData) {
    if (this.isNative()) {
      await this._callNative('import_backup', 'all', backupData);
    }
    if (backupData && typeof backupData === 'object') {
      Object.keys(backupData).forEach(k => {
        try {
          localStorage.setItem(k, typeof backupData[k] === 'string' ? backupData[k] : JSON.stringify(backupData[k]));
        } catch (_) {}
      });
    }
  }
};

window.MarktNativeStorage = MarktNativeStorage;
