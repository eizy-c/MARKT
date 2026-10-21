import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';
import '../services/bcv_service.dart';
import '../widgets/invoice_detail_modal.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<Product> _products = [];
  final List<CartItem> _cart = [];
  final List<Client> _clients = [];
  final List<Seller> _sellers = [
    Seller(id: '1', name: 'Eizy Vendedor Principal', code: 'VEND-01'),
    Seller(id: '2', name: 'Caja Mostrador', code: 'CAJA-01'),
    Seller(id: '3', name: 'Ventas Online', code: 'ONL-01'),
  ];

  Client? _selectedClient;
  late Seller _selectedSeller;
  BusinessProfile _businessProfile = BusinessProfile();
  String _selectedPaymentMethod = 'Efectivo USD (\$)';
  bool _loading = true;

  final List<String> _paymentMethods = [
    'Efectivo USD (\$)',
    'Pago Móvil (Bs.)',
    'Punto de Venta / Débito',
    'Transferencia Bancaria',
    'Zelle (USD)',
    'Efectivo Bs.',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSeller = _sellers.first;
    _initPosData();
  }

  Future<void> _initPosData() async {
    await _loadProducts();
    await _loadClients();
    await _loadBusinessProfile();
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final raw = await StorageService.instance.load('business_profile');
      if (raw != null && raw is Map<String, dynamic>) {
        setState(() {
          _businessProfile = BusinessProfile.fromJson(raw);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadClients() async {
    try {
      final raw = await StorageService.instance.load('clients');
      if (raw != null && raw is List) {
        setState(() {
          _clients.clear();
          for (final c in raw) {
            _clients.add(Client.fromJson(Map<String, dynamic>.from(c)));
          }
          if (_clients.isNotEmpty) {
            _selectedClient = _clients.first;
          }
        });
      } else {
        final defaultClient = Client(
          id: '1',
          docId: 'V-28425010',
          firstName: 'Cliente',
          lastName: 'Mostrador',
          phone: '0414-5803945',
          address: 'Barquisimeto',
        );
        setState(() {
          _clients.add(defaultClient);
          _selectedClient = defaultClient;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final raw = await StorageService.instance.load('products');
      if (raw != null && raw is List) {
        setState(() {
          _products.clear();
          for (final item in raw) {
            _products.add(Product.fromJson(Map<String, dynamic>.from(item)));
          }
          _loading = false;
        });
      } else {
        final defaults = [
          Product(id: '1', name: 'Acrílico 3mm Cristal', category: 'Materiales', priceUsd: 15.0, stock: 25),
          Product(id: '2', name: 'Corte Láser CNC (Hora)', category: 'Servicios', priceUsd: 25.0, stock: 99),
          Product(id: '3', name: 'Letras Corpóreas LED', category: 'Publicidad', priceUsd: 45.0, stock: 10),
          Product(id: '4', name: 'Vinil Adhesivo Mate', category: 'Materiales', priceUsd: 8.5, stock: 50),
        ];
        setState(() {
          _products.addAll(defaults);
          _loading = false;
        });
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar productos POS: $e', stack);
      setState(() => _loading = false);
    }
  }

  void _addToCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        _cart[idx].quantity++;
      } else {
        _cart.add(CartItem(product: p, quantity: 1));
      }
    });
    DebugLogger.instance.info('Producto agregado al carrito: ${p.name}');
  }

  void _removeFromCart(Product p) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        if (_cart[idx].quantity > 1) {
          _cart[idx].quantity--;
        } else {
          _cart.removeAt(idx);
        }
      }
    });
  }

  double get _totalUsd => _cart.fold(0.0, (acc, item) => acc + item.totalUsd);

  void _showCartDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detalle de la Orden',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Color(0xFF1E293B)),
              ..._cart.map((item) => ListTile(
                title: Text(
                  item.product.name,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                ),
                subtitle: Text(
                  'Cant: ${item.quantity} x \$${item.product.priceUsd.toStringAsFixed(2)}',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                  onPressed: () {
                    _removeFromCart(item.product);
                    setModalState(() {});
                    setState(() {});
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectClientModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Seleccionar Cliente para Facturación',
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _clients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final c = _clients[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                    title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('CI: ${c.docId} • WA: ${c.phone}'),
                    onTap: () {
                      setState(() => _selectedClient = c);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _completeSaleAndShowInvoice() {
    if (_cart.isEmpty) return;

    final rateBcv = BcvService.instance.currentRates.usd;
    final totalUsd = _totalUsd;
    final totalBs = totalUsd * rateBcv;

    _businessProfile.folioCounter++;
    final folioStr = 'FES-${_businessProfile.folioCounter.toString().padLeft(4, '0')}';

    final invoice = Invoice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      folio: folioStr,
      date: DateTime.now(), // Fecha automática
      client: _selectedClient ?? Client(id: '0', docId: 'V-000000', firstName: 'Cliente', lastName: 'General', phone: '', address: ''),
      seller: _selectedSeller,
      items: List.from(_cart),
      rateBcv: rateBcv,
      currencyMode: 'USD',
      totalUsd: totalUsd,
      totalBs: totalBs,
      paymentMethod: _selectedPaymentMethod,
      business: _businessProfile,
    );

    // Guardar folio actualizado
    StorageService.instance.save('business_profile', _businessProfile.toJson());

    // FASE 5: Persistencia de Facturas para Analítica Financiera
    _saveInvoiceHistory(invoice);

    // FASE 2: Alimentación automática al Libro de Caja
    final cashMovement = CashMovement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: 'income',
      category: 'Venta POS ($folioStr)',
      amountUsd: totalUsd,
      amountBs: totalBs,
      method: _selectedPaymentMethod,
      description: 'Factura $folioStr - Cliente: ${invoice.client.fullName}',
      date: DateTime.now(),
    );
    _recordCashIncome(cashMovement);

    // Limpiar carrito
    setState(() => _cart.clear());

    // Mostrar el ticket / factura en pantalla completa
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.9,
        child: InvoiceDetailModal(invoice: invoice),
      ),
    );

    DebugLogger.instance.info('Factura generada y registrada en caja: $folioStr por \$${totalUsd.toStringAsFixed(2)}');
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
      DebugLogger.instance.error('Error al sincronizar con libro de caja: $e');
    }
  }

  Future<void> _saveInvoiceHistory(Invoice invoice) async {
    try {
      final raw = await StorageService.instance.load('invoices');
      final List<Map<String, dynamic>> list = [];
      if (raw != null && raw is List) {
        for (final item in raw) {
          list.add(Map<String, dynamic>.from(item));
        }
      }
      list.insert(0, invoice.toJson());
      await StorageService.instance.save('invoices', list);
    } catch (e) {
      DebugLogger.instance.error('Error al guardar historial de factura: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rateBcv = BcvService.instance.currentRates.usd;

    return Column(
      children: [
        // 1. Selector de Cliente & Vendedor (Stitch POS)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              // Cliente Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _showSelectClientModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFF6366F1), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedClient?.fullName ?? 'Seleccionar Cliente',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'CI: ${_selectedClient?.docId ?? "N/A"} • ${_selectedClient?.phone ?? ""}',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _showSelectClientModal,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cambiar', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Vendedor & Tasa Selector
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Seller>(
                          isExpanded: true,
                          value: _selectedSeller,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          items: _sellers.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedSeller = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Tasa: Bs. ${rateBcv.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. Grid de Productos del Catálogo
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final p = _products[i];
                    return InkWell(
                      onTap: () => _addToCart(p),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    p.category,
                                    style: const TextStyle(color: Color(0xFF6366F1), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Icon(Icons.add_circle_outline, color: Color(0xFF6366F1), size: 18),
                              ],
                            ),
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${p.priceUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Bs. ${(p.priceUsd * rateBcv).toStringAsFixed(2)}',
                                  style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // 3. Barra Inferior de Cobro & Método de Pago
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF020617) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Carrito Resumen
                InkWell(
                  onTap: _cart.isEmpty ? null : _showCartDetails,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: Color(0xFF6366F1), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${_cart.length} ítems (ver detalle)',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total: \$${_totalUsd.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Bs. ${(_totalUsd * rateBcv).toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selector de Forma de Pago
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedPaymentMethod,
                            dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                            ),
                            items: _paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentMethod = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cart.isEmpty ? null : _completeSaleAndShowInvoice,
                        icon: const Icon(Icons.receipt, size: 16),
                        label: const Text('Facturar Ticket'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
