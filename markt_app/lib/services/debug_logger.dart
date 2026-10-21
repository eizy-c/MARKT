import 'dart:collection';
import 'package:flutter/foundation.dart';

class DebugLog {
  final DateTime timestamp;
  final String level; // 'error', 'warn', 'info'
  final String message;
  final String? stackTrace;

  DebugLog({
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
  });
}

class DebugLogger {
  static final DebugLogger instance = DebugLogger._internal();
  DebugLogger._internal();

  final List<DebugLog> _logs = [];
  final ValueNotifier<int> errorCount = ValueNotifier<int>(0);
  final ValueNotifier<List<DebugLog>> logsNotifier = ValueNotifier<List<DebugLog>>([]);

  UnmodifiableListView<DebugLog> get logs => UnmodifiableListView(_logs);

  void log(String level, String message, [String? stackTrace]) {
    final entry = DebugLog(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      stackTrace: stackTrace,
    );
    _logs.insert(0, entry);
    if (_logs.length > 200) _logs.removeLast();

    if (level == 'error') {
      errorCount.value++;
    }
    logsNotifier.value = List.unmodifiable(_logs);
    debugPrint('[$level] $message');
  }

  void info(String message) => log('info', message);
  void warn(String message) => log('warn', message);
  void error(String message, [dynamic stack]) => log('error', message, stack?.toString());

  void clear() {
    _logs.clear();
    errorCount.value = 0;
    logsNotifier.value = [];
  }
}
