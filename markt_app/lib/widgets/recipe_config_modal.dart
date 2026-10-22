import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';

class RecipeConfigModal extends StatefulWidget {
  final String title;
  final List<RecipeItem> initialRecipe;
  final List<Product> availableProducts;
  final Function onSave;

  const RecipeConfigModal({
    super.key,
    required this.title,
    required this.initialRecipe,
    required this.availableProducts,
    required this.onSave,
  });

  @override
  State<RecipeConfigModal> createState() => _RecipeConfigModalState();
}

class _RecipeConfigModalState extends State<RecipeConfigModal> {
  late final List<RecipeItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialRecipe);
  }

  double get _totalCostUsd => _items.fold(0.0, (acc, item) => acc + item.totalCostUsd);
  double get _totalSalePriceUsd => _items.fold(0.0, (acc, item) => acc + item.totalSalePriceUsd);
  double get _marginPercent => _totalSalePriceUsd > 0
      ? ((_totalSalePriceUsd - _totalCostUsd) / _totalSalePriceUsd) * 100
      : 0.0;

  void _showAddEditItemDialog([RecipeItem? existingItem]) {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final qtyCtrl = TextEditingController(text: (existingItem?.quantity ?? 1.0).toString());
    final costCtrl = TextEditingController(text: (existingItem?.unitCostUsd ?? 0.0).toString());
    final salePriceCtrl = TextEditingController(
      text: existingItem != null && existingItem.unitSalePriceUsd > 0
          ? existingItem.unitSalePriceUsd.toStringAsFixed(2)
          : (existingItem != null ? (existingItem.unitCostUsd * 1.5).toStringAsFixed(2) : ''),
    );

    String type = existingItem?.type ?? 'material';
    String unit = existingItem?.unit ?? 'unid';
    bool deductInv = existingItem?.deductInventory ?? true;
    Product? selectedProduct;

    // Dimensiones de piezas (Acrílicos, MDF, etc.)
    bool isDimensional = existingItem?.widthCm != null && existingItem?.heightCm != null;
    final widthCtrl = TextEditingController(text: existingItem?.widthCm?.toString() ?? '');
    final heightCtrl = TextEditingController(text: existingItem?.heightCm?.toString() ?? '');
    final wasteCtrl = TextEditingController(text: existingItem?.wastePercent?.toString() ?? '20');

    if (existingItem?.inventoryProductId != null) {
      selectedProduct = widget.availableProducts.firstWhere(
        (p) => p.id == existingItem!.inventoryProductId,
        orElse: () => widget.availableProducts.isNotEmpty
            ? widget.availableProducts.first
            : Product(id: '', name: '', category: '', priceUsd: 0),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    void recalculateDimensionalQty() {
      final w = double.tryParse(widthCtrl.text) ?? 0.0;
      final h = double.tryParse(heightCtrl.text) ?? 0.0;
      final waste = double.tryParse(wasteCtrl.text) ?? 20.0;

      if (w > 0 && h > 0) {
        final areaCm2 = (w * h) * (1.0 + (waste / 100.0));
        if (unit == 'cm2') {
          qtyCtrl.text = areaCm2.toStringAsFixed(1);
        } else if (unit == 'm2') {
          qtyCtrl.text = (areaCm2 / 10000.0).toStringAsFixed(4);
        } else if (unit == 'láminas' || unit == 'laminas') {
          // Lámina estándar 122 x 244 cm = 29,768 cm2
          qtyCtrl.text = (areaCm2 / 29768.0).toStringAsFixed(4);
        } else {
          qtyCtrl.text = (areaCm2 / 10000.0).toStringAsFixed(3);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Padding(
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
                      Text(
                        existingItem == null ? 'Añadir Insumo / Servicio' : 'Editar Componente',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tipo de Insumo / Servicio
                  const Text('Tipo de Componente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTypeChip('material', 'Material / Lámina', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('corte_cnc', 'Corte CNC / Láser', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('consumible', 'Consumible', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('mano_obra', 'Mano de Obra', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('instalacion', 'Instalación', type, (t) => setDialogState(() => type = t)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Si es Material o Servicio de Inventario: Selector de artículo
                  if (widget.availableProducts.isNotEmpty) ...[
                    const Text('Vincular a Insumo / Material de Catálogo (Opcional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Product?>(
                          isExpanded: true,
                          value: selectedProduct,
                          hint: const Text('Seleccionar insumo o material...'),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                          items: [
                            const DropdownMenuItem<Product?>(value: null, child: Text('Personalizado (sin inventario)')),
                            ...widget.availableProducts.map((p) {
                              final tag = p.type == 'material' ? '[Material]' : (p.type == 'servicio' ? '[Servicio]' : '[Prod]');
                              return DropdownMenuItem(
                                value: p,
                                child: Text('$tag ${p.name} (Costo: \$${p.costUsd > 0 ? p.costUsd.toStringAsFixed(2) : p.priceUsd.toStringAsFixed(2)} | Venta: \$${p.priceUsd.toStringAsFixed(2)})'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProduct = val;
                              if (val != null) {
                                nameCtrl.text = val.name;
                                // Toma estrictamente el costo real de adquisición del insumo
                                final realCost = val.costUsd > 0 ? val.costUsd : val.priceUsd;
                                costCtrl.text = realCost.toStringAsFixed(2);
                                salePriceCtrl.text = val.priceUsd > 0 ? val.priceUsd.toStringAsFixed(2) : (realCost * 1.5).toStringAsFixed(2);
                                if (val.unit.isNotEmpty) {
                                  unit = val.unit;
                                }
                                if (val.unit == 'láminas' || val.unit == 'm2' || val.unit == 'cm2' || val.name.toLowerCase().contains('acril') || val.name.toLowerCase().contains('lámina')) {
                                  isDimensional = true;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Nombre del Insumo / Servicio
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Descripción del Insumo o Servicio *',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // MODO DIMENSIONAL PARA LÁMINAS (ACRÍLICO, MDF, CORTE)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.square_foot, size: 16, color: Color(0xFF3B82F6)),
                                SizedBox(width: 6),
                                Text('Cálculo por Medidas (cm) [Láminas / Acrílicos]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF3B82F6))),
                              ],
                            ),
                            Switch(
                              value: isDimensional,
                              activeThumbColor: const Color(0xFF3B82F6),
                              onChanged: (v) {
                                setDialogState(() {
                                  isDimensional = v;
                                  if (v) recalculateDimensionalQty();
                                });
                              },
                            ),
                          ],
                        ),
                        if (isDimensional) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: widthCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setDialogState(recalculateDimensionalQty),
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Ancho (cm)',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: heightCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setDialogState(recalculateDimensionalQty),
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: 'Alto (cm)',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: TextField(
                                  controller: wasteCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (_) => setDialogState(recalculateDimensionalQty),
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                  decoration: InputDecoration(
                                    labelText: '% Merma',
                                    filled: true,
                                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Calcula el área neta más el desperdicio y actualiza la cantidad automáticamente.',
                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cantidad y Unidad
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setDialogState(() {}),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Cantidad Consumida *',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: unit,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                              items: const [
                                DropdownMenuItem(value: 'unid', child: Text('unid')),
                                DropdownMenuItem(value: 'mts', child: Text('mts')),
                                DropdownMenuItem(value: 'm2', child: Text('m2')),
                                DropdownMenuItem(value: 'cm2', child: Text('cm2')),
                                DropdownMenuItem(value: 'láminas', child: Text('láminas')),
                                DropdownMenuItem(value: 'horas', child: Text('horas / min')),
                                DropdownMenuItem(value: 'global', child: Text('global')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    unit = val;
                                    if (isDimensional) recalculateDimensionalQty();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Costo Unitario y Precio Venta Sugerido del Insumo
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setDialogState(() {}),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Costo Insumo (\$ USD) *',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: salePriceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setDialogState(() {}),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Precio Venta Detal (\$)',
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Subtotal Card
                  Builder(builder: (_) {
                    final q = double.tryParse(qtyCtrl.text) ?? 1.0;
                    final c = double.tryParse(costCtrl.text) ?? 0.0;
                    final sp = double.tryParse(salePriceCtrl.text) ?? (c * 1.5);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Costo Parcial: \$${(q * c).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))),
                          Text('Venta Detal: \$${(q * sp).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF6366F1))),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 6),
                  if (type == 'material')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Descontar automáticamente del inventario al facturar/entregar', style: TextStyle(fontSize: 12)),
                      value: deductInv,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (v) => setDialogState(() => deductInv = v),
                    ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final q = double.tryParse(qtyCtrl.text) ?? 1.0;
                        final c = double.tryParse(costCtrl.text) ?? 0.0;
                        final sp = double.tryParse(salePriceCtrl.text) ?? (c * 1.5);

                        final newItem = RecipeItem(
                          id: existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          inventoryProductId: selectedProduct?.id,
                          name: nameCtrl.text.trim(),
                          type: type,
                          quantity: q,
                          unit: unit,
                          unitCostUsd: c,
                          unitSalePriceUsd: sp,
                          deductInventory: deductInv,
                          widthCm: isDimensional ? double.tryParse(widthCtrl.text) : null,
                          heightCm: isDimensional ? double.tryParse(heightCtrl.text) : null,
                          wastePercent: isDimensional ? double.tryParse(wasteCtrl.text) : null,
                        );

                        setState(() {
                          if (existingItem != null) {
                            final idx = _items.indexWhere((it) => it.id == existingItem.id);
                            if (idx >= 0) _items[idx] = newItem;
                          } else {
                            _items.add(newItem);
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(existingItem == null ? 'Añadir a la Receta' : 'Actualizar Insumo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String id, String label, String currentType, Function(String) onSelect) {
    final isSelected = currentType == id;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      onSelected: (_) => onSelect(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.architecture_outlined, color: Color(0xFF6366F1), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Receta de Materiales & Costos (BOM)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(height: 16),

          // Total Cost & Suggested Price Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('COSTO REAL TOTAL (COGS):', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    Text(
                      '\$${_totalCostUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                    ),
                    Text(
                      '~Bs. ${(_totalCostUsd * rate).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('SUMA VENTA AL DETAL:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                    Text(
                      '\$${_totalSalePriceUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)),
                    ),
                    Text(
                      'Margen: ${_marginPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Componentes (${_items.length}):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditItemDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir Insumo', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Lista de Insumos y Servicios
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_outlined, size: 44, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          const SizedBox(height: 8),
                          Text(
                            'Sin consumibles ni materiales añadidos todavía.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agrega separadores, tiras LED, acrílico con medidas, corte CNC o mano de obra.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final it = _items[i];
                      IconData typeIcon = Icons.inventory_2_outlined;
                      Color typeColor = const Color(0xFF6366F1);

                      if (it.type == 'consumible') {
                        typeIcon = Icons.science_outlined;
                        typeColor = const Color(0xFFEC4899);
                      } else if (it.type == 'corte_cnc') {
                        typeIcon = Icons.precision_manufacturing_outlined;
                        typeColor = const Color(0xFFF59E0B);
                      } else if (it.type == 'mano_obra') {
                        typeIcon = Icons.engineering_outlined;
                        typeColor = const Color(0xFF38BDF8);
                      } else if (it.type == 'instalacion') {
                        typeIcon = Icons.build_outlined;
                        typeColor = const Color(0xFF10B981);
                      }

                      final dimText = (it.widthCm != null && it.heightCm != null)
                          ? ' [${it.widthCm!.toStringAsFixed(1)}x${it.heightCm!.toStringAsFixed(1)} cm]'
                          : '';

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 18),
                        ),
                        title: Text(
                          '${it.name}$dimText',
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${it.quantity} ${it.unit} • Costo: \$${it.totalCostUsd.toStringAsFixed(2)} • Venta: \$${it.totalSalePriceUsd.toStringAsFixed(2)}',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF6366F1)),
                              onPressed: () => _showAddEditItemDialog(it),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                              onPressed: () => setState(() => _items.removeAt(i)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Botón Guardar Receta
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                try {
                  (widget.onSave as dynamic)(_items, _totalCostUsd, _totalSalePriceUsd);
                } catch (_) {
                  (widget.onSave as dynamic)(_items, _totalCostUsd);
                }
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Confirmar & Aplicar Receta'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
