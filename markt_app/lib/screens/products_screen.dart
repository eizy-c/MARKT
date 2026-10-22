import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../services/bcv_service.dart';
import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';
import '../widgets/recipe_config_modal.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final List<Product> _products = [];
  final List<ProductCategory> _categories = [];
  bool _loading = true;
  String _selectedTab = 'todos'; // 'todos', 'producto', 'servicio', 'material'
  String _selectedCategoryFilter = 'todas';

  @override
  void initState() {
    super.initState();
    StorageService.instance.dataUpdateNotifier.addListener(_onStorageUpdate);
    _loadAll();
  }

  @override
  void dispose() {
    StorageService.instance.dataUpdateNotifier.removeListener(_onStorageUpdate);
    super.dispose();
  }

  void _onStorageUpdate() {
    if (mounted) {
      _loadAll();
    }
  }

  Future<void> _loadAll() async {
    try {
      final rawCats = await StorageService.instance.load('categories');
      if (rawCats != null && rawCats is List && rawCats.isNotEmpty) {
        _categories.clear();
        for (final item in rawCats) {
          _categories.add(ProductCategory.fromJson(Map<String, dynamic>.from(item)));
        }
      }

      // Categorías estándar para taller de publicidad solicitadas por el cliente
      final standardCategories = [
        ProductCategory(id: 'cat_avisos', name: 'Avisos', type: 'producto'),
        ProductCategory(id: 'cat_corporeos', name: 'Corpóreos', type: 'producto'),
        ProductCategory(id: 'cat_medallas', name: 'Medallas', type: 'producto'),
        ProductCategory(id: 'cat_habladores', name: 'Habladores', type: 'producto'),
        ProductCategory(id: 'cat_neon', name: 'Avisos Neón', type: 'producto'),
        ProductCategory(id: 'cat_espejos', name: 'Cuadros de Espejos', type: 'producto'),
        ProductCategory(id: 'cat_materiales', name: 'Materiales e Insumos', type: 'material'),
        ProductCategory(id: 'cat_servicios', name: 'Servicios e Instalación', type: 'servicio'),
      ];

      bool addedAny = false;
      for (final std in standardCategories) {
        if (!_categories.any((c) => c.name.toLowerCase() == std.name.toLowerCase())) {
          _categories.add(std);
          addedAny = true;
        }
      }
      if (addedAny) {
        await _saveCategories();
      }

      final raw = await StorageService.instance.load('products');
      if (raw != null && raw is List) {
        _products.clear();
        for (final item in raw) {
          _products.add(Product.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      setState(() => _loading = false);
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar inventario/categorías: $e', stack);
      setState(() => _loading = false);
    }
  }

  Future<void> _saveCategories() async {
    await StorageService.instance.save('categories', _categories.map((c) => c.toJson()).toList());
  }

  Future<void> _saveProducts() async {
    await StorageService.instance.save('products', _products.map((item) => item.toJson()).toList());
  }

  /// Si se modifica el costo o precio de un material/insumo,
  /// actualiza automáticamente el costo y precio de los productos que lo usan en su receta.
  void _propagateMaterialPriceChanges(Product updatedMaterial) {
    bool hasPropagated = false;
    for (int i = 0; i < _products.length; i++) {
      final prod = _products[i];
      if (prod.recipe.isEmpty) continue;

      bool recipeModified = false;
      final newRecipe = prod.recipe.map((rItem) {
        if (rItem.inventoryProductId == updatedMaterial.id) {
          recipeModified = true;
          final unitCost = updatedMaterial.costUsd > 0 ? updatedMaterial.costUsd : updatedMaterial.priceUsd;
          return rItem.copyWith(
            unitCostUsd: unitCost,
          );
        }
        return rItem;
      }).toList();

      if (recipeModified) {
        final newRecipeCost = newRecipe.fold<double>(0.0, (acc, item) => acc + (item.totalCostUsd));
        // Mantener el margen porcentual que tenía el producto
        double newPrice = prod.priceUsd;
        if (prod.costUsd > 0 && prod.priceUsd > prod.costUsd) {
          final marginPercent = ((prod.priceUsd - prod.costUsd) / prod.costUsd);
          newPrice = double.parse((newRecipeCost * (1.0 + marginPercent)).toStringAsFixed(2));
        } else if (newRecipeCost > newPrice) {
          // Si el nuevo costo supera el precio de venta, aplicar al menos 30% de margen
          newPrice = double.parse((newRecipeCost * 1.30).toStringAsFixed(2));
        }

        _products[i] = prod.copyWith(
          costUsd: double.parse(newRecipeCost.toStringAsFixed(2)),
          priceUsd: newPrice,
          recipe: newRecipe,
        );
        hasPropagated = true;
        DebugLogger.instance.info('Precio recalculado por insumo para: ${prod.name} -> Costo: \$$newRecipeCost, Venta: \$$newPrice');
      }
    }

    if (hasPropagated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se actualizaron automáticamente los productos y recetas que usan este insumo.'),
          backgroundColor: Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCategoryManagementModal() {
    final nameCtrl = TextEditingController();
    String newCatType = 'producto';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setCatState) => Container(
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.category, color: Color(0xFF6366F1), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Módulo de Categorías',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Text(
                  'Crea categorías para organizar tus Productos, Servicios o Materiales (insumos de recetas).',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Formulario Nueva Categoría
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameCtrl,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Nombre de la categoría',
                          hintText: 'ej. Láminas Acrílicas, Mano de Obra, Avisos',
                          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: newCatType,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 12),
                            items: const [
                              DropdownMenuItem(value: 'producto', child: Text('Producto')),
                              DropdownMenuItem(value: 'servicio', child: Text('Servicio')),
                              DropdownMenuItem(value: 'material', child: Text('Material')),
                            ],
                            onChanged: (val) {
                              if (val != null) setCatState(() => newCatType = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final n = nameCtrl.text.trim();
                      if (n.isEmpty) return;
                      final cat = ProductCategory(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: n,
                        type: newCatType,
                      );
                      setState(() {
                        _categories.add(cat);
                      });
                      setCatState(() {
                        nameCtrl.clear();
                      });
                      await _saveCategories();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Registrar Categoría', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Categorías Registradas (${_categories.length}):',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),

                if (_categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No hay categorías creadas aún.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final c = _categories[i];
                        Color badgeColor = const Color(0xFF6366F1);
                        String badgeText = 'Producto';
                        if (c.type == 'material') {
                          badgeColor = const Color(0xFFF59E0B);
                          badgeText = 'Material';
                        } else if (c.type == 'servicio') {
                          badgeColor = const Color(0xFF10B981);
                          badgeText = 'Servicio';
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  c.name,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                onPressed: () async {
                                  setState(() {
                                    _categories.removeAt(i);
                                  });
                                  setCatState(() {});
                                  await _saveCategories();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddProductDialog([Product? existingProduct]) {
    final nameCtrl = TextEditingController(text: existingProduct?.name ?? '');
    String selectedCat = existingProduct?.category ?? (_categories.isNotEmpty ? _categories.first.name : 'General');
    String itemType = existingProduct?.type ?? (_categories.any((c) => c.name == selectedCat) ? _categories.firstWhere((c) => c.name == selectedCat).type : 'producto');
    String unit = existingProduct?.unit ?? 'unid';
    final priceCtrl = TextEditingController(text: existingProduct != null ? existingProduct.priceUsd.toStringAsFixed(2) : '');
    final costCtrl = TextEditingController(text: existingProduct != null ? existingProduct.costUsd.toStringAsFixed(2) : '');
    final stockCtrl = TextEditingController(text: existingProduct != null ? existingProduct.stock.toString() : '10');
    final minStockCtrl = TextEditingController(text: existingProduct != null ? existingProduct.minStock.toString() : '3');
    List<RecipeItem> currentRecipe = existingProduct != null ? List.from(existingProduct.recipe) : [];
    final cVal = existingProduct?.costUsd ?? 0.0;
    final pVal = existingProduct?.priceUsd ?? 0.0;
    final initialMargin = (cVal > 0 && pVal > 0) ? (((pVal - cVal) / cVal) * 100.0).toStringAsFixed(0) : '50';
    final marginCtrl = TextEditingController(text: initialMargin);
    double suggestedRetailFromRecipe = existingProduct?.recipeTotalSalePriceUsd ?? 0.0;
    String? photoPath = existingProduct?.imagePath;

    // Variables para la Calculadora de Compra en Lote / Presentación para Materiales
    bool showBulkCalc = false;
    String bulkPreset = 'lamina_1';
    final bulkCostCtrl = TextEditingController();
    final bulkWidthCtrl = TextEditingController(text: '122');
    final bulkHeightCtrl = TextEditingController(text: '244');
    final bulkQtyCtrl = TextEditingController(text: '2.977');
    String bulkMargin = '50';

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
                        existingProduct == null ? 'Nuevo Registro' : 'Editar Registro',
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
                  const SizedBox(height: 10),

                  // Foto del Producto / Catalogo
                  InkWell(
                    onTap: () async {
                      try {
                        final files = await FilePicker.pickFiles(type: FileType.image);
                        if (files.isNotEmpty && files.first.path != null) {
                          final saved = await StorageService.instance.saveProjectPhoto(files.first.path!);
                          setModalState(() {
                            photoPath = saved?.path ?? files.first.path;
                          });
                        }
                      } catch (e) {
                        DebugLogger.instance.error('Error al seleccionar foto de producto: $e');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 84,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: photoPath != null ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                          width: photoPath != null ? 1.5 : 1,
                        ),
                      ),
                      child: photoPath != null && File(photoPath!).existsSync()
                          ? Stack(
                              children: [
                                Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.file(
                                      File(photoPath!),
                                      height: 80,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        photoPath = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_a_photo_outlined, color: Color(0xFF6366F1), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Añadir Foto del Producto (Para Catálogo)',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selector de Tipo de Registro: Producto, Servicio, Material
                  Row(
                    children: [
                      _buildTypeSelectorChip('producto', 'Producto', itemType, (t) {
                        setModalState(() {
                          itemType = t;
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildTypeSelectorChip('servicio', 'Servicio', itemType, (t) {
                        setModalState(() {
                          itemType = t;
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildTypeSelectorChip('material', 'Material (Insumo)', itemType, (t) {
                        setModalState(() {
                          itemType = t;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nombre del Ítem
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: itemType == 'material'
                          ? 'Nombre del Material / Insumo * (ej. Lámina Acrílico 3mm, Tira LED)'
                          : (itemType == 'servicio'
                              ? 'Nombre del Servicio * (ej. Mano de Obra, Instalación)'
                              : 'Nombre del Producto * (ej. Aviso Corporativo LED)'),
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Categoría y Unidad de Medida
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _categories.any((c) => c.name == selectedCat)
                                  ? selectedCat
                                  : (_categories.isNotEmpty ? _categories.first.name : null),
                              hint: Text('Categoría', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                              items: [
                                if (_categories.isEmpty)
                                  const DropdownMenuItem(value: 'General', child: Text('General (Crear categorías arriba)')),
                                ..._categories.map((c) => DropdownMenuItem(
                                      value: c.name,
                                      child: Text('${c.name} (${c.type})'),
                                    )),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    selectedCat = val;
                                    final found = _categories.firstWhere((c) => c.name == val, orElse: () => ProductCategory(id: '', name: val, type: itemType));
                                    itemType = found.type;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: unit,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                              items: const [
                                DropdownMenuItem(value: 'unid', child: Text('unid')),
                                DropdownMenuItem(value: 'mts', child: Text('mts')),
                                DropdownMenuItem(value: 'm2', child: Text('m2')),
                                DropdownMenuItem(value: 'láminas', child: Text('láminas')),
                                DropdownMenuItem(value: 'horas', child: Text('horas')),
                                DropdownMenuItem(value: 'global', child: Text('global')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => unit = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Si es Material / Insumo: Calculadora de Compra en Lote / Presentación Comercial
                  if (itemType == 'material') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calculate_outlined, color: Color(0xFF10B981), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Calculadora de Compra por Lote / Presentación',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: () => setModalState(() => showBulkCalc = !showBulkCalc),
                                icon: Icon(showBulkCalc ? Icons.expand_less : Icons.expand_more, size: 16),
                                label: Text(showBulkCalc ? 'Ocultar' : 'Calcular Costo', style: const TextStyle(fontSize: 11)),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981), visualDensity: VisualDensity.compact),
                              ),
                            ],
                          ),
                          Text(
                            'Calcula el costo por metro, m² o pieza al comprar en rollos, láminas enteras o cajas.',
                            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                          ),
                          if (showBulkCalc) ...[
                            const SizedBox(height: 10),
                            const Text('Presentación comercial adquirida:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildBulkPresetChip('lamina_1', '1 Completa (122x244cm)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkWidthCtrl.text = '122';
                                      bulkHeightCtrl.text = '244';
                                      bulkQtyCtrl.text = '2.977';
                                      unit = 'm2';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('lamina_media', '1/2 Lámina (122x122cm)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkWidthCtrl.text = '122';
                                      bulkHeightCtrl.text = '122';
                                      bulkQtyCtrl.text = '1.488';
                                      unit = 'm2';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('lamina_cuarto', '1/4 Lámina (60x122cm)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkWidthCtrl.text = '60';
                                      bulkHeightCtrl.text = '122';
                                      bulkQtyCtrl.text = '0.732';
                                      unit = 'm2';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('lamina_octavo', '1/8 Lámina (60x60cm)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkWidthCtrl.text = '60';
                                      bulkHeightCtrl.text = '60';
                                      bulkQtyCtrl.text = '0.360';
                                      unit = 'm2';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('rollo_led', 'Rollo LED (5 mts)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkQtyCtrl.text = '5.0';
                                      unit = 'mts';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('rollo_vinil', 'Rollo Vinil (50 mts)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkQtyCtrl.text = '50.0';
                                      unit = 'mts';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('paquete_100', 'Caja / Paquete (100 unid)', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                      bulkQtyCtrl.text = '100';
                                      unit = 'unid';
                                    });
                                  }),
                                  const SizedBox(width: 6),
                                  _buildBulkPresetChip('personalizado', 'Personalizado', bulkPreset, (p) {
                                    setModalState(() {
                                      bulkPreset = p;
                                    });
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Entradas de la calculadora
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: bulkCostCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    onChanged: (_) => setModalState(() {}),
                                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                      labelText: 'Total Pagado (\$ USD) *',
                                      hintText: 'Ej. 80.00',
                                      filled: true,
                                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (bulkPreset.startsWith('lamina_')) ...[
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: bulkWidthCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) {
                                        final w = double.tryParse(bulkWidthCtrl.text) ?? 0.0;
                                        final h = double.tryParse(bulkHeightCtrl.text) ?? 0.0;
                                        if (w > 0 && h > 0) {
                                          bulkQtyCtrl.text = ((w * h) / 10000.0).toStringAsFixed(3);
                                        }
                                        setModalState(() {});
                                      },
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Ancho cm',
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: bulkHeightCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) {
                                        final w = double.tryParse(bulkWidthCtrl.text) ?? 0.0;
                                        final h = double.tryParse(bulkHeightCtrl.text) ?? 0.0;
                                        if (w > 0 && h > 0) {
                                          bulkQtyCtrl.text = ((w * h) / 10000.0).toStringAsFixed(3);
                                        }
                                        setModalState(() {});
                                      },
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Alto cm',
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: bulkQtyCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (_) => setModalState(() {}),
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                                      decoration: InputDecoration(
                                        labelText: 'Rendimiento ($unit)',
                                        filled: true,
                                        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Margen sugerido de venta al detal
                            Row(
                              children: [
                                const Text('Margen Venta Detal:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 6),
                                ...['30', '40', '50', '70', '100'].map((m) {
                                  final isSel = bulkMargin == m;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: InkWell(
                                      onTap: () => setModalState(() => bulkMargin = m),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFF10B981) : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isSel ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                                        ),
                                        child: Text(
                                          '+$m%',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isSel ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A))),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Tarjeta de Resultado en Vivo
                            Builder(builder: (_) {
                              final totalP = double.tryParse(bulkCostCtrl.text) ?? 0.0;
                              final q = double.tryParse(bulkQtyCtrl.text) ?? 1.0;
                              final unitC = (totalP > 0 && q > 0) ? (totalP / q) : 0.0;
                              final mVal = double.tryParse(bulkMargin) ?? 50.0;
                              final unitSp = unitC * (1.0 + (mVal / 100.0));

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Costo Unitario: \$${unitC.toStringAsFixed(2)} / $unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF10B981))),
                                        Text('Venta Detal: \$${unitSp.toStringAsFixed(2)} / $unit (+$bulkMargin%)', style: const TextStyle(fontSize: 10, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        if (unitC <= 0) return;
                                        setModalState(() {
                                          costCtrl.text = unitC.toStringAsFixed(2);
                                          priceCtrl.text = unitSp.toStringAsFixed(2);
                                          marginCtrl.text = bulkMargin;
                                          if (stockCtrl.text.isEmpty || stockCtrl.text == '0' || stockCtrl.text == '10') {
                                            stockCtrl.text = q.round().toString();
                                          }
                                          showBulkCalc = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Aplicar a Insumo', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Si es Producto terminado: Receta / Bill of Materials (BOM)
                  if (itemType == 'producto') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Receta de Fabricación (BOM):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6366F1))),
                                  Text(
                                    currentRecipe.isEmpty
                                        ? 'Sin materiales configurados'
                                        : '${currentRecipe.length} componentes • Costo: \$${currentRecipe.fold(0.0, (a, b) => a + b.totalCostUsd).toStringAsFixed(2)}',
                                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: ctx,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => RecipeConfigModal(
                                      title: nameCtrl.text.trim().isEmpty ? 'Producto' : nameCtrl.text.trim(),
                                      initialRecipe: currentRecipe,
                                      availableProducts: _products,
                                      onSave: (updated, totalCost, [suggestedSalePrice]) {
                                        setModalState(() {
                                          currentRecipe = updated;
                                          costCtrl.text = totalCost.toStringAsFixed(2);
                                          if (suggestedSalePrice != null && (suggestedSalePrice as double) > 0) {
                                            suggestedRetailFromRecipe = suggestedSalePrice;
                                          }
                                          final m = double.tryParse(marginCtrl.text) ?? 50.0;
                                          priceCtrl.text = (totalCost * (1.0 + (m / 100.0))).toStringAsFixed(2);
                                        });
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.architecture, size: 14),
                                label: Text(currentRecipe.isEmpty ? 'Configurar Receta' : 'Editar Receta', style: const TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6366F1),
                                  side: const BorderSide(color: Color(0xFF6366F1)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          if (suggestedRetailFromRecipe > 0) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                setModalState(() {
                                  priceCtrl.text = suggestedRetailFromRecipe.toStringAsFixed(2);
                                  final c = double.tryParse(costCtrl.text) ?? 0.0;
                                  if (c > 0) {
                                    marginCtrl.text = (((suggestedRetailFromRecipe - c) / c) * 100.0).toStringAsFixed(0);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Suma venta de insumos: \$${suggestedRetailFromRecipe.toStringAsFixed(2)} [Tocar para aplicar]',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selector de Margen de Ganancia (%) Automático
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('% de Ganancia Deseada:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Precio de venta automático', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [30, 40, 50, 60, 80, 100].map((mVal) {
                              final isCurrent = marginCtrl.text == mVal.toString();
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text('+$mVal%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : null)),
                                  backgroundColor: isCurrent ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  onPressed: () {
                                    setModalState(() {
                                      marginCtrl.text = mVal.toString();
                                      final c = double.tryParse(costCtrl.text) ?? 0.0;
                                      priceCtrl.text = (c * (1.0 + (mVal / 100.0))).toStringAsFixed(2);
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Precios / Costos
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costCtrl,
                          readOnly: currentRecipe.isNotEmpty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (val) {
                            final c = double.tryParse(val) ?? 0.0;
                            final m = double.tryParse(marginCtrl.text) ?? 50.0;
                            if (itemType == 'producto') {
                              priceCtrl.text = (c * (1.0 + (m / 100.0))).toStringAsFixed(2);
                            }
                            setModalState(() {});
                          },
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: currentRecipe.isNotEmpty ? 'Costo Receta (\$ USD)' : 'Costo Base (\$ USD)',
                            helperText: currentRecipe.isNotEmpty ? 'Suma automática de receta' : null,
                            labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (itemType == 'producto') ...[
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: marginCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              final m = double.tryParse(val) ?? 0.0;
                              final c = double.tryParse(costCtrl.text) ?? 0.0;
                              priceCtrl.text = (c * (1.0 + (m / 100.0))).toStringAsFixed(2);
                              setModalState(() {});
                            },
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: '% Gan.',
                              suffixText: '%',
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (itemType != 'material')
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) {
                              final p = double.tryParse(val) ?? 0.0;
                              final c = double.tryParse(costCtrl.text) ?? 0.0;
                              if (c > 0 && p > 0) {
                                final calculatedM = ((p - c) / c) * 100.0;
                                marginCtrl.text = calculatedM.toStringAsFixed(0);
                              }
                              setModalState(() {});
                            },
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Precio Venta Sugerido (\$ USD) *',
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

                  // Tarjeta dinámica de rentabilidad y ganancia neta en vivo
                  if (price > 0 && itemType != 'material')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: margin >= 30 ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (margin >= 30 ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ganancia Neta Limpia:',
                                style: TextStyle(
                                  color: margin >= 30 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '+\$${(price - cost).toStringAsFixed(2)} (~Bs. ${((price - cost) * BcvService.instance.currentRates.usd).toStringAsFixed(2)})',
                                style: TextStyle(
                                  color: margin >= 30 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Margen Comercial: ${margin.toStringAsFixed(1)}%', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              Text('Venta Final: \$${price.toStringAsFixed(2)} (~Bs. ${(price * BcvService.instance.currentRates.usd).toStringAsFixed(2)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Stock Actual y Mínimo (Crucial para Materiales y Productos)
                  if (itemType != 'servicio') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: itemType == 'material' ? 'Stock de Material ($unit) *' : 'Stock Actual ($unit)',
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
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final p = Product(
                          id: existingProduct?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameCtrl.text.trim(),
                          category: selectedCat.trim().isEmpty ? 'General' : selectedCat.trim(),
                          type: itemType,
                          unit: unit,
                          priceUsd: itemType == 'material' ? 0.0 : (double.tryParse(priceCtrl.text) ?? 0.0),
                          costUsd: double.tryParse(costCtrl.text) ?? 0.0,
                          stock: itemType == 'servicio' ? 999999 : (int.tryParse(stockCtrl.text) ?? 0),
                          minStock: itemType == 'servicio' ? 0 : (int.tryParse(minStockCtrl.text) ?? 2),
                          recipe: currentRecipe,
                          imagePath: photoPath,
                        );

                        setState(() {
                          if (existingProduct != null) {
                            final idx = _products.indexWhere((item) => item.id == existingProduct.id);
                            if (idx != -1) _products[idx] = p;
                          } else {
                            _products.insert(0, p);
                          }
                          // Si es un material, insumo o servicio, actualizar los productos que lo usan en su receta
                          if (p.type == 'material' || p.type == 'servicio') {
                            _propagateMaterialPriceChanges(p);
                          }
                        });
                        await _saveProducts();
                        DebugLogger.instance.info('Ítem guardado: ${p.name} (${p.type})');
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

  Widget _buildTypeSelectorChip(String value, String label, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == value;
    Color color = const Color(0xFF6366F1);
    if (value == 'material') color = const Color(0xFFF59E0B);
    if (value == 'servicio') color = const Color(0xFF10B981);

    return Expanded(
      child: GestureDetector(
        onTap: () => onSelect(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : Colors.grey.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : Colors.grey,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulkPresetChip(String id, String label, String currentPreset, Function(String) onSelect) {
    final isSel = currentPreset == id;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 10, color: isSel ? Colors.white : null, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
      selected: isSel,
      selectedColor: const Color(0xFF10B981),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onSelect(id),
    );
  }

  Widget _buildFilterTab(String key, String label, int count) {
    final isSelected = _selectedTab == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B).withValues(alpha: 0.4)),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  List<Product> get _displayedProducts {
    var list = _products;
    if (_selectedTab != 'todos') {
      list = list.where((p) => p.type == _selectedTab).toList();
    }
    if (_selectedCategoryFilter != 'todas') {
      list = list.where((p) => p.category.toLowerCase() == _selectedCategoryFilter.toLowerCase()).toList();
    }
    return list;
  }

  Widget _buildCategoryFilterChip(String key, String label) {
    final isSelected = _selectedCategoryFilter.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
        selectedColor: const Color(0xFF6366F1),
        checkmarkColor: Colors.white,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) => setState(() => _selectedCategoryFilter = key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final prodCount = _products.where((p) => p.type == 'producto').length;
    final servCount = _products.where((p) => p.type == 'servicio').length;
    final matCount = _products.where((p) => p.type == 'material').length;

    return Column(
      children: [
        // Cabecera con Botón de Categorías y Agregar Ítem
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_products.length} Ítems Registrados',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_categories.length} categorías activas',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showCategoryManagementModal,
                    icon: const Icon(Icons.category, size: 16),
                    label: const Text('Categorías', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddProductDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Filtro por Tipo de Ítem: Todos, Productos, Materiales, Servicios
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterTab('todos', 'Todos', _products.length),
              const SizedBox(width: 8),
              _buildFilterTab('producto', 'Productos', prodCount),
              const SizedBox(width: 8),
              _buildFilterTab('material', 'Materiales (Stock)', matCount),
              const SizedBox(width: 8),
              _buildFilterTab('servicio', 'Servicios', servCount),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Filtro por Categorías de Publicidad (Avisos, Corpóreos, Medallas, etc.)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildCategoryFilterChip('todas', 'Todas'),
              ..._categories.map((c) => _buildCategoryFilterChip(c.name, c.name)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Lista de Ítems
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _displayedProducts.isEmpty
                  ? Center(
                      child: Text(
                        'Sin artículos en esta vista.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _displayedProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = _displayedProducts[i];
                        final isLowStock = p.type != 'servicio' && p.stock <= p.minStock;

                        Color typeColor = const Color(0xFF6366F1);
                        IconData typeIcon = Icons.inventory_2;
                        if (p.type == 'material') {
                          typeColor = const Color(0xFFF59E0B);
                          typeIcon = Icons.layers;
                        } else if (p.type == 'servicio') {
                          typeColor = const Color(0xFF10B981);
                          typeIcon = Icons.build_circle;
                        }

                        final hasValidPhoto = p.imagePath != null && File(p.imagePath!).existsSync();

                        return InkWell(
                          onTap: () => _showAddProductDialog(p),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
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
                                // Foto miniatura o ícono de tipo
                                if (hasValidPhoto)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(p.imagePath!),
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: (isLowStock ? const Color(0xFFEF4444) : typeColor).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isLowStock ? Icons.warning_amber_rounded : typeIcon,
                                      color: isLowStock ? const Color(0xFFEF4444) : typeColor,
                                      size: 22,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: typeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              p.type.toUpperCase(),
                                              style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              p.name,
                                              style: TextStyle(
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            '${p.category} • ',
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (p.type != 'servicio')
                                            Text(
                                              'Stock: ${p.stock} ${p.unit}',
                                              style: TextStyle(
                                                color: isLowStock ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                                fontWeight: isLowStock ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            )
                                          else
                                            const Text(
                                              'Servicio Activo',
                                              style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                                            ),
                                        ],
                                      ),
                                      if (p.recipe.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${p.recipe.length} materiales/insumos • Receta: \$${p.recipeTotalCostUsd.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (p.type != 'material' && p.priceUsd > 0)
                                      Text(
                                        '\$${p.priceUsd.toStringAsFixed(2)}',
                                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    if (p.costUsd > 0)
                                      Text(
                                        'Costo: \$${p.costUsd.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: p.type == 'material' ? const Color(0xFF38BDF8) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                          fontSize: p.type == 'material' ? 14 : 10,
                                          fontWeight: p.type == 'material' ? FontWeight.bold : FontWeight.normal,
                                        ),
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
      ],
    );
  }
}
