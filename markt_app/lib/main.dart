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

              // Botón Tienda / POS Azul Claro
              InkWell(
                onTap: () => _onDestinationSelected(1), // Ir al POS
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: Color(0xFF2563EB), size: 20),
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
            _buildNavItem(icon: Icons.menu, label: 'Menú', index: 99, isDark: isDark, isDrawerTrigger: true),
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
}
