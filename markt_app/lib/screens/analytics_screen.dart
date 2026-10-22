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
  final List<ProjectItem> _projects = [];
  final List<Seller> _sellers = [];
  String _teamSubTab = 'armadores';
  bool _loading = true;
  String _period = 'mes'; // 'hoy', 'semana', 'mes', 'historico'

  @override
  void initState() {
    super.initState();
    StorageService.instance.dataUpdateNotifier.addListener(_onStorageUpdate);
    _loadData();
  }

  @override
  void dispose() {
    StorageService.instance.dataUpdateNotifier.removeListener(_onStorageUpdate);
    super.dispose();
  }

  void _onStorageUpdate() {
    if (mounted) {
      _loadData();
    }
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

      final rawProjects = await StorageService.instance.load('proyectos');
      _projects.clear();
      if (rawProjects != null && rawProjects is List) {
        for (final item in rawProjects) {
          _projects.add(ProjectItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      final rawSellers = await StorageService.instance.load('sellers');
      _sellers.clear();
      if (rawSellers != null && rawSellers is List) {
        for (final item in rawSellers) {
          _sellers.add(Seller.fromJson(Map<String, dynamic>.from(item)));
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

  List<String> get _workshopWorkers {
    final Set<String> names = {};
    for (final s in _sellers) {
      if (s.role == 'armador' || s.role == 'ambos') {
        names.add(s.name);
      }
    }
    for (final p in _projects) {
      if (p.assignedWorkerName != null && p.assignedWorkerName!.trim().isNotEmpty) {
        names.add(p.assignedWorkerName!.trim());
      }
    }
    if (names.isEmpty && _sellers.isNotEmpty) {
      for (final s in _sellers) {
        names.add(s.name);
      }
    }
    return names.toList();
  }

  void _showSettleLaborModal(String workerName, List<ProjectItem> readyProjects, double totalToPayUsd) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;
    final totalBs = totalToPayUsd * rate;
    String selectedMethod = r'Efectivo USD ($)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments, color: Color(0xFF10B981), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Liquidar Mano de Obra',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  'Técnico / Armador: $workerName',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total a Pagar / Liquidar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                          Text(
                            '\${totalToPayUsd.toStringAsFixed(2)} USD',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Equivalente BCV:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          Text(
                            'Bs. ${totalBs.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Proyectos Terminados Incluidos (${readyProjects.length}):',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: readyProjects.length,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (c, idx) {
                      final p = readyProjects[idx];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.title,
                              style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155), fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '\${p.effectiveAssemblyFeeUsd.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Método de Pago / Origen:',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedMethod,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      items: const [
                        DropdownMenuItem(value: r'Efectivo USD ($)', child: Text(r'Efectivo USD ($)')),
                        DropdownMenuItem(value: 'Pago Móvil', child: Text('Pago Móvil')),
                        DropdownMenuItem(value: 'Transferencia Bancaria', child: Text('Transferencia Bancaria')),
                        DropdownMenuItem(value: 'Efectivo Bs.', child: Text('Efectivo Bs.')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedMethod = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () async {
                      // 1. Mark projects as assemblyPaid = true
                      final readyIds = readyProjects.map((p) => p.id).toSet();
                      for (int i = 0; i < _projects.length; i++) {
                        if (readyIds.contains(_projects[i].id)) {
                          _projects[i] = _projects[i].copyWith(assemblyPaid: true);
                        }
                      }
                      await StorageService.instance.save('proyectos', _projects.map((p) => p.toJson()).toList());

                      // 2. Create cash movement expense
                      final expense = CashMovement(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        type: 'expense',
                        category: 'Nómina y Pagos a Personal',
                        amountUsd: totalToPayUsd,
                        amountBs: totalBs,
                        method: selectedMethod,
                        description: 'Liquidación mano de obra armado - $workerName (${readyProjects.length} trabajos)',
                        date: DateTime.now(),
                      );
                      _cashMovements.insert(0, expense);
                      await StorageService.instance.save('cash_movements', _cashMovements.map((c) => c.toJson()).toList());

                      DebugLogger.instance.info('Mano de obra liquidada a $workerName por \${totalToPayUsd}');
                      setState(() {});
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mano de obra de $workerName liquidada exitosamente. Egreso registrado.'),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar Pago y Registrar Egreso', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    if (_loading) return const Center(child: CircularProgressIndicator());
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

          // Rendimiento de Personal: Ventas & Armados de Taller
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
                        const Icon(Icons.badge_outlined, color: Color(0xFF6366F1), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Rendimiento de Personal',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _teamSubTab = 'armadores'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _teamSubTab == 'armadores'
                                  ? const Color(0xFFF59E0B)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Armadores Taller',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _teamSubTab == 'armadores' ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() => _teamSubTab = 'vendedores'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _teamSubTab == 'vendedores'
                                  ? const Color(0xFF6366F1)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Vendedores',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _teamSubTab == 'vendedores' ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // PESTAÑA: ARMADORES & MANO DE OBRA
                if (_teamSubTab == 'armadores') ...[
                  Text(
                    'La mano de obra va directamente al técnico. Se desbloquea para pago únicamente cuando el trabajo está Finalizado / Entregado.',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  if (_workshopWorkers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No hay técnicos o trabajos de taller registrados.',
                          style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),
                    )
                  else
                    ..._workshopWorkers.map((workerName) {
                      // Proyectos de este trabajador
                      final workerProjs = _projects.where((p) =>
                          p.assignedWorkerName == workerName ||
                          _sellers.any((s) => s.name == workerName && s.id == p.assignedWorkerId)).toList();

                      // Listos para liquidar (terminados y aún no pagados)
                      final readyToPayProjs = workerProjs.where((p) => p.isAssemblyReady && !p.assemblyPaid).toList();
                      final readyToPayUsd = readyToPayProjs.fold(0.0, (acc, p) => acc + p.effectiveAssemblyFeeUsd);

                      // En taller / Por procesar (no finalizados aún)
                      final inProcessProjs = workerProjs.where((p) => !p.isAssemblyReady && p.effectiveAssemblyFeeUsd > 0).toList();
                      final inProcessUsd = inProcessProjs.fold(0.0, (acc, p) => acc + p.effectiveAssemblyFeeUsd);

                      // Ya pagados históricamente
                      final alreadyPaidProjs = workerProjs.where((p) => p.assemblyPaid).toList();
                      final alreadyPaidUsd = alreadyPaidProjs.fold(0.0, (acc, p) => acc + p.effectiveAssemblyFeeUsd);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.build_circle, color: Color(0xFFF59E0B), size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      workerName,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (readyToPayUsd > 0)
                                  ElevatedButton.icon(
                                    onPressed: () => _showSettleLaborModal(workerName, readyToPayProjs, readyToPayUsd),
                                    icon: const Icon(Icons.payments, size: 14),
                                    label: Text('Liquidar \$${readyToPayUsd.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Listo p/ Cobrar', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${readyToPayUsd.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                        Text(
                                          '${readyToPayProjs.length} terminados',
                                          style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('En Taller', style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${inProcessUsd.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                        ),
                                        Text(
                                          '${inProcessProjs.length} en proceso',
                                          style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)).withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Ya Pagado', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '\$${alreadyPaidUsd.toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                        Text(
                                          '${alreadyPaidProjs.length} liquidados',
                                          style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ] else ...[
                  // PESTAÑA: VENDEDORES & COMISIONES
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
                      final sObj = _sellers.where((s) => s.name.toLowerCase() == entry.key.toLowerCase()).firstOrNull;
                      final comPct = sObj?.commissionPercent ?? 5.0;
                      final comUsd = entry.value * (comPct / 100.0);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
                                  '\$${entry.value.toStringAsFixed(2)} (${percent.toStringAsFixed(0)}%) • Comis: \$${comUsd.toStringAsFixed(2)} (${comPct.toStringAsFixed(1)}%)',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
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
