import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final List<Product> _products = [];
  final List<CartItem> _cart = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
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
        // Inicial con productos base de demostración si está vacío
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

  void _showCartDetails() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Detalle de la Orden', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(color: Color(0xFF1E293B)),
              ..._cart.map((item) => ListTile(
                title: Text(item.product.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('Cant: ${item.quantity} x \$${item.product.priceUsd.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444)),
                  onPressed: () {
                    _removeFromCart(item.product);
                    setModalState(() {});
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  double get _totalUsd => _cart.fold(0.0, (acc, item) => acc + item.totalUsd);

  void _completeSale() {
    if (_cart.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('Cobro Exitoso', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total cobrado: \$${_totalUsd.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Venta registrada en el sistema nativo de Flutter.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _cart.clear());
              DebugLogger.instance.info('Venta finalizada con éxito.');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Grid de Productos
        Expanded(
          flex: 6,
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
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1E293B)),
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
                                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Icon(Icons.add_circle_outline, color: Color(0xFF6366F1), size: 18),
                              ],
                            ),
                            Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '\$${p.priceUsd.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Barra Inferior del Carrito
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFF020617),
            border: Border(top: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _cart.isEmpty ? null : _showCartDetails,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: Color(0xFF94A3B8), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${_cart.length} productos en orden (toca para ver)',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        'Total: \$${_totalUsd.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _cart.isEmpty ? null : _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Cobrar / Facturar Ticket',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
