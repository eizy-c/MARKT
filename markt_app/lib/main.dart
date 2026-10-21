import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF8F9FF),
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF8F9FF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MarktApp());
}

class MarktApp extends StatelessWidget {
  const MarktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MARTK POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FF),
      ),
      home: const MarktWebViewScreen(),
    );
  }
}

class MarktWebViewScreen extends StatefulWidget {
  const MarktWebViewScreen({super.key});

  @override
  State<MarktWebViewScreen> createState() => _MarktWebViewScreenState();
}

class _MarktWebViewScreenState extends State<MarktWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  Future<Directory> _getDataDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dataDir = Directory('${appDir.path}/markt_data');
    if (!await dataDir.exists()) {
      await dataDir.create(recursive: true);
    }
    return dataDir;
  }

  Future<void> _handleStorageMessage(JavaScriptMessage message) async {
    try {
      final payload = jsonDecode(message.message) as Map<String, dynamic>;
      final action = payload['action'] as String?;
      final key = payload['key'] as String?;
      final requestId = payload['requestId'] as String?;
      final dataDir = await _getDataDirectory();

      if (action == 'save' && key != null) {
        final data = payload['data'];
        final file = File('${dataDir.path}/$key.json');
        await file.writeAsString(jsonEncode(data), flush: true);
        if (requestId != null) {
          _sendResponseToJs(requestId, success: true);
        }
      } else if (action == 'load' && key != null) {
        final file = File('${dataDir.path}/$key.json');
        if (await file.exists()) {
          final content = await file.readAsString();
          final parsed = jsonDecode(content);
          if (requestId != null) {
            _sendResponseToJs(requestId, success: true, data: parsed);
          }
        } else {
          if (requestId != null) {
            _sendResponseToJs(requestId, success: true, data: null);
          }
        }
      } else if (action == 'delete' && key != null) {
        final file = File('${dataDir.path}/$key.json');
        if (await file.exists()) {
          await file.delete();
        }
        if (requestId != null) {
          _sendResponseToJs(requestId, success: true);
        }
      } else if (action == 'export_backup') {
        // Collect all json files into one map
        final Map<String, dynamic> backup = {};
        final files = dataDir.listSync().whereType<File>();
        for (final f in files) {
          if (f.path.endsWith('.json')) {
            final fileName = f.uri.pathSegments.last.replaceAll('.json', '');
            try {
              backup[fileName] = jsonDecode(await f.readAsString());
            } catch (_) {}
          }
        }
        if (requestId != null) {
          _sendResponseToJs(requestId, success: true, data: backup);
        }
      } else if (action == 'import_backup') {
        final backupData = payload['data'] as Map<String, dynamic>?;
        if (backupData != null) {
          for (final entry in backupData.entries) {
            final file = File('${dataDir.path}/${entry.key}.json');
            await file.writeAsString(jsonEncode(entry.value), flush: true);
          }
        }
        if (requestId != null) {
          _sendResponseToJs(requestId, success: true);
        }
      }
    } catch (e) {
      debugPrint('Error en NativeStorage Channel: $e');
    }
  }

  void _sendResponseToJs(String requestId, {required bool success, dynamic data}) {
    final responseJson = jsonEncode({
      'requestId': requestId,
      'success': success,
      'data': data,
    });
    // Sanitize for JS invocation
    final encoded = jsonEncode(responseJson);
    _controller.runJavaScript('window.MarktNativeStorage && window.MarktNativeStorage._onNativeResponse($encoded);');
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8F9FF))
      ..addJavaScriptChannel(
        'MarktNativeStorageChannel',
        onMessageReceived: _handleStorageMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Web Resource Error: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.startsWith('https://api.whatsapp.com') ||
                url.startsWith('https://wa.me') ||
                url.startsWith('whatsapp:') ||
                url.startsWith('https://calendar.google.com') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:')) {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadFlutterAsset('assets/web/index.html');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          if (context.mounted) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FF),
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
