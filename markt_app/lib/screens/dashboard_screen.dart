import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedPeriod = 'Este Mes';
  String _selectedProjectFilter = 'Todos';

  double _salesTotalUsd = 0.0;
  double _cogsTotalUsd = 0.0;
  double _cashBalanceUsd = 0.0;
  double _receivablesPendingUsd = 0.0;
  int _receivablesCount = 0;

  final List<ProjectItem> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      // 1. Facturas
      final rawInvoices = await StorageService.instance.load('invoices');
      double sales = 0.0;
      double cogs = 0.0;
      if (rawInvoices != null && rawInvoices is List) {
        for (final item in rawInvoices) {
          final inv = Invoice.fromJson(Map<String, dynamic>.from(item));
          sales += inv.totalUsd;
          cogs += inv.totalCostUsd;
        }
      }

      // 2. Caja
      final rawCash = await StorageService.instance.load('cash_movements');
      double cashBal = 0.0;
      double cashExpenses = 0.0;
      if (rawCash != null && rawCash is List) {
        for (final item in rawCash) {
          final m = CashMovement.fromJson(Map<String, dynamic>.from(item));
          if (m.type == 'income') {
            cashBal += m.amountUsd;
          } else {
            cashBal -= m.amountUsd;
            cashExpenses += m.amountUsd;
          }
        }
      }

      // 3. Cuentas por Cobrar
      final rawReceivables = await StorageService.instance.load('receivables');
      double recPending = 0.0;
      int recCount = 0;
      if (rawReceivables != null && rawReceivables is List) {
        for (final item in rawReceivables) {
          final acc = ReceivableAccount.fromJson(Map<String, dynamic>.from(item));
          if (!acc.isPaid) {
            recPending += acc.remainingBalanceUsd;
            recCount++;
          }
        }
      }

      // 4. Proyectos
      final rawProjects = await StorageService.instance.load('proyectos');
      _projects.clear();
      if (rawProjects != null && rawProjects is List) {
        for (final item in rawProjects) {
          _projects.add(ProjectItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      setState(() {
        _salesTotalUsd = sales;
        _cogsTotalUsd = cogs;
        _cashBalanceUsd = cashBal;
        _receivablesPendingUsd = recPending;
        _receivablesCount = recCount;
        _loading = false;
      });
    } catch (e, stack) {
      DebugLogger.instance.error('Error cargando métricas de dashboard: $e', stack);
      setState(() => _loading = false);
    }
  }

  double get _netProfitUsd => _salesTotalUsd - _cogsTotalUsd;
  double get _marginPercent => _salesTotalUsd > 0 ? (_netProfitUsd / _salesTotalUsd) * 100 : 0.0;

  List<ProjectItem> get _filteredProjects {
    if (_selectedProjectFilter == 'Todos') return _projects;
    if (_selectedProjectFilter == 'En Espera') {
      return _projects.where((p) => p.status == '1_aprobacion').toList();
    }
    if (_selectedProjectFilter == 'En Proceso') {
      return _projects.where((p) => p.status == '2_anticipo' || p.status == '3_taller').toList();
    }
    if (_selectedProjectFilter == 'Por Cobrar') {
      return _projects.where((p) => p.status == '4_sitio').toList();
    }
    if (_selectedProjectFilter == 'Listos') {
      return _projects.where((p) => p.status == '5_finalizado').toList();
    }
    return _projects;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;

    // Colores fieles a la captura (Azul claro suave en Light Mode, AMOLED en Dark Mode)
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBorder = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del Panel Principal: Resumen del Negocio
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PANEL PRINCIPAL',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Resumen del Negocio',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Métricas financieras y estado de pedidos en tiempo real',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dropdown "Este Mes"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPeriod,
                        icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        items: ['Hoy', 'Esta Semana', 'Este Mes', 'Histórico']
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedPeriod = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Banner Inteligente de Recordatorios y Notificaciones Activas
            _buildSmartAlertBanner(isDark),
            const SizedBox(height: 12),

            // Bento Grid de 4 Cards (Ventas, Utilidad Neta, Por Cobrar, Saldo en Caja)
            Row(
              children: [
                // 1. Ventas
                Expanded(
                  child: _buildKpiCard(
                    title: 'Ventas',
                    amount: '\$${_salesTotalUsd.toStringAsFixed(2)}',
                    subtext: '${(_salesTotalUsd * rate).toStringAsFixed(2)} Bs.',
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFF10B981).withValues(alpha: 0.12),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    onTap: () => widget.onNavigate(1), // POS
                  ),
                ),
                const SizedBox(width: 12),
                // 2. Utilidad Neta
                Expanded(
                  child: _buildKpiCard(
                    title: 'Utilidad Neta',
                    amount: '\$${_netProfitUsd.toStringAsFixed(2)}',
                    subtext: 'Margen: ${_marginPercent.toStringAsFixed(0)}%',
                    amountColor: const Color(0xFF2563EB),
                    icon: Icons.verified_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    onTap: () => widget.onNavigate(4), // Analítica
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // 3. Por Cobrar
                Expanded(
                  child: _buildKpiCard(
                    title: 'Por Cobrar',
                    amount: '\$${_receivablesPendingUsd.toStringAsFixed(2)}',
                    subtext: '$_receivablesCount cuentas pendientes',
                    titleColor: const Color(0xFFD97706),
                    amountColor: const Color(0xFFD97706),
                    icon: Icons.assignment_late_outlined,
                    iconColor: const Color(0xFFD97706),
                    iconBg: const Color(0xFFD97706).withValues(alpha: 0.12),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    onTap: () => widget.onNavigate(3), // Cuentas por Cobrar
                  ),
                ),
                const SizedBox(width: 12),
                // 4. Saldo en Caja
                Expanded(
                  child: _buildKpiCard(
                    title: 'Saldo en Caja',
                    amount: '\$${_cashBalanceUsd.toStringAsFixed(2)}',
                    subtext: '${(_cashBalanceUsd * rate).toStringAsFixed(2)} Bs.',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF64748B),
                    iconBg: const Color(0xFF64748B).withValues(alpha: 0.12),
                    cardBg: cardBg,
                    cardBorder: cardBorder,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    onTap: () => widget.onNavigate(2), // Libro de Caja
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Principal: Proyectos & Pedidos Activos
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assignment_outlined, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Proyectos & Pedidos Activos',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'En espera, en proceso de trabajo y por cobrar',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Botón Negro "+ Nuevo Pedido"
                  ElevatedButton.icon(
                    onPressed: () => widget.onNavigate(5), // Ir a Proyectos
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF6366F1) : Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Carrusel de Filtros: [Todos] [En Espera] [En Proceso] [Por Cobrar] [Listos]
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Todos', 'En Espera', 'En Proceso', 'Por Cobrar', 'Listos'].map((f) {
                        final isSelected = _selectedProjectFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedProjectFilter = f),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2563EB)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Lista resumida de proyectos según filtro
                  if (_loading)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else if (_filteredProjects.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No hay pedidos activos en este estado.',
                          style: TextStyle(color: secondaryText, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._filteredProjects.take(3).map((p) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      style: TextStyle(
                                        color: primaryText,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      p.clientName,
                                      style: TextStyle(color: secondaryText, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${p.totalUsd.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String subtext,
    Color? titleColor,
    Color? amountColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color cardBg,
    required Color cardBorder,
    required Color primaryText,
    required Color secondaryText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor ?? secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                color: amountColor ?? primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryText,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartAlertBanner(bool isDark) {
    final waitingProjectsCount = _projects.where((p) => p.status == '1_aprobacion').length;
    final readyProjectsCount = _projects.where((p) => p.status == '5_finalizado' || p.status == 'completed').length;
    final pendingDownPaymentCount = _projects.where((p) => p.status == '2_anticipo').length;

    final hasAlerts = _receivablesCount > 0 || waitingProjectsCount > 0 || readyProjectsCount > 0 || pendingDownPaymentCount > 0;
    if (!hasAlerts) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Recordatorios & Atención Requerida',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_receivablesCount > 0)
                _buildAlertPill(
                  label: '$_receivablesCount deudas pendientes',
                  icon: Icons.money_off,
                  color: const Color(0xFFEF4444),
                  onTap: () => widget.onNavigate(3), // Por Cobrar
                ),
              if (pendingDownPaymentCount > 0)
                _buildAlertPill(
                  label: '$pendingDownPaymentCount por cobrar inicial',
                  icon: Icons.pending_actions,
                  color: const Color(0xFFF59E0B),
                  onTap: () => widget.onNavigate(5), // Proyectos
                ),
              if (waitingProjectsCount > 0)
                _buildAlertPill(
                  label: '$waitingProjectsCount proyectos en espera',
                  icon: Icons.hourglass_top,
                  color: const Color(0xFF38BDF8),
                  onTap: () => widget.onNavigate(5), // Proyectos
                ),
              if (readyProjectsCount > 0)
                _buildAlertPill(
                  label: '$readyProjectsCount proyectos listos sin entregar',
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF10B981),
                  onTap: () => widget.onNavigate(5), // Proyectos
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertPill({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
