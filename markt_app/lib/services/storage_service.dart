import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'debug_logger.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  /// Notificador reactivo global para sincronización en tiempo real entre pantallas.
  final ValueNotifier<int> dataUpdateNotifier = ValueNotifier<int>(0);

  void notifyDataChanged() {
    dataUpdateNotifier.value++;
  }

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
      notifyDataChanged();
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
        notifyDataChanged();
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
      notifyDataChanged();
      return true;
    } catch (e, stack) {
      DebugLogger.instance.error('Error importando backup: $e', stack);
      return false;
    }
  }

  Future<bool> hasAnyData() async {
    try {
      final dir = await _getDirectory();
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
        for (final f in files) {
          final content = await f.readAsString();
          if (content.trim().length > 4 && content.trim() != '[]' && content.trim() != '{}') {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  Future<File?> saveProjectPhoto(String originalFilePath) async {
    try {
      final dir = await _getDirectory();
      final photosDir = Directory('${dir.path}/project_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final ext = originalFilePath.split('.').last;
      final newName = 'photo_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000)}.$ext';
      final targetFile = File('${photosDir.path}/$newName');
      final original = File(originalFilePath);
      if (await original.exists()) {
        return await original.copy(targetFile.path);
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error guardando foto de proyecto: $e', stack);
    }
    return null;
  }

  Future<bool> clearAllData() async {
    try {
      final dir = await _getDirectory();
      if (await dir.exists()) {
        final entities = dir.listSync(recursive: true);
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            }
          } catch (_) {}
        }
      }
      // Limpiar cache temporal
      try {
        final tempDir = await getTemporaryDirectory();
        if (await tempDir.exists()) {
          final tempFiles = tempDir.listSync(recursive: true).whereType<File>();
          for (final tf in tempFiles) {
            try {
              await tf.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}
      notifyDataChanged();
      return true;
    } catch (e, stack) {
      DebugLogger.instance.error('Error limpiando datos: $e', stack);
      return false;
    }
  }
}
