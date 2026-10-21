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
  final List<BankAccount> _bankAccounts = [];
  final List<Seller> _sellers = [
    Seller(id: '1', name: 'Eizy Vendedor Principal', code: 'VEND-01'),
    Seller(id: '2', name: 'Caja Mostrador', code: 'CAJA-01'),
    Seller(id: '3', name: 'Ventas Online', code: 'ONL-01'),
  ];

  // Tipo de comprobante: 'factura' | 'cotizacion' | 'egreso' | 'abono'
  String _voucherType = 'factura';

  // Selección de Tasa: 'USD' | 'EUR'
  String _rateCurrency = 'USD';

  Client? _selectedClient;
  late Seller _selectedSeller;
  BusinessProfile _businessProfile = BusinessProfile();
  String _selectedPaymentMethod = 'Efectivo USD (\$)';
  BankAccount? _selectedBank;
  String _paymentReference = '';
  bool _loading = true;

  // Filtro y búsqueda de productos estilo Valery
  final TextEditingController _searchProductCtrl = TextEditingController();
  String _productSearchQuery = '';

  // Formulario rápido para Egresos y Abonos
  final TextEditingController _quickConceptCtrl = TextEditingController();
  final TextEditingController _quickAmountCtrl = TextEditingController();
  String _quickCurrency = 'USD'; // 'USD' o 'Bs'

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

  @override
  void dispose() {
    _searchProductCtrl.dispose();
    _quickConceptCtrl.dispose();
    _quickAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _initPosData() async {
    await _loadProducts();
    await _loadClients();
    await _loadBankAccounts();
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

  Future<void> _loadBankAccounts() async {
    try {
      final raw = await StorageService.instance.load('bank_accounts');
      if (raw != null && raw is List) {
        setState(() {
          _bankAccounts.clear();
          for (final b in raw) {
            _bankAccounts.add(BankAccount.fromJson(Map<String, dynamic>.from(b)));
          }
          if (_bankAccounts.isNotEmpty) {
            _selectedBank = _bankAccounts.first;
          }
        });
      } else {
        final defaultAccounts = [
          BankAccount(
            id: '1',
            bankName: 'Banesco Banco Universal',
            accountNumber: '0134-0000-00-0000000000',
            accountHolder: 'EIZY STORE C.A.',
            docId: 'J-28425010-0',
            phone: '0414-5803945',
            accountType: 'Corriente',
          ),
          BankAccount(
            id: '2',
            bankName: 'Banco de Venezuela',
            accountNumber: '0102-0000-00-0000000000',
            accountHolder: 'EIZY STORE C.A.',
            docId: 'J-28425010-0',
            phone: '0414-5803945',
            accountType: 'Corriente',
          ),
        ];
        setState(() {
          _bankAccounts.addAll(defaultAccounts);
          _selectedBank = defaultAccounts.first;
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

  double get _activeRate {
    final rates = BcvService.instance.currentRates;
    return _rateCurrency == 'EUR' ? rates.eur : rates.usd;
  }

  void _addToCart(Product p, {int qty = 1}) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        _cart[idx].quantity += qty;
      } else {
        _cart.add(CartItem(product: p, quantity: qty));
      }
    });
    DebugLogger.instance.info('Producto agregado: ${p.name} (Cant: $qty)');
  }

  void _updateCartQty(Product p, int newQty) {
    setState(() {
      final idx = _cart.indexWhere((c) => c.product.id == p.id);
      if (idx >= 0) {
        if (newQty <= 0) {
          _cart.removeAt(idx);
        } else {
          _cart[idx].quantity = newQty;
        }
      }
    });
  }

  void _promptProductQuantity(Product p) {
    int qty = 1;
    final idx = _cart.indexWhere((c) => c.product.id == p.id);
    if (idx >= 0) qty = _cart[idx].quantity;
    final ctrl = TextEditingController(text: qty.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            p.name,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Precio: \$${p.priceUsd.toStringAsFixed(2)} | Bs. ${(p.priceUsd * _activeRate).toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      int val = int.tryParse(ctrl.text) ?? 1;
                      if (val > 1) {
                        val--;
                        ctrl.text = val.toString();
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                  ),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      int val = int.tryParse(ctrl.text) ?? 1;
                      val++;
                      ctrl.text = val.toString();
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final finalQty = int.tryParse(ctrl.text) ?? 1;
                _updateCartQty(p, finalQty);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirmar Cantidad'),
            ),
          ],
        );
      },
    );
  }

  double get _totalUsd => _cart.fold(0.0, (acc, item) => acc + item.totalUsd);

  void _showCartDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Detalle del Carrito Valery (${_cart.length} productos)',
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              ..._cart.map((item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.product.name, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                    subtitle: Text('Cant: ${item.quantity} x \$${item.product.priceUsd.toStringAsFixed(2)} = \$${item.totalUsd.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: () {
                            _updateCartQty(item.product, item.quantity - 1);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18, color: Color(0xFF10B981)),
                          onPressed: () {
                            _updateCartQty(item.product, item.quantity + 1);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                          onPressed: () {
                            _updateCartQty(item.product, 0);
                            setModalState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // Búsqueda de cliente por CI o registro rápido
  void _showClientLookupOrRegisterModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ciCtrl = TextEditingController(text: _selectedClient?.docId ?? '');
    final nameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    bool notFound = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
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
                          const Icon(Icons.person_search, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Text(
                            'Buscar o Registrar Cliente',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // CI Input con botón de búsqueda directa
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ciCtrl,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'C.I. / RIF del Cliente (ej. V-12345678)',
                            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (val) {
                            final clean = val.trim().toLowerCase();
                            final found = _clients.firstWhere(
                              (c) => c.docId.toLowerCase().contains(clean) || c.fullName.toLowerCase().contains(clean),
                              orElse: () => Client(id: '', docId: '', firstName: '', lastName: '', phone: '', address: ''),
                            );
                            if (found.id.isNotEmpty) {
                              setState(() => _selectedClient = found);
                              Navigator.pop(ctx);
                            } else {
                              setModalState(() {
                                notFound = true;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final clean = ciCtrl.text.trim().toLowerCase();
                          final found = _clients.firstWhere(
                            (c) => c.docId.toLowerCase().contains(clean) || c.fullName.toLowerCase().contains(clean),
                            orElse: () => Client(id: '', docId: '', firstName: '', lastName: '', phone: '', address: ''),
                          );
                          if (found.id.isNotEmpty) {
                            setState(() => _selectedClient = found);
                            Navigator.pop(ctx);
                          } else {
                            setModalState(() {
                              notFound = true;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Buscar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (notFound) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_add, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El cliente no está registrado. Completa sus datos para añadirlo de inmediato:',
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Nombre *',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lastNameCtrl,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Apellido',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'WhatsApp / Teléfono *',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: addressCtrl,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Dirección de Entrega',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final newClient = Client(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            docId: ciCtrl.text.trim(),
                            firstName: nameCtrl.text.trim(),
                            lastName: lastNameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            address: addressCtrl.text.trim(),
                          );
                          setState(() {
                            _clients.add(newClient);
                            _selectedClient = newClient;
                          });
                          await StorageService.instance.save('clients', _clients.map((c) => c.toJson()).toList());
                          if (mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Registrar y Seleccionar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      'O selecciona de la lista existente:',
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      child: ListView.separated(
                        itemCount: _clients.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final c = _clients[i];
                          return ListTile(
                            dense: true,
                            leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                            title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('CI: ${c.docId} • Telf: ${c.phone}', style: const TextStyle(fontSize: 11)),
                            onTap: () {
                              setState(() => _selectedClient = c);
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Diálogo obligatorio de Referencia y Banco para Pago Móvil / Transferencia
  Future<bool> _promptPagoMovilBankAndReference() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final refCtrl = TextEditingController(text: _paymentReference);
    BankAccount? chosenBank = _selectedBank ?? (_bankAccounts.isNotEmpty ? _bankAccounts.first : null);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF38BDF8).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.phone_android, color: Color(0xFF38BDF8), size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Datos de Pago Móvil',
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Es obligatorio seleccionar el Banco receptor y colocar el número de referencia:',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 14),

              // Banco Destino
              const Text('Banco Receptor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BankAccount>(
                    isExpanded: true,
                    value: chosenBank,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                    items: _bankAccounts
                        .map((b) => DropdownMenuItem(
                              value: b,
                              child: Text('${b.bankName} (${b.phone})'),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => chosenBank = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Número de Referencia (Obligatorio)
              const Text('Número de Referencia (Últimos 4-6 dígitos): *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: refCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Ej. 849201',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (refCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('¡Atención! Debe colocar el número de referencia para continuar'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedBank = chosenBank;
                  _paymentReference = refCtrl.text.trim();
                });
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              child: const Text('Validar y Facturar'),
            ),
          ],
        ),
      ),
    );

    return confirmed ?? false;
  }

  // Facturar / Procesar Comprobante
  Future<void> _processVoucher() async {
    // 1. Validaciones para Pago Móvil
    final isPagoMovil = _selectedPaymentMethod.toLowerCase().contains('móvil') || _selectedPaymentMethod.toLowerCase().contains('movil');
    if (isPagoMovil) {
      final ok = await _promptPagoMovilBankAndReference();
      if (!ok) return;
    }

    final rate = _activeRate;
    double totalUsd = 0.0;
    double totalBs = 0.0;
    String folioPrefix = 'FES-';

    if (_voucherType == 'cotizacion') {
      folioPrefix = 'COT-';
    } else if (_voucherType == 'egreso') {
      folioPrefix = 'EGR-';
    } else if (_voucherType == 'abono') {
      folioPrefix = 'REC-';
    }

    _businessProfile.folioCounter++;
    final folioStr = '$folioPrefix${_businessProfile.folioCounter.toString().padLeft(4, '0')}';

    List<CartItem> invoiceItems = [];

    if (_voucherType == 'factura' || _voucherType == 'cotizacion') {
      if (_cart.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El carrito está vacío. Agregue productos antes de continuar.')),
        );
        return;
      }
      totalUsd = _totalUsd;
      totalBs = totalUsd * rate;
      invoiceItems = List.from(_cart);
    } else {
      // Egreso o Abono
      final amount = double.tryParse(_quickAmountCtrl.text) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor indique un monto válido.')),
        );
        return;
      }
      if (_quickCurrency == 'USD') {
        totalUsd = amount;
        totalBs = totalUsd * rate;
      } else {
        totalBs = amount;
        totalUsd = totalBs / rate;
      }

      final concept = _quickConceptCtrl.text.trim().isEmpty ? (_voucherType == 'egreso' ? 'Comprobante de Egreso' : 'Recibo de Abono') : _quickConceptCtrl.text.trim();

      invoiceItems = [
        CartItem(
          product: Product(
            id: 'mov-${DateTime.now().millisecondsSinceEpoch}',
            name: concept,
            category: _voucherType == 'egreso' ? 'Egreso Operativo' : 'Abono a Cuenta',
            priceUsd: totalUsd,
          ),
          quantity: 1,
        )
      ];
    }

    final invoice = Invoice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      folio: folioStr,
      voucherType: _voucherType,
      date: DateTime.now(),
      client: _selectedClient ?? Client(id: '0', docId: 'V-000000', firstName: 'Cliente', lastName: 'General', phone: '', address: ''),
      seller: _selectedSeller,
      items: invoiceItems,
      rateBcv: rate,
      rateCurrency: _rateCurrency,
      currencyMode: 'USD',
      totalUsd: totalUsd,
      totalBs: totalBs,
      paymentMethod: _selectedPaymentMethod,
      bankName: _selectedBank?.bankName,
      paymentReference: _paymentReference.isNotEmpty ? _paymentReference : null,
      notes: _quickConceptCtrl.text.trim().isNotEmpty ? _quickConceptCtrl.text.trim() : null,
      business: _businessProfile,
    );

    // Guardar perfil (contador de folio)
    await StorageService.instance.save('business_profile', _businessProfile.toJson());

    // Guardar en historial de facturas / comprobantes
    await _saveInvoiceHistory(invoice);

    // Impacto en Libro de Caja
    if (_voucherType == 'factura' || _voucherType == 'abono') {
      final cashMovement = CashMovement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'income',
        category: _voucherType == 'factura' ? 'Venta POS ($folioStr)' : 'Abono Caja ($folioStr)',
        amountUsd: totalUsd,
        amountBs: totalBs,
        method: _selectedPaymentMethod,
        description: '$folioStr - ${_selectedClient?.fullName ?? "Cliente"} - Ref: ${_paymentReference.isEmpty ? "N/A" : _paymentReference}',
        date: DateTime.now(),
      );
      await _recordCashMovement(cashMovement);
    } else if (_voucherType == 'egreso') {
      final cashMovement = CashMovement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'expense',
        category: 'Egreso de Caja ($folioStr)',
        amountUsd: totalUsd,
        amountBs: totalBs,
        method: _selectedPaymentMethod,
        description: '$folioStr - Concepto: ${_quickConceptCtrl.text.trim()} - Ref: ${_paymentReference.isEmpty ? "N/A" : _paymentReference}',
        date: DateTime.now(),
      );
      await _recordCashMovement(cashMovement);
    }
    // Cotización NO impacta caja

    // Limpiar carrito / formulario
    setState(() {
      _cart.clear();
      _paymentReference = '';
      _quickConceptCtrl.clear();
      _quickAmountCtrl.clear();
    });

    // Mostrar el ticket comprobante
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.9,
          child: InvoiceDetailModal(invoice: invoice),
        ),
      );
    }

    DebugLogger.instance.info('Comprobante emitido con éxito: $folioStr ($_voucherType)');
  }

  Future<void> _recordCashMovement(CashMovement movement) async {
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
      DebugLogger.instance.error('Error al registrar movimiento en caja: $e');
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

  List<Product> get _filteredProducts {
    if (_productSearchQuery.isEmpty) return _products;
    final q = _productSearchQuery.toLowerCase();
    return _products.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q) || (p.code ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = _activeRate;

    return Column(
      children: [
        // 1. Selector Segmentado de Tipo de Comprobante (Venta, Cotización, Egreso, Abono)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildVoucherChip('factura', '🧾 Venta', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildVoucherChip('cotizacion', '📋 Cotización', const Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                _buildVoucherChip('egreso', '💸 Egreso', const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                _buildVoucherChip('abono', '💰 Abono', const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ),

        // 2. Cabecera de Cliente, Vendedor y Tasa Dual (USD / EUR)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
          ),
          child: Column(
            children: [
              // Fila Cliente
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: _showClientLookupOrRegisterModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person, color: Color(0xFF6366F1), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedClient?.fullName ?? 'Seleccionar / Registrar Cliente',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'CI: ${_selectedClient?.docId ?? "N/A"} • Telf: ${_selectedClient?.phone ?? ""}',
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
                  OutlinedButton.icon(
                    onPressed: _showClientLookupOrRegisterModal,
                    icon: const Icon(Icons.search, size: 14),
                    label: const Text('Buscar CI', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fila Vendedor & Tasa BCV (USD / EUR)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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

                  // Selector Tasa USD / EUR BCV
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _rateCurrency,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                        items: [
                          DropdownMenuItem(value: 'USD', child: Text('USD: Bs. ${BcvService.instance.currentRates.usd.toStringAsFixed(2)}')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR: Bs. ${BcvService.instance.currentRates.eur.toStringAsFixed(2)}')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _rateCurrency = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 3. Vista Central: O Productos (Venta/Cotización) O Formulario Rápido (Egreso/Abono)
        if (_voucherType == 'factura' || _voucherType == 'cotizacion') ...[
          // Buscador rápido tipo Valery
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _searchProductCtrl,
              onChanged: (val) => setState(() => _productSearchQuery = val),
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre o categoría (Lista Valery)...',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _productSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchProductCtrl.clear();
                          setState(() => _productSearchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
              ),
            ),
          ),

          // Lista de Productos tipo Valery (Nombre, Stock, Cantidad, Precio Dual y Botón Selector)
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron productos.',
                          style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _filteredProducts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final p = _filteredProducts[i];
                          final cartItem = _cart.firstWhere((c) => c.product.id == p.id, orElse: () => CartItem(product: p, quantity: 0));
                          final inCartQty = cartItem.quantity;

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: inCartQty > 0
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                                width: inCartQty > 0 ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Badge de Stock y Categoría
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (inCartQty > 0 ? const Color(0xFF6366F1) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    inCartQty > 0 ? Icons.check_circle : Icons.inventory_2_outlined,
                                    color: inCartQty > 0 ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Detalles del Producto
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p.category} • Stock: ${p.stock} unids.',
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Precios USD y Bs.
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${p.priceUsd.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Bs. ${(p.priceUsd * rate).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),

                                // Controles de Cantidad tipo Valery
                                if (inCartQty > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _updateCartQty(p, inCartQty - 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), shape: BoxShape.circle),
                                          child: const Icon(Icons.remove, size: 14, color: Color(0xFFEF4444)),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _promptProductQuantity(p),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            '$inCartQty',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _updateCartQty(p, inCartQty + 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), shape: BoxShape.circle),
                                          child: const Icon(Icons.add, size: 14, color: Color(0xFF10B981)),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () => _promptProductQuantity(p),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Añadir', style: TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ] else ...[
          // Formulario Rápido de Movimiento Directo (Egreso / Abono a Caja)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _voucherType == 'egreso' ? Icons.money_off : Icons.add_circle,
                          color: _voucherType == 'egreso' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _voucherType == 'egreso' ? 'Datos del Egreso de Caja' : 'Datos del Abono / Anticipo',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _quickConceptCtrl,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: _voucherType == 'egreso' ? 'Concepto del Gasto (ej. Pago de Flete, Almuerzo, Material)' : 'Concepto del Abono (ej. Anticipo Trabajo Letras LED)',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quickAmountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                            decoration: InputDecoration(
                              labelText: 'Monto',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _quickCurrency,
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                items: const [
                                  DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                                  DropdownMenuItem(value: 'Bs', child: Text('Bs.')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _quickCurrency = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tasa aplicada: Bs. ${rate.toStringAsFixed(2)} ($_rateCurrency)',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // 4. Barra Inferior de Cobro, Banco y Método de Pago
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF020617) : Colors.white,
            border: Border(top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Resumen Carrito (en modo Factura o Cotización)
                if (_voucherType == 'factura' || _voucherType == 'cotizacion')
                  InkWell(
                    onTap: _cart.isEmpty ? null : _showCartDetails,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_cart_outlined, color: Color(0xFF6366F1), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '${_cart.length} ítems en orden (tocar para editar)',
                                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
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
                                'Bs. ${(_totalUsd * rate).toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),

                // Selector de Forma de Pago y Botón de Emisión
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
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
                    const SizedBox(width: 8),

                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: _processVoucher,
                        icon: Icon(_getSubmitButtonIcon(), size: 16),
                        label: Text(_getSubmitButtonLabel()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getSubmitButtonColor(),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildVoucherChip(String id, String label, Color color) {
    final isSelected = _voucherType == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => setState(() => _voucherType = id),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  IconData _getSubmitButtonIcon() {
    switch (_voucherType) {
      case 'cotizacion':
        return Icons.request_quote_outlined;
      case 'egreso':
        return Icons.money_off;
      case 'abono':
        return Icons.savings_outlined;
      case 'factura':
      default:
        return Icons.receipt_long;
    }
  }

  String _getSubmitButtonLabel() {
    switch (_voucherType) {
      case 'cotizacion':
        return 'Emitir Cotización';
      case 'egreso':
        return 'Registrar Egreso';
      case 'abono':
        return 'Registrar Abono';
      case 'factura':
      default:
        return 'Facturar Venta';
    }
  }

  Color _getSubmitButtonColor() {
    switch (_voucherType) {
      case 'cotizacion':
        return const Color(0xFF0284C7); // Sky blue
      case 'egreso':
        return const Color(0xFFDC2626); // Red
      case 'abono':
        return const Color(0xFFD97706); // Amber
      case 'factura':
      default:
        return const Color(0xFF10B981); // Emerald Green
    }
  }
}
