import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/debug_logger.dart';

class DebugConsoleModal extends StatelessWidget {
  const DebugConsoleModal({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = DebugLogger.instance;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF1E293B), width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.terminal, color: Color(0xFFF59E0B), size: 18),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Consola de Diagnóstico',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          final logs = logger.logs;
                          final text = logs.map((l) => '[${l.timestamp.toIso8601String()}] [${l.level.toUpperCase()}] ${l.message} ${l.stackTrace ?? ''}').join('\n');
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Logs copiados al portapapeles'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text('Copiar', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                      ),
                      IconButton(
                        onPressed: () => logger.clear(),
                        icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 18),
                        tooltip: 'Limpiar logs',
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 16),

              // Logs List
              Expanded(
                child: ValueListenableBuilder<List<DebugLog>>(
                  valueListenable: logger.logsNotifier,
                  builder: (context, logs, _) {
                    if (logs.isEmpty) {
                      return const Center(
                        child: Text(
                          'Sin errores detectados. Sistema operando con normalidad.',
                          style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 13),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final isError = log.level == 'error';
                        final isWarn = log.level == 'warn';

                        final bgColor = isError
                            ? const Color(0xFF450A0A).withValues(alpha: 0.5)
                            : isWarn
                                ? const Color(0xFF451A03).withValues(alpha: 0.5)
                                : const Color(0xFF0B132B).withValues(alpha: 0.7);

                        final textColor = isError
                            ? const Color(0xFFF87171)
                            : isWarn
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFF94A3B8);

                        final icon = isError
                            ? Icons.error_outline
                            : isWarn
                                ? Icons.warning_amber_rounded
                                : Icons.info_outline;

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isError
                                  ? const Color(0xFF7F1D1D)
                                  : isWarn
                                      ? const Color(0xFF78350F)
                                      : const Color(0xFF1E293B),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(icon, size: 14, color: textColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        log.level.toUpperCase(),
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                log.message,
                                style: TextStyle(color: textColor, fontSize: 12, fontFamily: 'monospace'),
                              ),
                              if (log.stackTrace != null && log.stackTrace!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    log.stackTrace!,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
