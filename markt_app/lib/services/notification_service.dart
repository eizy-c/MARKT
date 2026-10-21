import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_models.dart';
import 'debug_logger.dart';
import 'storage_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Function(String?)? onNotificationTap;

  Future<void> initialize({Function(String?)? onSelectNotification}) async {
    if (onSelectNotification != null) {
      onNotificationTap = onSelectNotification;
    }
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          DebugLogger.instance.info('Notificacion tocada con payload: ${response.payload}');
          if (onNotificationTap != null) {
            onNotificationTap!(response.payload);
          }
        },
      );

      // Solicitar permisos en Android 13+
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      DebugLogger.instance.info('Servicio de notificaciones locales inicializado correctamente.');
    } catch (e, stack) {
      DebugLogger.instance.error('Error al inicializar notificaciones locales: $e', stack);
    }
  }

  // Enviar una notificación inmediata al teléfono
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'markt_alerts_channel',
        'Alertas de Negocio MARKT',
        channelDescription: 'Recordatorios de cobranzas, proyectos en taller y control de inventario',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload,
      );
    } catch (e, stack) {
      DebugLogger.instance.error('Error al mostrar notificacion: $e', stack);
    }
  }

  // Chequeo de alertas comerciales y de taller
  Future<void> runBusinessAlertsCheck() async {
    try {
      // 1. Alerta de Cuentas por Cobrar Vencidas y Pendientes
      final rawRec = await StorageService.instance.load('receivables');
      if (rawRec != null && rawRec is List) {
        final List<ReceivableAccount> receivables = [];
        for (final item in rawRec) {
          receivables.add(ReceivableAccount.fromJson(Map<String, dynamic>.from(item)));
        }

        final overdue = receivables.where((r) => r.isOverdue).toList();
        if (overdue.isNotEmpty) {
          final totalOverdueUsd = overdue.fold(0.0, (acc, r) => acc + r.remainingBalanceUsd);
          await showNotification(
            id: 101,
            title: 'Cuentas por Cobrar Vencidas',
            body: 'Tienes ${overdue.length} deuda(s) vencida(s) por un total de \$${totalOverdueUsd.toStringAsFixed(2)}. Toca para revisar o enviar WhatsApp.',
            payload: 'receivables',
          );
        }
      }

      // 2. Alerta de Proyectos Listos o en Espera de Inicial
      final rawProj = await StorageService.instance.load('proyectos');
      if (rawProj != null && rawProj is List) {
        final List<ProjectItem> projects = [];
        for (final item in rawProj) {
          projects.add(ProjectItem.fromJson(Map<String, dynamic>.from(item)));
        }

        final waitingApprovalOrAdvance = projects.where((p) => p.status == '1_aprobacion' || p.status == '2_anticipo').toList();
        if (waitingApprovalOrAdvance.isNotEmpty) {
          await showNotification(
            id: 102,
            title: 'Proyectos Esperando Anticipo',
            body: '${waitingApprovalOrAdvance.length} proyecto(s) estan esperando confirmacion de inicial para iniciar produccion.',
            payload: 'projects',
          );
        }
      }

      // 3. Alerta de Stock Mínimo Crítico en Inventario
      final rawProd = await StorageService.instance.load('products');
      if (rawProd != null && rawProd is List) {
        final List<Product> products = [];
        for (final item in rawProd) {
          products.add(Product.fromJson(Map<String, dynamic>.from(item)));
        }

        final lowStock = products.where((p) => p.stock <= p.minStock).toList();
        if (lowStock.isNotEmpty) {
          final names = lowStock.take(2).map((p) => p.name).join(', ');
          await showNotification(
            id: 103,
            title: 'Alerta de Inventario Bajo',
            body: '${lowStock.length} articulo(s) en nivel critico de stock: $names${lowStock.length > 2 ? " y otros" : ""}.',
            payload: 'inventory',
          );
        }
      }

      // 4. Presupuestos emitidos por vencer (cotizaciones)
      final rawInvoices = await StorageService.instance.load('invoices');
      if (rawInvoices != null && rawInvoices is List) {
        final List<Invoice> invoices = [];
        for (final item in rawInvoices) {
          invoices.add(Invoice.fromJson(Map<String, dynamic>.from(item)));
        }

        final pendingQuotes = invoices.where((i) => i.voucherType == 'cotizacion' && !i.isInitialPaid).toList();
        final expiringSoon = pendingQuotes.where((i) {
          final diff = i.expirationDate.difference(DateTime.now()).inHours;
          return diff > 0 && diff <= 24;
        }).toList();

        if (expiringSoon.isNotEmpty) {
          await showNotification(
            id: 104,
            title: 'Presupuestos por Vencer',
            body: '${expiringSoon.length} cotizacion(es) venceran en menos de 24 horas sin confirmacion de pago.',
            payload: 'invoices',
          );
        }
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error durante chequeo de alertas: $e', stack);
    }
  }
}
