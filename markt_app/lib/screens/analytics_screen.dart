import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final List<Invoice> _invoices = [];
  final List<CashMovement> _cashMovements = [];
  bool _loading = true;
  String _period = 'mes'; // 'hoy', 'semana', 'mes', 'historico'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final rawInvoices = await StorageService.instance.load('invoices');
      final rawCash = await StorageService.instance.load('cash_movements');

      _invoices.clear();
      if (rawInvoices != null && rawInvoices is List) {
        for (final item in rawInvoices) {
          _invoices.add(Invoice.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      _cashMovements.clear();
      if (rawCash != null && rawCash is List) {
        for (final item in rawCash) {
          _cashMovements.add(CashMovement.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      setState(() => _loading = false);
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar analítica financiera: $e', stack);
      setState(() => _loading = false);
    }
  }

  List<Invoice> get _filteredInvoices {
    final now = DateTime.now();
    return _invoices.where((inv) {
      if (_period == 'hoy') {
        return inv.date.year == now.year && inv.date.month == now.month && inv.date.day == now.day;
      }
      if (_period == 'semana') {
        final diff = now.difference(inv.date).inDays;
        return diff <= 7;
      }
      if (_period == 'mes') {
        return inv.date.year == now.year && inv.date.month == now.month;
      }
      return true; // historico
    }).toList();
  }

  double get _totalBilledUsd =>
      _filteredInvoices.fold(0.0, (acc, inv) => acc + inv.totalUsd);

  double get _totalCogsUsd =>
      _filteredInvoices.fold(0.0, (acc, inv) => acc + inv.totalCostUsd);

  double get _operatingExpensesUsd {
    final now = DateTime.now();
    final expenses = _cashMovements.where((m) {
      if (m.type != 'expense') return false;
      if (_period == 'hoy') {
        return m.date.year == now.year && m.date.month == now.month && m.date.day == now.day;
      }
      if (_period == 'semana') {
        final diff = now.difference(m.date).inDays;
        return diff <= 7;
      }
      if (_period == 'mes') {
        return m.date.year == now.year && m.date.month == now.month;
      }
      return true;
    });
    return expenses.fold(0.0, (acc, m) => acc + m.amountUsd);
  }

  double get _netProfitRealUsd => (_totalBilledUsd - _totalCogsUsd) - _operatingExpensesUsd;

  double get _profitMarginPercent =>
      _totalBilledUsd > 0 ? (_netProfitRealUsd / _totalBilledUsd) * 100 : 0.0;

  Map<String, double> get _sellerPerformance {
    final Map<String, double> res = {};
    for (final inv in _filteredInvoices) {
      final name = inv.seller.name.isEmpty ? 'Vendedor Principal' : inv.seller.name;
      res[name] = (res[name] ?? 0.0) + inv.totalUsd;
    }
    return res;
  }

  Map<String, double> get _paymentMethodBreakdown {
    final Map<String, double> res = {};
    for (final inv in _filteredInvoices) {
      String m = inv.paymentMethod;
      // Normalizar nombres
      if (m.toLowerCase().contains('movil') || m.toLowerCase().contains('móvil')) {
        m = 'Pago Móvil';
      } else if (m.toLowerCase().contains('punto') || m.toLowerCase().contains('debito') || m.toLowerCase().contains('débito')) {
        m = 'Punto de Venta / Débito';
      } else if (m.toLowerCase().contains('transferencia')) {
        m = 'Transferencia Bancaria';
      } else if (m.toLowerCase().contains('zelle')) {
        m = 'Zelle (USD)';
      } else if (m.toLowerCase().contains('efectivo') && m.toLowerCase().contains('bs')) {
        m = 'Efectivo Bs.';
      } else if (m.toLowerCase().contains('efectivo') || m.toLowerCase().contains('usd')) {
        m = 'Efectivo USD (\$)';
      }
      res[m] = (res[m] ?? 0.0) + inv.totalUsd;
    }
    return res;
  }

  void _shareFinancialReportWhatsApp() {
    final rate = BcvService.instance.currentRates.usd;
    final totalBs = _totalBilledUsd * rate;
    final profitBs = _netProfitRealUsd * rate;

    final report = '''
*REPORTE GERENCIAL MARKT POS*
Periodo: ${_period.toUpperCase()}
-----------------------------------
*Ventas Facturadas:* \$${_totalBilledUsd.toStringAsFixed(2)} (~Bs. ${totalBs.toStringAsFixed(2)})
*Costo Mercancía (COGS):* \$${_totalCogsUsd.toStringAsFixed(2)}
*Gastos Operativos Caja:* \$${_operatingExpensesUsd.toStringAsFixed(2)}
-----------------------------------
*Utilidad Neta Real:* \$${_netProfitRealUsd.toStringAsFixed(2)} (~Bs. ${profitBs.toStringAsFixed(2)})
*Margen Operativo:* ${_profitMarginPercent.toStringAsFixed(1)}%
*Tickets Emitidos:* ${_filteredInvoices.length}
-----------------------------------
_Generado automáticamente por MARKT POS._
''';

    Clipboard.setData(ClipboardData(text: report));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen financiero copiado al portapapeles para WhatsApp'),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header y Botón Compartir
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analítica & Utilidad Real',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Métricas financieras y COGS (Fase 5)',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _shareFinancialReportWhatsApp,
                icon: const Icon(Icons.share, size: 16),
                label: const Text('WhatsApp'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector de Período (Hoy / Esta Semana / Este Mes / Histórico)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('hoy', 'Hoy', isDark),
                _buildPeriodChip('semana', 'Esta Semana', isDark),
                _buildPeriodChip('mes', 'Este Mes', isDark),
                _buildPeriodChip('historico', 'Histórico Completo', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tarjeta Principal de Utilidad Neta
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _netProfitRealUsd >= 0
                    ? [const Color(0xFF064E3B), const Color(0xFF047857)]
                    : [const Color(0xFF7F1D1D), const Color(0xFF991B1B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'UTILIDAD NETA REAL',
                      style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Margen: ${_profitMarginPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${_netProfitRealUsd.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Aprox. Bs. ${(_netProfitRealUsd * rate).toStringAsFixed(2)} al cambio BCV',
                  style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bento de 3 Columnas Financieras
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  title: 'Ventas Totales',
                  value: '\$${_totalBilledUsd.toStringAsFixed(2)}',
                  subtitle: '${_filteredInvoices.length} facturas',
                  icon: Icons.payments,
                  iconColor: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBentoCard(
                  title: 'Costo Mercancía',
                  value: '\$${_totalCogsUsd.toStringAsFixed(2)}',
                  subtitle: 'COGS base',
                  icon: Icons.shopping_bag_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildBentoCard(
                  title: 'Gastos Caja',
                  value: '\$${_operatingExpensesUsd.toStringAsFixed(2)}',
                  subtitle: 'Egresos reg.',
                  icon: Icons.money_off,
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Rendimiento de Vendedores & Comisiones
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Rendimiento de Vendedores',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_sellerPerformance.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Sin ventas registradas en este período.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ..._sellerPerformance.entries.map((entry) {
                    final percent = _totalBilledUsd > 0 ? (entry.value / _totalBilledUsd) * 100 : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                entry.key,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '\$${entry.value.toStringAsFixed(2)} (${percent.toStringAsFixed(0)}%)',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Analítica por Método de Pago (Pago Móvil, Punto de Venta, Efectivo, etc.)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ventas por Método de Pago',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tasa: Bs. ${rate.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_paymentMethodBreakdown.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Sin ventas registradas en este período.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ..._paymentMethodBreakdown.entries.map((entry) {
                    final percent = _totalBilledUsd > 0 ? (entry.value / _totalBilledUsd) * 100 : 0.0;
                    final amountBs = entry.value * rate;
                    IconData mIcon = Icons.payments_outlined;
                    Color mColor = const Color(0xFF10B981);
                    if (entry.key.contains('Móvil')) {
                      mIcon = Icons.phone_android;
                      mColor = const Color(0xFF38BDF8);
                    } else if (entry.key.contains('Punto')) {
                      mIcon = Icons.credit_card;
                      mColor = const Color(0xFF6366F1);
                    } else if (entry.key.contains('Transferencia')) {
                      mIcon = Icons.account_balance;
                      mColor = const Color(0xFFF59E0B);
                    } else if (entry.key.contains('Zelle')) {
                      mIcon = Icons.send_to_mobile;
                      mColor = const Color(0xFF8B5CF6);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(mIcon, size: 16, color: mColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${entry.value.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
                                    style: TextStyle(color: mColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Bs. ${amountBs.toStringAsFixed(2)}',
                                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 10),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: percent / 100,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            color: mColor,
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String id, String label, bool isDark) {
    final isSelected = _period == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF6366F1),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (val) => setState(() => _period = id),
      ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
