import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'debug_logger.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  Directory? _dataDir;

  Future<Directory> _getDirectory() async {
    if (_dataDir != null) return _dataDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/markt_data');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dataDir = dir;
    return dir;
  }

  Future<void> save(String key, dynamic data) async {
    try {
      final dir = await _getDirectory();
      final file = File('${dir.path}/$key.json');
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e, stack) {
      DebugLogger.instance.error('Error guardando $key: $e', stack);
    }
  }

  Future<dynamic> load(String key) async {
    try {
      final dir = await _getDirectory();
      final file = File('${dir.path}/$key.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content);
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error cargando $key: $e', stack);
    }
    return null;
  }

  Future<void> delete(String key) async {
    try {
      final dir = await _getDirectory();
      final file = File('${dir.path}/$key.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error eliminando $key: $e', stack);
    }
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final Map<String, dynamic> backup = {};
    try {
      final dir = await _getDirectory();
      final files = dir.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.json')) {
          final fileName = f.uri.pathSegments.last.replaceAll('.json', '');
          try {
            backup[fileName] = jsonDecode(await f.readAsString());
          } catch (_) {}
        }
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error exportando backup: $e', stack);
    }
    return backup;
  }

  Future<bool> importBackup(Map<String, dynamic> backupData) async {
    try {
      final dir = await _getDirectory();
      for (final entry in backupData.entries) {
        final file = File('${dir.path}/${entry.key}.json');
        await file.writeAsString(jsonEncode(entry.value), flush: true);
      }
      return true;
    } catch (e, stack) {
      DebugLogger.instance.error('Error importando backup: $e', stack);
      return false;
    }
  }

  Future<bool> clearAllData() async {
    try {
      final dir = await _getDirectory();
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>();
        for (final f in files) {
          if (f.path.endsWith('.json')) {
            await f.delete();
          }
        }
      }
      return true;
    } catch (e, stack) {
      DebugLogger.instance.error('Error limpiando datos: $e', stack);
      return false;
    }
  }
}
