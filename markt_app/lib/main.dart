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
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú Principal',
            onPressed: () {
              Scaffold.of(ctx).openDrawer();
            },
          ),
        ),
        actions: [
          // Pill con la Tasa Oficial BCV del Día
          ValueListenableBuilder<BcvRates>(
            valueListenable: BcvService.instance.ratesNotifier,
            builder: (context, rates, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: BcvService.instance.isLoading,
                builder: (context, loading, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: loading ? null : () => BcvService.instance.fetchRates(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: rates.isLive ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFF334155),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (loading)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                              )
                            else
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: rates.isLive ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            const SizedBox(width: 6),
                            Text(
                              'BCV: Bs. ${rates.usd.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Tasa BCV',
            onPressed: () {
              BcvService.instance.fetchRates();
              setState(() {});
              DebugLogger.instance.info('Actualizando datos y tasa BCV.');
            },
          ),
        ],
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
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF6366F1).withValues(alpha: 0.25),
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold);
              }
              return const TextStyle(color: Color(0xFF64748B), fontSize: 11);
            },
          ),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF818CF8), size: 22);
              }
              return const IconThemeData(color: Color(0xFF64748B), size: 22);
            },
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex > 3 ? 0 : _currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: 'POS',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Caja',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Proyectos',
            ),
          ],
        ),
      ),
    );
  }
}
