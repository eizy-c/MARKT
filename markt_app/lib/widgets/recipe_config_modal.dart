import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';

class RecipeConfigModal extends StatefulWidget {
  final String title;
  final List<RecipeItem> initialRecipe;
  final List<Product> availableProducts;
  final Function(List<RecipeItem> updatedRecipe, double calculatedCostUsd) onSave;

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

  void _showAddEditItemDialog([RecipeItem? existingItem]) {
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final qtyCtrl = TextEditingController(text: (existingItem?.quantity ?? 1.0).toString());
    final costCtrl = TextEditingController(text: (existingItem?.unitCostUsd ?? 0.0).toString());
    String type = existingItem?.type ?? 'material';
    String unit = existingItem?.unit ?? 'unid';
    bool deductInv = existingItem?.deductInventory ?? true;
    Product? selectedProduct;

    if (existingItem?.inventoryProductId != null) {
      selectedProduct = widget.availableProducts.firstWhere(
        (p) => p.id == existingItem!.inventoryProductId,
        orElse: () => widget.availableProducts.isNotEmpty
            ? widget.availableProducts.first
            : Product(id: '', name: '', category: '', priceUsd: 0),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                        existingItem == null ? 'Añadir Componente / Consumo' : 'Editar Componente',
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
                        _buildTypeChip('material', 'Material', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('consumible', 'Consumible', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('corte_cnc', 'Corte CNC / Láser', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('mano_obra', 'Mano de Obra', type, (t) => setDialogState(() => type = t)),
                        const SizedBox(width: 6),
                        _buildTypeChip('instalacion', 'Instalación', type, (t) => setDialogState(() => type = t)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Si es Material de Inventario: Selector de artículo
                  if (type == 'material' && widget.availableProducts.isNotEmpty) ...[
                    const Text('Vincular a Material / Artículo de Inventario (Opcional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                child: Text('$tag ${p.name} (Stock: ${p.stock} ${p.unit}) - Costo: \$${p.costUsd > 0 ? p.costUsd.toStringAsFixed(2) : p.priceUsd.toStringAsFixed(2)}'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProduct = val;
                              if (val != null) {
                                nameCtrl.text = val.name;
                                costCtrl.text = (val.costUsd > 0 ? val.costUsd : val.priceUsd).toStringAsFixed(2);
                                if (val.unit.isNotEmpty && ['unid', 'mts', 'm2', 'horas', 'global'].contains(val.unit)) {
                                  unit = val.unit;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Nombre / Descripción del Insumo
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Descripción del Insumo o Tarea * (ej. 4 Separadores, Luces LED 12V)',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cantidad y Unidad
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Cantidad *',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
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
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              items: ['unid', 'mts', 'm2', 'horas', 'global']
                                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => unit = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Costo Unit (\$)',
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (type == 'material' && selectedProduct != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Descontar automáticamente del inventario al facturar/entregar', style: TextStyle(fontSize: 12)),
                      value: deductInv,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (v) => setDialogState(() => deductInv = v),
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final q = double.tryParse(qtyCtrl.text) ?? 1.0;
                        final c = double.tryParse(costCtrl.text) ?? 0.0;

                        final newItem = RecipeItem(
                          id: existingItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          inventoryProductId: selectedProduct?.id,
                          name: nameCtrl.text.trim(),
                          type: type,
                          quantity: q,
                          unit: unit,
                          unitCostUsd: c,
                          deductInventory: deductInv,
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
      height: MediaQuery.of(context).size.height * 0.88,
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
                    Row(
                      children: [
                        const Icon(Icons.architecture_outlined, color: Color(0xFF6366F1), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Receta de Materiales & Costos (BOM)',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
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
          const Divider(height: 20),

          // Total Cost Card
          Container(
            padding: const EdgeInsets.all(14),
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
                    const Text('COSTO REAL TOTAL DE FABRICACIÓN:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_totalCostUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                    ),
                    Text(
                      '~Bs. ${(_totalCostUsd * rate).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditItemDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Añadir Insumo', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lista de Insumos y Servicios
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                          const SizedBox(height: 12),
                          Text(
                            'Sin consumibles ni materiales añadidos todavía.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrega separadores, tiras LED, acrílico, horas de corte CNC o mano de obra.',
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
                          it.name,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${it.quantity} ${it.unit} x \$${it.unitCostUsd.toStringAsFixed(2)} ${it.deductInventory && it.inventoryProductId != null ? "• Descuenta Inventario" : ""}',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${it.totalCostUsd.toStringAsFixed(2)}',
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 13),
                            ),
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
          const SizedBox(height: 14),

          // Botón Guardar Receta
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onSave(_items, _totalCostUsd);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Confirmar & Guardar Receta de Costos'),
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
