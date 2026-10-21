import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Product> _products = [];
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
        setState(() => _loading = false);
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar inventario: $e', stack);
      setState(() => _loading = false);
    }
  }

  void _showAddProductDialog() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'General');
    final priceCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '10');
    final minStockCtrl = TextEditingController(text: '3');

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final price = double.tryParse(priceCtrl.text) ?? 0.0;
          final cost = double.tryParse(costCtrl.text) ?? 0.0;
          final margin = price > 0 ? ((price - cost) / price) * 100 : 0.0;

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
                      Text(
                        'Nuevo Producto / Material',
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
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Nombre del Producto / Servicio *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: catCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Categoría (Materiales, Servicios, Retail...)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setModalState(() {}),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Costo Base (\$ USD)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setModalState(() {}),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Precio Venta (\$ USD) *',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Indicador dinámico de margen de ganancia
                  if (price > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: margin >= 30 ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Margen Estimado de Ganancia:',
                            style: TextStyle(
                              color: margin >= 30 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${margin.toStringAsFixed(1)}% (\$${(price - cost).toStringAsFixed(2)})',
                            style: TextStyle(
                              color: margin >= 30 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Stock Actual',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: minStockCtrl,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Stock Mínimo (Alerta)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final p = Product(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameCtrl.text.trim(),
                          category: catCtrl.text.trim().isEmpty ? 'General' : catCtrl.text.trim(),
                          priceUsd: double.tryParse(priceCtrl.text) ?? 0.0,
                          costUsd: double.tryParse(costCtrl.text) ?? 0.0,
                          stock: int.tryParse(stockCtrl.text) ?? 0,
                          minStock: int.tryParse(minStockCtrl.text) ?? 2,
                        );

                        setState(() => _products.insert(0, p));
                        await StorageService.instance.save('products', _products.map((item) => item.toJson()).toList());
                        DebugLogger.instance.info('Producto agregado: ${p.name}');
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Guardar en Catálogo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_products.length} Artículos en Catálogo',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _products.isEmpty
                  ? Center(
                      child: Text(
                        'Sin artículos en inventario.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _products[i];
                        final isLowStock = p.stock <= p.minStock;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isLowStock
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isLowStock ? const Color(0xFFEF4444) : const Color(0xFFA855F7)).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2,
                                  color: isLowStock ? const Color(0xFFEF4444) : const Color(0xFFA855F7),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${p.category} • ',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Stock: ${p.stock}',
                                          style: TextStyle(
                                            color: isLowStock ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                            fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (p.costUsd > 0) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Margen: ${p.marginPercentage.toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$${p.priceUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  if (p.costUsd > 0)
                                    Text(
                                      'Costo: \$${p.costUsd.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        fontSize: 10,
                                      ),
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
}
