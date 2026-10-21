import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final List<CashMovement> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCashMovements();
  }

  Future<void> _loadCashMovements() async {
    try {
      final raw = await StorageService.instance.load('cash_movements');
      if (raw != null && raw is List) {
        setState(() {
          _movements.clear();
          for (final item in raw) {
            _movements.add(CashMovement.fromJson(Map<String, dynamic>.from(item)));
          }
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar libro de caja: $e', stack);
      setState(() => _loading = false);
    }
  }

  double get _totalBalance => _movements.fold(0.0, (acc, m) {
        return m.type == 'income' ? acc + m.amountUsd : acc - m.amountUsd;
      });

  void _showAddMovementDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String type = 'income';

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
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nuevo Movimiento de Caja',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Ingreso (+)')),
                      selected: type == 'income',
                      selectedColor: const Color(0xFF10B981),
                      onSelected: (val) => setModalState(() => type = 'income'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Egreso (-)')),
                      selected: type == 'expense',
                      selectedColor: const Color(0xFFEF4444),
                      onSelected: (val) => setModalState(() => type = 'expense'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Monto en USD (\$)',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Descripción / Motivo',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) return;

                    final newMov = CashMovement(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      type: type,
                      category: type == 'income' ? 'Ingreso General' : 'Gasto Operativo',
                      amountUsd: amt,
                      amountBs: 0.0,
                      method: 'efectivo_usd',
                      description: descController.text.trim().isEmpty ? 'Movimiento registrado' : descController.text.trim(),
                      date: DateTime.now(),
                    );

                    setState(() => _movements.insert(0, newMov));
                    await StorageService.instance.save('cash_movements', _movements.map((m) => m.toJson()).toList());
                    DebugLogger.instance.info('Movimiento de caja registrado: ${newMov.type} \$${newMov.amountUsd}');
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Guardar Movimiento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Balance Header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo Actual en Caja', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '\$${_totalBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _totalBalance >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddMovementDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Registrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Lista de Movimientos
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _movements.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay movimientos registrados en caja.',
                        style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _movements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final m = _movements[i];
                        final isIncome = m.type == 'income';

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isIncome ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.description,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${m.date.day}/${m.date.month}/${m.date.year} - ${m.category}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isIncome ? '+' : '-'}\$${m.amountUsd.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
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
}
