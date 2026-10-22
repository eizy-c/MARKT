import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';

class RecipeConfigModal extends StatefulWidget {
  final String title;
  final List<RecipeItem> initialRecipe;
  final List<Product> availableProducts;
  final Function onSave;
  final double? initialAssemblyFee;

  const RecipeConfigModal({
    super.key,
    required this.title,
    required this.initialRecipe,
    required this.availableProducts,
    required this.onSave,
    this.initialAssemblyFee,
  });

  @override
  State<RecipeConfigModal> createState() => _RecipeConfigModalState();
}

class _RecipeConfigModalState extends State<RecipeConfigModal> {
  late final List<RecipeItem> _items;
  bool _includeInstallation = true;
  double _workshopMarginPercent = 50.0;
  late final TextEditingController _marginCtrl;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialRecipe);
    // Sincronizar monto de armado externo para que no aparezca en $0 ni redunde
    if (widget.initialAssemblyFee != null && widget.initialAssemblyFee! > 0) {
      final hasLabor = _items.any((it) => it.type == 'mano_obra');
      if (!hasLabor) {
        _items.add(RecipeItem(
          id: 'labor_armado_${DateTime.now().millisecondsSinceEpoch}',
          name: 'Mano de Obra Armado (Técnico)',
          type: 'mano_obra',
          quantity: 1,
          unit: 'global',
          unitCostUsd: widget.initialAssemblyFee!,
          unitSalePriceUsd: widget.initialAssemblyFee!,
        ));
      }
    }
    _marginCtrl = TextEditingController(text: '50');
  }

  @override
  void dispose() {
    _marginCtrl.dispose();
    super.dispose();
  }

  // 1. Costo Puro de Materiales e Insumos (Adquisicion)
  double get _materialsCostUsd => _items
      .where((it) => it.type == 'material' || it.type == 'consumible' || it.type == 'corte_cnc')
      .fold(0.0, (acc, item) => acc + item.totalCostUsd);

  // 2. Costo de Mano de Obra en Taller (Armador)
  double get _laborCostUsd => _items
      .where((it) => it.type == 'mano_obra')
      .fold(0.0, (acc, item) => acc + item.totalCostUsd);

  // Costo Real de Fabricacion en Taller (COGS del Aviso)
  double get _manufacturingCostUsd => _materialsCostUsd + _laborCostUsd;

  // 3. Costo e Instalacion en Sitio / Flete
  double get _installationCostUsd => _items
      .where((it) => it.type == 'instalacion')
      .fold(0.0, (acc, item) => acc + item.totalCostUsd);

  double get _installationSalePriceUsd => _items
      .where((it) => it.type == 'instalacion')
      .fold(0.0, (acc, item) => acc + (item.totalSalePriceUsd > 0 ? item.totalSalePriceUsd : item.totalCostUsd * 1.3));

  // Costo Total General (Incluyendo instalacion si esta activa)
  double get _totalCostUsd => _manufacturingCostUsd + (_includeInstallation ? _installationCostUsd : 0.0);

  // Suma de Precios de Venta de Insumos al Detal (Sueltos)
  double get _totalSalePriceUsd => _items.fold(0.0, (acc, item) => acc + item.totalSalePriceUsd);

  // Precio Sugerido de Cotizacion al Cliente:
  // (Costo Fabricacion * (1 + Margen %)) + (Instalacion si esta activa)
  double get _suggestedQuotationUsd {
    final fabPrice = _manufacturingCostUsd * (1.0 + (_workshopMarginPercent / 100.0));
    final instPrice = _includeInstallation ? _installationSalePriceUsd : 0.0;
    return fabPrice + instPrice;
  }

  double get _netProfitUsd => _suggestedQuotationUsd - _totalCostUsd;
  double get _finalMarginPercent => _suggestedQuotationUsd > 0
      ? ((_netProfitUsd) / _suggestedQuotationUsd) * 100
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

    // Dimensiones de piezas para Laminas (Acrilico, MDF, Alucobond, etc.)
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
        } else if (unit == 'laminas' || unit == 'láminas') {
          // Lamina estandar 122 x 244 cm = 29,768 cm2
          qtyCtrl.text = (areaCm2 / 29768.0).toStringAsFixed(4);
        } else {
          qtyCtrl.text = (areaCm2 / 10000.0).toStringAsFixed(4);
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
                        existingItem == null ? 'Anadir Insumo / Servicio' : 'Editar Componente',
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
                        _buildTypeChip('material', 'Material / Lamina', type, (t) {
                          setDialogState(() {
                            type = t;
                            if (unit == 'horas') unit = 'unid';
                          });
                        }),
                        const SizedBox(width: 6),
                        _buildTypeChip('corte_cnc', 'Corte CNC / Laser', type, (t) {
                          setDialogState(() {
                            type = t;
                            if (unit == 'unid') unit = 'mts';
                          });
                        }),
                        const SizedBox(width: 6),
                        _buildTypeChip('consumible', 'Consumible', type, (t) {
                          setDialogState(() {
                            type = t;
                          });
                        }),
                        const SizedBox(width: 6),
                        _buildTypeChip('mano_obra', 'Mano de Obra (Armado)', type, (t) {
                          setDialogState(() {
                            type = t;
                            unit = 'horas';
                            deductInv = false;
                          });
                        }),
                        const SizedBox(width: 6),
                        _buildTypeChip('instalacion', 'Instalacion en Sitio', type, (t) {
                          setDialogState(() {
                            type = t;
                            unit = 'global';
                            deductInv = false;
                          });
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Si es Material o Servicio de Inventario: Selector de articulo
                  if (widget.availableProducts.isNotEmpty) ...[
                    const Text('Vincular a Insumo / Material de Catalogo (Opcional):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                              final displayCost = p.costUsd > 0 ? p.costUsd : p.priceUsd;
                              return DropdownMenuItem(
                                value: p,
                                child: Text('$tag ${p.name} (Costo: \$${displayCost.toStringAsFixed(2)} | Venta: \$${p.priceUsd.toStringAsFixed(2)})'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProduct = val;
                              if (val != null) {
                                nameCtrl.text = val.name;
                                // Toma estrictamente el costo de adquisicion real del insumo
                                final realCost = val.costUsd > 0 ? val.costUsd : val.priceUsd;
                                costCtrl.text = realCost.toStringAsFixed(2);
                                salePriceCtrl.text = val.priceUsd > 0 ? val.priceUsd.toStringAsFixed(2) : (realCost * 1.5).toStringAsFixed(2);
                                if (val.unit.isNotEmpty) {
                                  unit = val.unit;
                                }
                                if (val.unit == 'láminas' || val.unit == 'laminas' || val.unit == 'm2' || val.unit == 'cm2' || val.name.toLowerCase().contains('acril') || val.name.toLowerCase().contains('lamina') || val.name.toLowerCase().contains('lámina') || val.name.toLowerCase().contains('mdf')) {
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

                  // Descripcion del Insumo / Servicio
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: type == 'mano_obra'
                          ? 'Descripcion de Mano de Obra (ej. Armado de letras 3D, Instalacion de LEDs)'
                          : (type == 'instalacion'
                              ? 'Descripcion de Instalacion (ej. Montaje en fachada, Andamios)'
                              : 'Descripcion del Insumo * (ej. Acrilico 3mm, Tira LED, Perfil de Aluminio)'),
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // MODO DIMENSIONAL PARA LAMINAS (ACRILICO, MDF, CORTE)
                  if (type == 'material' || type == 'corte_cnc') ...[
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
                                  Text('Calculo por Medidas (cm) [Laminas / Acrilicos]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF3B82F6))),
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
                            const SizedBox(height: 8),
                            const Text(
                              'Destajo / Fracciones Comerciales de Lámina:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6)),
                            ),
                            const SizedBox(height: 4),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildDestajoChip('1 Completa (122x244)', 122, 244, widthCtrl, heightCtrl, recalculateDimensionalQty, setDialogState),
                                  const SizedBox(width: 4),
                                  _buildDestajoChip('1/2 (122x122)', 122, 122, widthCtrl, heightCtrl, recalculateDimensionalQty, setDialogState),
                                  const SizedBox(width: 4),
                                  _buildDestajoChip('1/4 (60x122)', 60, 122, widthCtrl, heightCtrl, recalculateDimensionalQty, setDialogState),
                                  const SizedBox(width: 4),
                                  _buildDestajoChip('1/8 (60x60)', 60, 60, widthCtrl, heightCtrl, recalculateDimensionalQty, setDialogState),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
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
                            const SizedBox(height: 6),
                            Builder(builder: (_) {
                              final w = double.tryParse(widthCtrl.text) ?? 0.0;
                              final h = double.tryParse(heightCtrl.text) ?? 0.0;
                              final waste = double.tryParse(wasteCtrl.text) ?? 20.0;
                              final netAreaM2 = (w * h) / 10000.0;
                              final totalAreaM2 = netAreaM2 * (1.0 + (waste / 100.0));
                              String fractionTag = '';
                              if ((w == 122 && h == 244) || (w == 244 && h == 122)) {
                                fractionTag = ' [1 Completa]';
                              } else if (w == 122 && h == 122) {
                                fractionTag = ' [1/2 Lámina]';
                              } else if ((w == 60 && h == 122) || (w == 122 && h == 60)) {
                                fractionTag = ' [1/4 Lámina]';
                              } else if (w == 60 && h == 60) {
                                fractionTag = ' [1/8 Lámina]';
                              }

                              return Text(
                                'Área neta: ${netAreaM2.toStringAsFixed(3)} m²$fractionTag + ${waste.toStringAsFixed(0)}% merma = ${totalAreaM2.toStringAsFixed(3)} m² consumidos.',
                                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155), fontWeight: FontWeight.w600),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

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
                            labelText: type == 'mano_obra'
                                ? 'Horas / Jornadas *'
                                : (type == 'instalacion' ? 'Cantidad Servicio *' : 'Cantidad Consumida *'),
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
                                DropdownMenuItem(value: 'unid', child: Text('unid (piezas)')),
                                DropdownMenuItem(value: 'mts', child: Text('mts (lineal)')),
                                DropdownMenuItem(value: 'm2', child: Text('m2 (area)')),
                                DropdownMenuItem(value: 'cm2', child: Text('cm2')),
                                DropdownMenuItem(value: 'laminas', child: Text('laminas')),
                                DropdownMenuItem(value: 'horas', child: Text('horas (tecnico)')),
                                DropdownMenuItem(value: 'global', child: Text('global / servicio')),
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

                  // Costo Unitario de Compra (Puro)
                  TextField(
                    controller: costCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialogState(() {}),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: type == 'mano_obra'
                          ? 'Costo Armador (\$ USD) *'
                          : (type == 'instalacion' ? 'Costo Instalacion (\$ USD) *' : 'Costo Real Compra (\$ USD) *'),
                      helperText: 'Costo neto de adquisicion del material o servicio',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Subtotal Card
                  Builder(builder: (_) {
                    final q = double.tryParse(qtyCtrl.text) ?? 1.0;
                    final c = double.tryParse(costCtrl.text) ?? 0.0;
                    final sp = double.tryParse(salePriceCtrl.text) ?? (c * 1.5);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Costo para Fabricacion:', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                              Text('\$${(q * c).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Venta al Detal (Referencial):', style: TextStyle(fontSize: 10, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                              Text('\$${(q * sp).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6366F1))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 6),
                  if (type == 'material' || type == 'consumible')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Descontar automaticamente del inventario al facturar o finalizar', style: TextStyle(fontSize: 11)),
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
                      child: Text(existingItem == null ? 'Anadir a la Receta' : 'Actualizar Componente'),
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
    Color color = const Color(0xFF6366F1);
    if (id == 'corte_cnc') color = const Color(0xFFF59E0B);
    if (id == 'consumible') color = const Color(0xFFEC4899);
    if (id == 'mano_obra') color = const Color(0xFF38BDF8);
    if (id == 'instalacion') color = const Color(0xFF10B981);

    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      selectedColor: color,
      onSelected: (_) => onSelect(id),
    );
  }

  Widget _buildDestajoChip(
    String label,
    double w,
    double h,
    TextEditingController widthCtrl,
    TextEditingController heightCtrl,
    VoidCallback recalculate,
    StateSetter setDialogState,
  ) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.15),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      onPressed: () {
        setDialogState(() {
          widthCtrl.text = w.toStringAsFixed(0);
          heightCtrl.text = h.toStringAsFixed(0);
          recalculate();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(height: 14),

          // PANEL MAESTRO DE COSTOS Y COTIZACION
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Costo Puro Materiales + Mano de Obra = Costo Fabricacion
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. INSUMOS / MAT:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          Text(
                            '\$${_materialsCostUsd.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                          ),
                          Text('Costo neto compra', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2. MANO DE OBRA:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                          Text(
                            '\$${_laborCostUsd.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                          ),
                          Text('Tecnico armador', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('COSTO FABRICACION:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                          Text(
                            '\$${_manufacturingCostUsd.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B)),
                          ),
                          Text('Taller (COGS)', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Fila 2: Instalacion en Sitio Opcional (Toggle)
                if (_installationCostUsd > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.build_circle_outlined, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(
                              'Instalacion en Sitio: \$${_installationCostUsd.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _includeInstallation ? 'Incluida en Cotizacion' : 'Excluida de Cotizacion',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _includeInstallation ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                            Switch(
                              value: _includeInstallation,
                              activeThumbColor: const Color(0xFF10B981),
                              onChanged: (v) => setState(() => _includeInstallation = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Fila 3: Selector de Margen de Ganancia del Taller
                Row(
                  children: [
                    const Text('Margen Taller:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [30, 40, 50, 60, 80, 100].map((m) {
                            final isSel = _workshopMarginPercent == m.toDouble();
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ChoiceChip(
                                label: Text('+$m%', style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : null)),
                                selected: isSel,
                                selectedColor: const Color(0xFF6366F1),
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) {
                                  setState(() {
                                    _workshopMarginPercent = m.toDouble();
                                    _marginCtrl.text = m.toString();
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Fila 4: Tarjeta Destacada de PRECIO FINAL DE COTIZACION AL CLIENTE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6366F1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PRECIO SUGERIDO DE COTIZACION:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                          Text(
                            '\$${_suggestedQuotationUsd.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF6366F1)),
                          ),
                          Text(
                            '~Bs. ${(_suggestedQuotationUsd * rate).toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Ganancia: +\$${_netProfitUsd.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                          Text(
                            'Margen: ${_finalMarginPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                          ),
                          Text(
                            'Costo Total: \$${_totalCostUsd.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          if (_totalSalePriceUsd > 0)
                            Text(
                              'Venta Detal: \$${_totalSalePriceUsd.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1), fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ),
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
                'Componentes del Despiece (${_items.length}):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditItemDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Anadir Insumo / Servicio', style: TextStyle(fontSize: 12)),
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
          const SizedBox(height: 6),

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
                            'Sin consumibles ni materiales anadidos todavia.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Agrega lamina acrilico/MDF con medidas, tiras LED, corte CNC, mano de obra o instalacion.',
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
                      Color typeColor = const Color(0xFF10B981);
                      String typeBadge = 'MATERIAL';

                      if (it.type == 'consumible') {
                        typeIcon = Icons.science_outlined;
                        typeColor = const Color(0xFFEC4899);
                        typeBadge = 'CONSUMIBLE';
                      } else if (it.type == 'corte_cnc') {
                        typeIcon = Icons.precision_manufacturing_outlined;
                        typeColor = const Color(0xFFF59E0B);
                        typeBadge = 'CORTE CNC';
                      } else if (it.type == 'mano_obra') {
                        typeIcon = Icons.engineering_outlined;
                        typeColor = const Color(0xFF38BDF8);
                        typeBadge = 'MANO OBRA';
                      } else if (it.type == 'instalacion') {
                        typeIcon = Icons.build_outlined;
                        typeColor = const Color(0xFF6366F1);
                        typeBadge = 'INSTALACION';
                      }

                      final dimText = (it.widthCm != null && it.heightCm != null)
                          ? ' [${it.widthCm!.toStringAsFixed(1)}x${it.heightCm!.toStringAsFixed(1)} cm${it.wastePercent != null ? " +${it.wastePercent!.toStringAsFixed(0)}% merma" : ""}]'
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
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(typeBadge, style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${it.name}$dimText',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${it.quantity} ${it.unit} • Costo Puro: \$${it.totalCostUsd.toStringAsFixed(2)} • Venta Detal: \$${it.totalSalePriceUsd.toStringAsFixed(2)}',
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
          const SizedBox(height: 10),

          // Boton Guardar Receta
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                try {
                  // Entrega: items, costo real de fabricacion, precio sugerido de cotizacion
                  (widget.onSave as dynamic)(_items, _manufacturingCostUsd, _suggestedQuotationUsd);
                } catch (_) {
                  try {
                    (widget.onSave as dynamic)(_items, _totalCostUsd, _suggestedQuotationUsd);
                  } catch (_) {
                    (widget.onSave as dynamic)(_items, _totalCostUsd);
                  }
                }
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_outlined),
              label: Text('Confirmar & Aplicar Receta (\$${_suggestedQuotationUsd.toStringAsFixed(2)})'),
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
