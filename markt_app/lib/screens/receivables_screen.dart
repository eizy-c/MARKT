import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class ReceivablesScreen extends StatefulWidget {
  const ReceivablesScreen({super.key});

  @override
  State<ReceivablesScreen> createState() => _ReceivablesScreenState();
}

class _ReceivablesScreenState extends State<ReceivablesScreen> {
  final List<ReceivableAccount> _accounts = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'al_dia', 'vencida', 'saldada'

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final raw = await StorageService.instance.load('receivables');
      if (raw != null && raw is List) {
        setState(() {
          _accounts.clear();
          for (final item in raw) {
            _accounts.add(ReceivableAccount.fromJson(Map<String, dynamic>.from(item)));
          }
          _loading = false;
        });
      } else {
        // Cuentas iniciales de demostración
        final demo = [
          ReceivableAccount(
            id: '1',
            clientName: 'Distribuidora Los Llanos C.A.',
            clientPhone: '+584145803945',
            concept: 'Factura FES-0038 Material Acrílico',
            totalUsd: 150.0,
            payments: [
              ReceivablePayment(
                id: 'p1',
                amountUsd: 50.0,
                method: 'pago_movil',
                date: DateTime.now().subtract(const Duration(days: 3)),
                note: 'Anticipo 30%',
              ),
            ],
            dueDate: DateTime.now().add(const Duration(days: 7)),
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
          ReceivableAccount(
            id: '2',
            clientName: 'Inversiones Gran Bazar',
            clientPhone: '+584120001122',
            concept: 'Factura FES-0029 Pendones y Vinil',
            totalUsd: 85.0,
            payments: [],
            dueDate: DateTime.now().subtract(const Duration(days: 2)), // Vencida
            createdAt: DateTime.now().subtract(const Duration(days: 16)),
          ),
        ];
        setState(() {
          _accounts.addAll(demo);
          _loading = false;
        });
        await StorageService.instance.save('receivables', _accounts.map((a) => a.toJson()).toList());
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar cuentas por cobrar: $e', stack);
      setState(() => _loading = false);
    }
  }

  double get _totalPendingUsd =>
      _accounts.fold(0.0, (acc, item) => acc + item.remainingBalanceUsd);

  List<ReceivableAccount> get _filteredAccounts {
    if (_filter == 'all') return _accounts;
    return _accounts.where((a) => a.status == _filter).toList();
  }

  void _showAddAccountDialog() {
    final clientCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();
    final totalCtrl = TextEditingController();
    int days = 15;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
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
                    Text(
                      'Nueva Cuenta por Cobrar (Crédito)',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: clientCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Nombre del Deudor / Cliente *',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Teléfono / WhatsApp de Cobro',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: conceptCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Concepto / Factura Relacionada',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: totalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Monto Total adeudado (\$ USD) *',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Plazo de Vencimiento:',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [7, 15, 30].map((d) {
                    final isSelected = days == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('$d días'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF6366F1),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                        onSelected: (val) => setModalState(() => days = d),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (clientCtrl.text.trim().isEmpty) return;
                      final total = double.tryParse(totalCtrl.text) ?? 0.0;
                      if (total <= 0) return;

                      final account = ReceivableAccount(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        clientName: clientCtrl.text.trim(),
                        clientPhone: phoneCtrl.text.trim(),
                        concept: conceptCtrl.text.trim().isEmpty ? 'Venta a crédito' : conceptCtrl.text.trim(),
                        totalUsd: total,
                        payments: [],
                        dueDate: DateTime.now().add(Duration(days: days)),
                        createdAt: DateTime.now(),
                      );

                      setState(() => _accounts.insert(0, account));
                      await StorageService.instance.save('receivables', _accounts.map((a) => a.toJson()).toList());
                      DebugLogger.instance.info('Cuenta por cobrar registrada para: ${account.clientName}');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Registrar Crédito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPaymentModal(ReceivableAccount acc) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String method = 'pago_movil';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final amtUsd = double.tryParse(amountCtrl.text) ?? 0.0;
          final amtBs = amtUsd * rate;

          return Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrar Abono a Deuda',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            acc.clientName,
                            style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Pendiente:', style: TextStyle(fontSize: 12)),
                        Text(
                          '\$${acc.remainingBalanceUsd.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setModalState(() {}),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Monto del Abono (\$ USD) *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixText: '\$ ',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  if (amtUsd > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Al cambio BCV: Bs. ${amtBs.toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: method,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Método de Pago',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pago_movil', child: Text('Pago Móvil Bs.')),
                      DropdownMenuItem(value: 'efectivo_usd', child: Text('Efectivo USD (\$)')),
                      DropdownMenuItem(value: 'efectivo_bs', child: Text('Efectivo Bs.')),
                      DropdownMenuItem(value: 'zelle', child: Text('Zelle')),
                      DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                    ],
                    onChanged: (val) => setModalState(() => method = val ?? 'pago_movil'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Referencia / Nota del Pago',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                        if (amt <= 0) return;

                        final p = ReceivablePayment(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          amountUsd: amt,
                          method: method,
                          date: DateTime.now(),
                          note: noteCtrl.text.trim(),
                        );

                        // Actualizar cuenta
                        final updatedPayments = List<ReceivablePayment>.from(acc.payments)..add(p);
                        final updatedAccount = ReceivableAccount(
                          id: acc.id,
                          clientName: acc.clientName,
                          clientPhone: acc.clientPhone,
                          concept: acc.concept,
                          totalUsd: acc.totalUsd,
                          payments: updatedPayments,
                          dueDate: acc.dueDate,
                          createdAt: acc.createdAt,
                        );

                        final idx = _accounts.indexWhere((a) => a.id == acc.id);
                        if (idx != -1) {
                          setState(() => _accounts[idx] = updatedAccount);
                          await StorageService.instance.save('receivables', _accounts.map((a) => a.toJson()).toList());
                        }

                        // Auto-alimentar Libro de Caja
                        final cashMov = CashMovement(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          type: 'income',
                          category: 'Abono Cuenta por Cobrar',
                          amountUsd: amt,
                          amountBs: amt * rate,
                          method: method,
                          description: 'Abono de ${acc.clientName} (${acc.concept})',
                          date: DateTime.now(),
                        );
                        _recordCashIncome(cashMov);

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Registrar Abono', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _recordCashIncome(CashMovement movement) async {
    try {
      final raw = await StorageService.instance.load('cash_movements');
      final List<Map<String, dynamic>> movements = [];
      if (raw != null && raw is List) {
        for (final m in raw) {
          movements.add(Map<String, dynamic>.from(m));
        }
      }
      movements.insert(0, movement.toJson());
      await StorageService.instance.save('cash_movements', movements);
    } catch (e) {
      DebugLogger.instance.error('Error al registrar abono en caja: $e');
    }
  }

  void _shareReminderWhatsApp(ReceivableAccount acc) {
    final rate = BcvService.instance.currentRates.usd;
    final totalBs = acc.remainingBalanceUsd * rate;
    final text = 'Hola estimado/a ${acc.clientName}, le saludamos cordialmente. '
        'Le recordamos amablemente su saldo pendiente de *\$${acc.remainingBalanceUsd.toStringAsFixed(2)}* '
        '(aprox. Bs. ${totalBs.toStringAsFixed(2)}) correspondiente a: "${acc.concept}". '
        'Agradecemos su gestión. ¡Feliz día!';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recordatorio copiado al portapapeles para WhatsApp a ${acc.clientName}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final overdueCount = _accounts.where((a) => a.status == 'vencida').length;

    return Column(
      children: [
        // KPI Strip (Fase 3 Changelog)
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
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
                        child: const Icon(Icons.request_quote_outlined, color: Color(0xFFEF4444), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Por Cobrar ("Quién me debe")',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_totalPendingUsd.toStringAsFixed(2)} en ${_accounts.where((a) => !a.isPaid).length} cuentas pendientes',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddAccountDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nuevo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Todas (${_accounts.length})', isDark),
                    _buildFilterChip('al_dia', 'Al Día (${_accounts.where((a) => a.status == 'al_dia').length})', isDark),
                    _buildFilterChip('vencida', 'Vencidas ($overdueCount)', isDark, isError: true),
                    _buildFilterChip('saldada', 'Saldadas (${_accounts.where((a) => a.status == 'saldada').length})', isDark),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _filteredAccounts.isEmpty
                  ? Center(
                      child: Text(
                        'No hay cuentas por cobrar en este filtro.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredAccounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final acc = _filteredAccounts[i];
                        final isPaid = acc.isPaid;
                        final isOverdue = acc.isOverdue;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isOverdue
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : (isOverdue
                                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                                              : const Color(0xFF38BDF8).withValues(alpha: 0.15)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isPaid ? 'Saldada' : (isOverdue ? 'Vencida' : 'Al Día'),
                                      style: TextStyle(
                                        color: isPaid
                                            ? const Color(0xFF10B981)
                                            : (isOverdue ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Resta: \$${acc.remainingBalanceUsd.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Total: \$${acc.totalUsd.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                acc.clientName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                acc.concept,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Vence: ${acc.dueDate.day}/${acc.dueDate.month}/${acc.dueDate.year}',
                                    style: TextStyle(
                                      color: isOverdue ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                      fontSize: 11,
                                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (acc.clientPhone.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.chat_outlined, color: Color(0xFF10B981), size: 18),
                                          tooltip: 'Cobrar por WhatsApp',
                                          onPressed: () => _shareReminderWhatsApp(acc),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (!isPaid)
                                        ElevatedButton.icon(
                                          onPressed: () => _showAddPaymentModal(acc),
                                          icon: const Icon(Icons.add_card, size: 14),
                                          label: const Text('Abonar', style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF6366F1),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String id, String label, bool isDark, {bool isError = false}) {
    final isSelected = _filter == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _filter = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isError ? const Color(0xFFEF4444) : const Color(0xFF6366F1))
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
