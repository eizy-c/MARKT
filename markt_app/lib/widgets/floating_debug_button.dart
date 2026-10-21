import 'package:flutter/material.dart';
import '../services/debug_logger.dart';
import 'debug_console_modal.dart';

class FloatingDebugButton extends StatelessWidget {
  const FloatingDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = DebugLogger.instance;

    return ValueListenableBuilder<int>(
      valueListenable: logger.errorCount,
      builder: (context, errorCount, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            FloatingActionButton.small(
              heroTag: 'debug_fab_btn',
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF334155), width: 1.2),
              ),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SizedBox(
                    height: MediaQuery.of(context).size.height * 0.75,
                    child: const DebugConsoleModal(),
                  ),
                );
              },
              child: const Icon(Icons.bug_report, size: 20, color: Color(0xFF38BDF8)),
            ),
            if (errorCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    errorCount > 99 ? '99+' : errorCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
