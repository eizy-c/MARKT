import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/debug_logger.dart';
import 'services/bcv_service.dart';
import 'services/theme_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/cash_screen.dart';
import 'screens/receivables_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/products_screen.dart';
import 'screens/clients_screen.dart';
import 'screens/settings_screen.dart';
import 'models/app_models.dart';
import 'services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/app_drawer.dart';
import 'widgets/floating_debug_button.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // Capturar errores de Flutter Framework
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      DebugLogger.instance.error(
        details.exceptionAsString(),
        details.stack,
      );
    };

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF020617),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    ThemeService.instance.init();

    runApp(const MarktApp());
  }, (error, stack) {
    // Capturar cualquier error no capturado en la zona
    DebugLogger.instance.error('Error no capturado en app: $error', stack);
  });
}

class MarktApp extends StatelessWidget {
  const MarktApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'MARTK POS',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          // Tema Claro (Light)
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF10B981),
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 0,
              scrolledUnderElevation: 0.5,
              titleTextStyle: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              iconTheme: IconThemeData(color: Color(0xFF0F172A)),
            ),
          ),
          // Tema Oscuro (Dark AMOLED)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF020617),
            cardColor: const Color(0xFF0F172A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              secondary: Color(0xFF10B981),
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF020617),
              foregroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              iconTheme: IconThemeData(color: Colors.white),
            ),
          ),
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    'Panel Principal',
    'Terminal POS (Ventas)',
    'Libro de Caja',
    'Cuentas por Cobrar',
    'Analítica Financiera',
    'Proyectos & Pedidos',
    'Inventario',
    'Clientes',
    'Configuración',
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigate: _onDestinationSelected),
      const PosScreen(),
      const CashScreen(),
      const ReceivablesScreen(),
      const AnalyticsScreen(),
      const ProjectsScreen(),
      const ProductsScreen(),
      const ClientsScreen(),
      const SettingsScreen(),
    ];
    DebugLogger.instance.info('MARTK POS nativo en Flutter iniciado con éxito.');
    BcvService.instance.init();
  }

  void _onDestinationSelected(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() {
        _currentIndex = index;
      });
      DebugLogger.instance.info('Navegando a: ${_titles[index]}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 16,
            right: 16,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
          ),
          child: Row(
            children: [
              // Botón Menú Lateral Cuadrado Redondeado
              Builder(
                builder: (ctx) => InkWell(
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(Icons.menu, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Logo Ícono Negro Redondeado
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.precision_manufacturing_outlined, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 10),

              // Título con punto verde
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'MARKT',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _titles[_currentIndex],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              // Pill Tasa BCV
              ValueListenableBuilder<BcvRates>(
                valueListenable: BcvService.instance.ratesNotifier,
                builder: (context, rates, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: BcvService.instance.isLoading,
                    builder: (context, loading, _) {
                      return InkWell(
                        onTap: loading ? null : () => BcvService.instance.fetchRates(),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'BCV: ${rates.usd.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (loading)
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2563EB)),
                                )
                              else
                                const Icon(Icons.refresh, size: 13, color: Color(0xFF2563EB)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 8),

              // Botón Cobranzas / Recordar Deuda (WhatsApp)
              InkWell(
                onTap: () => _onDestinationSelected(3), // Ir a Cuentas por Cobrar
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.mark_chat_unread_outlined, color: Color(0xFF10B981), size: 20),
                ),
              ),
              const SizedBox(width: 8),

              // Botón Notificaciones del Sistema
              InkWell(
                onTap: _showNotificationsCenterModal,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.notifications_outlined, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: AppDrawer(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: const FloatingDebugButton(),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF020617) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(icon: Icons.grid_view, label: 'Inicio', index: 0, isDark: isDark),
            _buildNavItem(icon: Icons.account_balance_wallet_outlined, label: 'Caja', index: 2, isDark: isDark),
            // Botón Central Redondo Negro "+" (POS / Venta)
            InkWell(
              onTap: () => _onDestinationSelected(1), // POS
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF6366F1) : Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 26),
              ),
            ),
            _buildNavItem(icon: Icons.assignment_late_outlined, label: 'Por Cobrar', index: 3, isDark: isDark),
            _buildNavItem(icon: Icons.store_mall_directory_outlined, label: 'Comercio', index: 8, isDark: isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
    bool isDrawerTrigger = false,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF64748B) : const Color(0xFF64748B));

    return Builder(
      builder: (ctx) => InkWell(
        onTap: () {
          if (isDrawerTrigger) {
            Scaffold.of(ctx).openDrawer();
          } else {
            _onDestinationSelected(index);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsCenterModal() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Cargar datos en vivo para generar alertas inteligentes
    List<ReceivableAccount> pendingDebts = [];
    List<ProjectItem> waitingProjects = [];
    List<ProjectItem> readyProjects = [];
    List<ProjectItem> pendingDownPaymentProjects = [];

    try {
      final rawRec = await StorageService.instance.load('receivables');
      if (rawRec != null && rawRec is List) {
        for (final item in rawRec) {
          final acc = ReceivableAccount.fromJson(Map<String, dynamic>.from(item));
          if (!acc.isPaid) pendingDebts.add(acc);
        }
      }

      final rawProj = await StorageService.instance.load('proyectos');
      if (rawProj != null && rawProj is List) {
        for (final item in rawProj) {
          final p = ProjectItem.fromJson(Map<String, dynamic>.from(item));
          if (p.status == '1_aprobacion') {
            waitingProjects.add(p);
          } else if (p.status == '2_anticipo') {
            pendingDownPaymentProjects.add(p);
          } else if (p.status == '5_finalizado' || p.status == 'completed') {
            readyProjects.add(p);
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active, color: Color(0xFFEF4444), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Centro de Notificaciones & Alertas',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Recordatorios de proyectos, iniciales y deudas',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: [
                  // 1. Deudas Pendientes de Clientes
                  if (pendingDebts.isNotEmpty) ...[
                    _buildNotificationHeader(
                      title: 'Deudas Pendientes de Cobro (${pendingDebts.length})',
                      color: const Color(0xFFEF4444),
                      icon: Icons.money_off,
                    ),
                    const SizedBox(height: 8),
                    ...pendingDebts.map((acc) => _buildDebtNotificationCard(acc, isDark)),
                    const SizedBox(height: 16),
                  ],

                  // 2. Clientes que deben dar Inicial / Anticipo
                  if (pendingDownPaymentProjects.isNotEmpty) ...[
                    _buildNotificationHeader(
                      title: 'Pendiente Pago de Inicial / Anticipo (${pendingDownPaymentProjects.length})',
                      color: const Color(0xFFF59E0B),
                      icon: Icons.pending_actions,
                    ),
                    const SizedBox(height: 8),
                    ...pendingDownPaymentProjects.map((p) => _buildProjectAlertCard(
                          title: p.title,
                          client: p.clientName,
                          amount: p.totalUsd,
                          alertText: 'Requiere cobro de inicial para iniciar producción en taller',
                          actionLabel: 'Cobrar Inicial',
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                          onAction: () {
                            Navigator.pop(ctx);
                            _onDestinationSelected(5); // Proyectos
                          },
                        )),
                    const SizedBox(height: 16),
                  ],

                  // 3. Proyectos en Espera de Aprobación
                  if (waitingProjects.isNotEmpty) ...[
                    _buildNotificationHeader(
                      title: 'Proyectos en Espera de Aprobación (${waitingProjects.length})',
                      color: const Color(0xFF38BDF8),
                      icon: Icons.hourglass_top,
                    ),
                    const SizedBox(height: 8),
                    ...waitingProjects.map((p) => _buildProjectAlertCard(
                          title: p.title,
                          client: p.clientName,
                          amount: p.totalUsd,
                          alertText: 'Cotización emitida en espera de confirmación del cliente',
                          actionLabel: 'Ver Proyecto',
                          color: const Color(0xFF38BDF8),
                          isDark: isDark,
                          onAction: () {
                            Navigator.pop(ctx);
                            _onDestinationSelected(5);
                          },
                        )),
                    const SizedBox(height: 16),
                  ],

                  // 4. Proyectos Listos sin Entregar
                  if (readyProjects.isNotEmpty) ...[
                    _buildNotificationHeader(
                      title: 'Proyectos Listos sin Entregar (${readyProjects.length})',
                      color: const Color(0xFF10B981),
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(height: 8),
                    ...readyProjects.map((p) => _buildProjectAlertCard(
                          title: p.title,
                          client: p.clientName,
                          amount: p.totalUsd,
                          alertText: 'Fabricación finalizada. Listo para retiro o instalación',
                          actionLabel: 'Notificar Entrega',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                          onAction: () {
                            Navigator.pop(ctx);
                            _onDestinationSelected(5);
                          },
                        )),
                    const SizedBox(height: 16),
                  ],

                  if (pendingDebts.isEmpty &&
                      pendingDownPaymentProjects.isEmpty &&
                      waitingProjects.isEmpty &&
                      readyProjects.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            const Icon(Icons.done_all, color: Color(0xFF10B981), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              '¡Todo al día!',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No hay deudas vencidas ni proyectos desatendidos.',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationHeader({required String title, required Color color, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildDebtNotificationCard(ReceivableAccount acc, bool isDark) {
    final rate = BcvService.instance.currentRates.usd;
    final totalBs = acc.remainingBalanceUsd * rate;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                acc.clientName,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                'Debe: \$${acc.remainingBalanceUsd.toStringAsFixed(2)} (~Bs. ${totalBs.toStringAsFixed(2)})',
                style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Concepto: ${acc.concept}',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final text = 'Hola estimado/a ${acc.clientName}, le saludamos cordialmente. '
                      'Le recordamos amablemente su saldo pendiente de *\$${acc.remainingBalanceUsd.toStringAsFixed(2)}* '
                      '(Bs. ${totalBs.toStringAsFixed(2)}) correspondiente a: "${acc.concept}". '
                      'Agradecemos su atención. ¡Feliz día!';
                  String cleanPhone = acc.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
                  if (cleanPhone.startsWith('0')) cleanPhone = '58${cleanPhone.substring(1)}';
                  final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}');
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    Clipboard.setData(ClipboardData(text: text));
                  }
                },
                icon: const Icon(Icons.chat, size: 14, color: Color(0xFF10B981)),
                label: const Text('Cobrar por WhatsApp', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectAlertCard({
    required String title,
    required String client,
    required double amount,
    required String alertText,
    required String actionLabel,
    required Color color,
    required bool isDark,
    required VoidCallback onAction,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Cliente: $client',
            style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            alertText,
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward, size: 14),
              label: Text(actionLabel, style: const TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
