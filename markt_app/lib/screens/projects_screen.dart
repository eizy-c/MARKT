import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_models.dart';
import '../services/bcv_service.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';
import '../widgets/recipe_config_modal.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final List<ProjectItem> _projects = [];
  final List<Product> _products = [];
  final List<Seller> _sellers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    StorageService.instance.dataUpdateNotifier.addListener(_onStorageUpdate);
    _loadData();
  }

  @override
  void dispose() {
    StorageService.instance.dataUpdateNotifier.removeListener(_onStorageUpdate);
    super.dispose();
  }

  void _onStorageUpdate() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final rawProds = await StorageService.instance.load('products');
      if (rawProds != null && rawProds is List) {
        _products.clear();
        for (final item in rawProds) {
          _products.add(Product.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      final rawSellers = await StorageService.instance.load('sellers');
      if (rawSellers != null && rawSellers is List) {
        _sellers.clear();
        for (final item in rawSellers) {
          _sellers.add(Seller.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    } catch (_) {}
    await _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final raw = await StorageService.instance.load('proyectos');
      if (raw != null && raw is List) {
        setState(() {
          _projects.clear();
          for (final item in raw) {
            _projects.add(ProjectItem.fromJson(Map<String, dynamic>.from(item)));
          }
          _loading = false;
        });
      } else {
        setState(() {
          _projects.clear();
          _loading = false;
        });
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error al cargar proyectos: $e', stack);
      setState(() => _loading = false);
    }
  }

  String _selectedStage = 'all';

  final List<Map<String, dynamic>> _stages = [
    {'id': 'all', 'name': 'Todos', 'icon': Icons.all_inbox},
    {'id': '1_aprobacion', 'name': '1. Aprobacion', 'icon': Icons.assignment_outlined},
    {'id': '2_anticipo', 'name': '2. Pago Anticipo', 'icon': Icons.payments_outlined},
    {'id': '3_taller', 'name': '3. Armado Taller', 'icon': Icons.precision_manufacturing_outlined},
    {'id': '4_sitio', 'name': '4. En Sitio', 'icon': Icons.engineering_outlined},
    {'id': '5_finalizado', 'name': '5. Entregado', 'icon': Icons.verified_outlined},
    {'id': 'catalogo', 'name': 'Catalogo / Fotos', 'icon': Icons.photo_library_outlined},
    {'id': 'cancelado', 'name': 'Cancelados', 'icon': Icons.cancel_outlined},
  ];

  List<ProjectItem> get _filteredProjects {
    if (_selectedStage == 'all') return _projects.where((p) => p.status != 'cancelado').toList();
    if (_selectedStage == 'catalogo') {
      return _projects.where((p) => (p.photos.isNotEmpty || p.status == '5_finalizado') && p.status != 'cancelado').toList();
    }
    return _projects.where((p) => p.status == _selectedStage).toList();
  }

  void _showAddProjectDialog() {
    final titleController = TextEditingController();
    final clientController = TextEditingController();
    final phoneController = TextEditingController();
    final dimController = TextEditingController();
    final totalController = TextEditingController();
    final assemblyFeeController = TextEditingController();
    List<RecipeItem> currentRecipe = [];
    String stage = '1_aprobacion';
    String? selectedWorkerId;
    String? selectedWorkerName;
    DateTime? selectedDeliveryDate = DateTime.now().add(const Duration(days: 3));

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
                      'Nuevo Proyecto / Pedido',
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
                  controller: titleController,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Título del Trabajo / Proyecto *',
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
                        controller: clientController,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Cliente / Empresa',
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
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'WhatsApp / Teléfono',
                          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dimController,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Medidas (ej. 50x50 cm)',
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
                        controller: totalController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: r'Precio Venta ($ USD) *',
                          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Asignar Técnico Armador & Mano de Obra
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.handyman, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Text(
                            'Taller: Técnico Armador & Mano de Obra',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: selectedWorkerId,
                            isExpanded: true,
                            hint: Text(
                              'Seleccionar Armador / Técnico',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                            ),
                            dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Sin Asignar Aún', style: TextStyle(fontSize: 12)),
                              ),
                              ..._sellers.map((s) {
                                final roleTag = s.role == 'armador'
                                    ? '[Técnico]'
                                    : (s.role == 'ambos' ? '[Taller/Venta]' : '[Ventas]');
                                return DropdownMenuItem<String?>(
                                  value: s.id,
                                  child: Text('${s.name} $roleTag', style: const TextStyle(fontSize: 12)),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedWorkerId = val;
                                if (val == null) {
                                  selectedWorkerName = null;
                                } else {
                                  final w = _sellers.firstWhere((s) => s.id == val);
                                  selectedWorkerName = w.name;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: assemblyFeeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                        decoration: InputDecoration(
                          labelText: r'Monto Mano de Obra Armado ($ USD)',
                          labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                          helperText: 'El dinero se desbloquea para pago al marcar el proyecto como Finalizado / Procesado.',
                          helperStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 10),
                          prefixIcon: const Icon(Icons.attach_money, size: 16),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Botón Configurar Consumibles / Receta del Proyecto
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Despiece, Consumibles y Receta:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6366F1))),
                            Text(
                              currentRecipe.isEmpty
                                  ? 'Sin consumibles calculados'
                                  : '${currentRecipe.length} ítems • Costo Total: \$${currentRecipe.fold(0.0, (a, b) => a + b.totalCostUsd).toStringAsFixed(2)}',
                              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: ctx,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => RecipeConfigModal(
                              title: titleController.text.trim().isEmpty ? 'Proyecto' : titleController.text.trim(),
                              initialRecipe: currentRecipe,
                              availableProducts: _products,
                              onSave: (updated, totalCost, [retailVal]) {
                                setModalState(() {
                                  currentRecipe = updated;
                                  // Auto sugerir mano de obra si está vacía
                                  final laborCost = updated.where((it) => it.type == 'mano_obra').fold(0.0, (acc, it) => acc + it.totalCostUsd);
                                  if (laborCost > 0 && (assemblyFeeController.text.isEmpty || assemblyFeeController.text == '0.0')) {
                                    assemblyFeeController.text = laborCost.toStringAsFixed(2);
                                  }
                                  // Auto sugerir precio final de cotización si no se ha colocado monto aún
                                  if (retailVal != null && (totalController.text.isEmpty || totalController.text == '0.0' || totalController.text == '0')) {
                                    totalController.text = (retailVal as double).toStringAsFixed(2);
                                  }
                                });
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.architecture, size: 14),
                        label: Text(currentRecipe.isEmpty ? 'Configurar' : 'Editar', style: const TextStyle(fontSize: 11)),
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
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDeliveryDate ?? DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setModalState(() => selectedDeliveryDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF6366F1)),
                            const SizedBox(width: 8),
                            Text(
                              selectedDeliveryDate != null
                                  ? 'Fecha de Entrega: ${selectedDeliveryDate!.day.toString().padLeft(2, '0')}/${selectedDeliveryDate!.month.toString().padLeft(2, '0')}/${selectedDeliveryDate!.year}'
                                  : 'Definir Fecha Estimada de Entrega',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.edit_calendar, size: 16, color: Color(0xFF6366F1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Etapa Inicial del Embudo:',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _stages.where((s) => s['id'] != 'all' && s['id'] != 'catalogo').map((s) {
                    final isSelected = stage == s['id'];
                    return ChoiceChip(
                      label: Text(s['name'], style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF6366F1),
                      onSelected: (val) => setModalState(() => stage = s['id']),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;
                      final amt = double.tryParse(totalController.text) ?? 0.0;
                      final fee = double.tryParse(assemblyFeeController.text) ?? 0.0;

                      final newP = ProjectItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: titleController.text.trim(),
                        clientName: clientController.text.trim().isEmpty ? 'Cliente Ocasional' : clientController.text.trim(),
                        clientPhone: phoneController.text.trim(),
                        totalUsd: amt,
                        status: stage,
                        date: DateTime.now(),
                        dimensions: dimController.text.trim(),
                        recipe: currentRecipe,
                        assignedWorkerId: selectedWorkerId,
                        assignedWorkerName: selectedWorkerName,
                        assemblyFeeUsd: fee,
                        assemblyPaid: false,
                        deliveryDate: selectedDeliveryDate,
                        photos: const [],
                      );

                      setState(() => _projects.insert(0, newP));
                      await StorageService.instance.save('proyectos', _projects.map((p) => p.toJson()).toList());
                      DebugLogger.instance.info('Proyecto creado: ${newP.title}');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Crear Proyecto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignWorkerModal(ProjectItem p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? selectedWorkerId = p.assignedWorkerId;
    String? selectedWorkerName = p.assignedWorkerName;

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
                      Text(
                        'Asignar Armador / Técnico',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  Text(
                    p.title,
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: selectedWorkerId,
                        isExpanded: true,
                        hint: Text(
                          'Seleccionar Armador / Técnico',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                        ),
                        dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Sin Asignar', style: TextStyle(fontSize: 13)),
                          ),
                          ..._sellers.map((s) {
                            final roleTag = s.role == 'armador'
                                ? '[Técnico]'
                                : (s.role == 'ambos' ? '[Taller/Venta]' : '[Ventas]');
                            return DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text('${s.name} $roleTag', style: const TextStyle(fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedWorkerId = val;
                            if (val == null) {
                              selectedWorkerName = null;
                            } else {
                              final w = _sellers.firstWhere((s) => s.id == val);
                              selectedWorkerName = w.name;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        final idx = _projects.indexWhere((it) => it.id == p.id);
                        if (idx != -1) {
                          setState(() {
                            _projects[idx] = p.copyWith(
                              assignedWorkerId: selectedWorkerId,
                              assignedWorkerName: selectedWorkerName,
                            );
                          });
                          await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Guardar Asignación'),
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

  void _showProjectDetailsModal(ProjectItem p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDetailsState) {
          // Re-obtener proyecto actualizado por si se agregaron pagos
          final currentP = _projects.firstWhere((it) => it.id == p.id, orElse: () => p);
          final balanceDue = currentP.balanceDueUsd;
          final isPaid = currentP.isFullyPaid;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera Modal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getStageLabel(currentP.status),
                            style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (currentP.deliveryDate != null)
                          Text(
                            'Entrega: ${currentP.deliveryDate!.day}/${currentP.deliveryDate!.month}/${currentP.deliveryDate!.year}',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  currentP.title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Contenido Scrolleable
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarjeta del Cliente
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentP.clientName,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (currentP.clientPhone.isNotEmpty)
                                    Text(
                                      'WhatsApp: ${currentP.clientPhone}',
                                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                                    ),
                                  if (currentP.dimensions.isNotEmpty)
                                    Text(
                                      'Medidas: ${currentP.dimensions}',
                                      style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                              if (currentP.clientPhone.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Color(0xFF10B981), size: 22),
                                  tooltip: 'Abrir WhatsApp',
                                  onPressed: () {
                                    final cleanPhone = currentP.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
                                    final msg = Uri.encodeComponent('Hola ${currentP.clientName}, le escribimos de MARKT sobre su trabajo: ${currentP.title}.');
                                    launchUrl(Uri.parse('https://wa.me/$cleanPhone?text=$msg'), mode: LaunchMode.externalApplication);
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Balance Financiero & Estado de Cuenta
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPaid ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'BALANCE DEL TRABAJO',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 0.5),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPaid ? '100% SALDADO' : 'SALDO PENDIENTE',
                                      style: TextStyle(
                                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Cotizado:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                                  Text(
                                    '\$${currentP.totalUsd.toStringAsFixed(2)} (~Bs. ${(currentP.totalUsd * rate).toStringAsFixed(2)})',
                                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Inicial / Anticipo Recibido:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                                  Text(
                                    '-\$${currentP.initialPaidUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                              if (currentP.initialPaymentMethod != null && currentP.initialPaymentMethod!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Método Inicial: ${currentP.initialPaymentMethod} ${currentP.initialPaymentReference != null ? "• Ref: ${currentP.initialPaymentReference}" : ""}',
                                    style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 11),
                                  ),
                                ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Cobrado a la Fecha:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13)),
                                  Text(
                                    '\$${currentP.totalPaidUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'CUÁNTO DEBE (SALDO RESTANTE):',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                  Text(
                                    isPaid ? '\$0.00' : '\$${balanceDue.toStringAsFixed(2)} (~Bs. ${(balanceDue * rate).toStringAsFixed(2)})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isPaid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Historial de Abonos
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Historial de Abonos (${currentP.payments.length})',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (!isPaid)
                              TextButton.icon(
                                onPressed: () => _showAddProjectPaymentDialog(currentP, () {
                                  setDetailsState(() {});
                                }),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('+ Registrar Abono', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF10B981)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (currentP.payments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                currentP.initialPaidUsd > 0
                                    ? 'Solo se ha recibido el anticipo inicial. No hay abonos posteriores.'
                                    : 'Aún no se ha registrado ningún abono para este trabajo.',
                                style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentP.payments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (ctx, idx) {
                              final pay = currentP.payments[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '+ \$${pay.amountUsd.toStringAsFixed(2)} (~Bs. ${(pay.amountUsd * rate).toStringAsFixed(2)})',
                                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          '${pay.method} • ${pay.date.day}/${pay.date.month}/${pay.date.year}',
                                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                                        ),
                                        if (pay.note.isNotEmpty)
                                          Text(
                                            pay.note,
                                            style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 10),
                                          ),
                                      ],
                                    ),
                                    const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 14),

                        // Despiece / Insumos de Fabricación
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Insumos & Costos de Fabricación (${currentP.recipe.length})',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => RecipeConfigModal(
                                    title: currentP.title,
                                    initialRecipe: currentP.recipe,
                                    availableProducts: _products,
                                    onSave: (updated, totalCost) async {
                                      final pIdx = _projects.indexWhere((it) => it.id == currentP.id);
                                      if (pIdx != -1) {
                                        setState(() {
                                          _projects[pIdx] = currentP.copyWith(recipe: updated);
                                        });
                                        await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                                        setDetailsState(() {});
                                      }
                                    },
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit, size: 14),
                              label: const Text('Editar Receta', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Costo Fabricación (Insumos + Armado):', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                                  Text('\$${currentP.totalCostUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Utilidad Neta del Aviso:', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                                  Text(
                                    '+\$${currentP.netProfitUsd.toStringAsFixed(2)} (${currentP.profitMarginPercent.toStringAsFixed(0)}% margen)',
                                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Técnico Armador
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Armador / Técnico Asignado:',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                _showAssignWorkerModal(currentP);
                              },
                              icon: const Icon(Icons.person_add, size: 14),
                              label: Text(currentP.assignedWorkerName == null ? 'Asignar' : 'Cambiar', style: const TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.handyman, size: 18, color: Color(0xFF6366F1)),
                              const SizedBox(width: 8),
                              Text(
                                currentP.assignedWorkerName ?? 'Sin Armador Asignado',
                                style: TextStyle(
                                  color: currentP.assignedWorkerName != null ? (isDark ? Colors.white : const Color(0xFF0F172A)) : const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Fotos del Proyecto
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fotos del Proyecto / Catálogo (${currentP.photos.length})',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showProjectGalleryModal(currentP),
                              icon: const Icon(Icons.photo_library, size: 14),
                              label: const Text('Gestionar Fotos', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                        _buildProjectPhotosPreview(currentP, isDark),
                        if (currentP.status != 'cancelado') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _confirmCancelProject(currentP);
                              },
                              icon: const Icon(Icons.cancel_outlined, size: 16),
                              label: const Text('Cancelar / Anular este Pedido'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _reactivateProject(currentP);
                              },
                              icon: const Icon(Icons.replay, size: 16),
                              label: const Text('Reactivar Pedido'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddProjectPaymentDialog(ProjectItem p, VoidCallback onAdded) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rate = BcvService.instance.currentRates.usd;
    final amountCtrl = TextEditingController(text: p.balanceDueUsd > 0 ? p.balanceDueUsd.toStringAsFixed(2) : '');
    final noteCtrl = TextEditingController();
    String paymentMethod = r'Efectivo USD ($)';

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registrar Abono a Proyecto',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  'Saldo pendiente actual: \$${p.balanceDueUsd.toStringAsFixed(2)}',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: r'Monto a Abonar ($ USD) *',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Método de Pago',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: r'Efectivo USD ($)', child: Text(r'Efectivo USD ($)')),
                    DropdownMenuItem(value: 'Pago Móvil (Bs.)', child: Text('Pago Móvil (Bs.)')),
                    DropdownMenuItem(value: 'Zelle (USD)', child: Text('Zelle (USD)')),
                    DropdownMenuItem(value: 'Punto de Venta / Débito', child: Text('Punto de Venta / Débito')),
                    DropdownMenuItem(value: 'Transferencia Bancaria', child: Text('Transferencia Bancaria')),
                    DropdownMenuItem(value: 'Efectivo Bs.', child: Text('Efectivo Bs.')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMethod = val);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Referencia / Banco / Nota',
                    hintText: 'ej. Ref 4829 Banco de Venezuela',
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

                      final refText = noteCtrl.text.trim();
                      final payment = ReceivablePayment(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        amountUsd: amt,
                        method: paymentMethod,
                        date: DateTime.now(),
                        note: refText.isEmpty ? 'Abono a proyecto' : refText,
                      );

                      // 1. Añadir pago a la lista del proyecto
                      final updatedPayments = List<ReceivablePayment>.from(p.payments)..add(payment);
                      final pIdx = _projects.indexWhere((it) => it.id == p.id);
                      if (pIdx != -1) {
                        final updated = _projects[pIdx].copyWith(payments: updatedPayments);
                        setState(() {
                          _projects[pIdx] = updated;
                        });
                        await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                      }

                      // 2. Ingresar el cobro a la Caja en tiempo real
                      final cashEntry = CashMovement(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        type: 'income',
                        category: 'Abono Proyecto',
                        amountUsd: amt,
                        amountBs: amt * rate,
                        method: paymentMethod,
                        description: 'Abono: ${p.title} (${p.clientName}) ${refText.isNotEmpty ? "- Ref: $refText" : ""}',
                        date: DateTime.now(),
                      );
                      final rawCash = await StorageService.instance.load('cash_movements');
                      final List<Map<String, dynamic>> cashList = [];
                      if (rawCash != null && rawCash is List) {
                        for (final item in rawCash) {
                          cashList.add(Map<String, dynamic>.from(item));
                        }
                      }
                      cashList.insert(0, cashEntry.toJson());
                      await StorageService.instance.save('cash_movements', cashList);

                      onAdded();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Abono de \$${amt.toStringAsFixed(2)} registrado en Caja con éxito.'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar Abono e Ingresar a Caja', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _advanceProjectStage(ProjectItem p) async {
    final stagesOrder = ['1_aprobacion', '2_anticipo', '3_taller', '4_sitio', '5_finalizado'];
    final currentIndex = stagesOrder.indexOf(p.status);
    final nextStage = currentIndex >= 0 && currentIndex < stagesOrder.length - 1
        ? stagesOrder[currentIndex + 1]
        : '5_finalizado';

    final index = _projects.indexWhere((item) => item.id == p.id);
    if (index != -1) {
      setState(() {
        _projects[index] = p.copyWith(status: nextStage);
      });
      await StorageService.instance.save('proyectos', _projects.map((item) => item.toJson()).toList());
      DebugLogger.instance.info('Proyecto ${p.title} avanzado a etapa $nextStage');
    }
  }

  void _confirmCancelProject(ProjectItem p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Cancelar Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas cancelar el pedido "${p.title}" del cliente ${p.clientName}?',
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
            ),
            if (p.totalPaidUsd > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tiene \${p.totalPaidUsd.toStringAsFixed(2)} USD en abonos registrados.',
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Puedes marcarlo como Cancelado (se archivará en la pestaña Cancelados) o eliminarlo definitivamente.',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Volver'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _deleteProjectPermanently(p);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
            ),
            child: const Text('Eliminar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final idx = _projects.indexWhere((x) => x.id == p.id);
              if (idx != -1) {
                setState(() {
                  _projects[idx] = p.copyWith(status: 'cancelado');
                });
                await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pedido "${p.title}" marcado como Cancelado.'),
                      backgroundColor: const Color(0xFFEF4444),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Marcar Cancelado'),
          ),
        ],
      ),
    );
  }

  void _reactivateProject(ProjectItem p) async {
    final idx = _projects.indexWhere((x) => x.id == p.id);
    if (idx != -1) {
      setState(() {
        _projects[idx] = p.copyWith(status: '1_aprobacion');
      });
      await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido "${p.title}" reactivado en etapa Aprobación.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _deleteProjectPermanently(ProjectItem p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar definitivamente?'),
        content: Text('Esta acción borrará el proyecto "${p.title}" permanentemente de la base de datos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final idx = _projects.indexWhere((x) => x.id == p.id);
      if (idx != -1) {
        setState(() {
          _projects.removeAt(idx);
        });
        await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pedido "${p.title}" eliminado definitivamente.'),
              backgroundColor: const Color(0xFF64748B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _changeDeliveryDate(ProjectItem p) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: p.deliveryDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final idx = _projects.indexWhere((x) => x.id == p.id);
      if (idx != -1) {
        setState(() {
          _projects[idx] = p.copyWith(deliveryDate: picked);
        });
        await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
      }
    }
  }

  void _shareQuotationToClient(ProjectItem p) async {
    final phone = p.clientPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final dateStr = p.deliveryDate != null
        ? '${p.deliveryDate!.day}/${p.deliveryDate!.month}/${p.deliveryDate!.year}'
        : 'A coordinar';
    final text = 'Hola ${p.clientName}, te adjuntamos la cotizacion formal de tu proyecto publicitario:\n\n'
        '*${p.title}*\n'
        'Monto Total: \$${p.totalUsd.toStringAsFixed(2)} USD\n'
        '${p.dimensions.isNotEmpty ? "Medidas: ${p.dimensions}\n" : ""}'
        'Fecha estimada de entrega: $dateStr\n'
        'Anticipo requerido para inicio: 50%\n\n'
        'Quedamos a tu orden para iniciar la produccion en taller una vez confirmado.';

    final encoded = Uri.encodeComponent(text);
    final urlStr = phone.isNotEmpty
        ? 'https://wa.me/$phone?text=$encoded'
        : 'https://api.whatsapp.com/send?text=$encoded';

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  void _showReceiveDepositDialog(ProjectItem p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suggestedDeposit = (p.totalUsd * 0.5);
    final depositCtrl = TextEditingController(text: suggestedDeposit.toStringAsFixed(2));
    String paymentMethod = r'Efectivo USD ($)';
    DateTime? deliveryDate = p.deliveryDate ?? DateTime.now().add(const Duration(days: 3));

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
                    Row(
                      children: [
                        const Icon(Icons.payments, color: Color(0xFF10B981), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Aprobar & Recibir Anticipo',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  'Proyecto: ${p.title} • Cliente: ${p.clientName}',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Presupuestado:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text(r'$' + p.totalUsd.toStringAsFixed(2), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: depositCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: r'Monto Anticipo / Inicial ($ USD) *',
                    helperText: 'El 50% recomendado es \$${suggestedDeposit.toStringAsFixed(2)}',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Metodo de Cobro en Caja',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: const [
                    DropdownMenuItem(value: r'Efectivo USD ($)', child: Text(r'Efectivo USD ($)')),
                    DropdownMenuItem(value: 'Pago Movil', child: Text('Pago Movil')),
                    DropdownMenuItem(value: 'Zelle (USD)', child: Text('Zelle (USD)')),
                    DropdownMenuItem(value: 'Punto de Venta / Tarjeta', child: Text('Punto de Venta / Tarjeta')),
                    DropdownMenuItem(value: 'Transferencia Bancaria', child: Text('Transferencia Bancaria')),
                    DropdownMenuItem(value: 'Efectivo Bs.', child: Text('Efectivo Bs.')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => paymentMethod = val);
                  },
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: deliveryDate ?? DateTime.now().add(const Duration(days: 3)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setModalState(() => deliveryDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          deliveryDate != null
                              ? 'Fecha Prometida de Entrega: ${deliveryDate!.day.toString().padLeft(2, '0')}/${deliveryDate!.month.toString().padLeft(2, '0')}/${deliveryDate!.year}'
                              : 'Definir Fecha de Entrega',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Icon(Icons.edit_calendar, size: 16, color: Color(0xFF6366F1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final depAmt = double.tryParse(depositCtrl.text) ?? 0.0;
                      if (depAmt <= 0) return;

                      // 1. Log Cash Inflow
                      final rate = BcvService.instance.currentRates.usd;
                      final cashEntry = CashMovement(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        type: 'income',
                        category: 'Anticipo Proyecto',
                        amountUsd: depAmt,
                        amountBs: depAmt * rate,
                        method: paymentMethod,
                        description: 'Anticipo inicial: ${p.title} - ${p.clientName}',
                        date: DateTime.now(),
                      );
                      final rawCash = await StorageService.instance.load('cash_movements');
                      final List<Map<String, dynamic>> cashList = [];
                      if (rawCash != null && rawCash is List) {
                        for (final item in rawCash) {
                          cashList.add(Map<String, dynamic>.from(item));
                        }
                      }
                      cashList.insert(0, cashEntry.toJson());
                      await StorageService.instance.save('cash_movements', cashList);

                      // 2. If remainder > 0, register or update receivable
                      final remainder = p.totalUsd - depAmt;
                      if (remainder > 0.01) {
                        final rawRec = await StorageService.instance.load('receivables');
                        final List<Map<String, dynamic>> recList = [];
                        if (rawRec != null && rawRec is List) {
                          for (final item in rawRec) {
                            recList.add(Map<String, dynamic>.from(item));
                          }
                        }
                        final rec = ReceivableAccount(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          clientName: p.clientName,
                          clientPhone: p.clientPhone,
                          concept: 'Proyecto: ${p.title} (Anticipo: \$${depAmt.toStringAsFixed(2)})',
                          totalUsd: p.totalUsd,
                          payments: [
                            ReceivablePayment(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              amountUsd: depAmt,
                              method: paymentMethod,
                              date: DateTime.now(),
                              note: 'Anticipo inicial recibido',
                            ),
                          ],
                          dueDate: deliveryDate ?? DateTime.now().add(const Duration(days: 7)),
                          createdAt: DateTime.now(),
                        );
                        recList.insert(0, rec.toJson());
                        await StorageService.instance.save('receivables', recList);
                      }

                      // 3. Advance project to '3_taller'
                      final idx = _projects.indexWhere((x) => x.id == p.id);
                      if (idx != -1) {
                        setState(() {
                          _projects[idx] = p.copyWith(
                            status: '3_taller',
                            deliveryDate: deliveryDate,
                          );
                        });
                        await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Anticipo de \$${depAmt.toStringAsFixed(2)} registrado en Caja. Proyecto enviado a Armado Taller.'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmar Anticipo e Iniciar Taller', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImageDialog(String path) {
    final file = File(path);
    if (!file.existsSync()) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(file, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showProjectGalleryModal(ProjectItem p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setGalleryState) {
          final currentPhotos = p.photos;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
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
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Color(0xFF6366F1), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Fotos del Proyecto / Catalogo',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                Text(
                  '${p.title} • ${p.clientName} (${currentPhotos.length} fotos guardadas)',
                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 14),

                // Boton Agregar / Tomar Fotos
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final files = await FilePicker.pickFiles(
                          type: FileType.image,
                        );
                        if (files.isNotEmpty) {
                          final List<String> newPaths = List.from(p.photos);
                          for (final f in files) {
                            if (f.path != null) {
                              final saved = await StorageService.instance.saveProjectPhoto(f.path!);
                              if (saved != null) {
                                newPaths.add(saved.path);
                              }
                            }
                          }
                          final idx = _projects.indexWhere((x) => x.id == p.id);
                          if (idx != -1) {
                            final updated = p.copyWith(photos: newPaths);
                            setState(() {
                              _projects[idx] = updated;
                            });
                            p = updated;
                            setGalleryState(() {});
                            await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                          }
                        }
                      } catch (e) {
                        DebugLogger.instance.error('Error al seleccionar fotos: $e');
                      }
                    },
                    icon: const Icon(Icons.add_a_photo, size: 18),
                    label: const Text('Tomar o Subir Fotos al Catalogo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Grid de Fotos
                Expanded(
                  child: currentPhotos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_album_outlined, size: 48, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              const SizedBox(height: 8),
                              Text(
                                'Aun no has agregado fotos a este trabajo.',
                                style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sube fotos del resultado final para mostrarselas como catalogo a nuevos clientes.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8), fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          itemCount: currentPhotos.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemBuilder: (ctx, idx) {
                            final photoPath = currentPhotos[idx];
                            final photoFile = File(photoPath);

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  GestureDetector(
                                    onTap: () => _showFullImageDialog(photoPath),
                                    child: photoFile.existsSync()
                                        ? Image.file(
                                            photoFile,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                            child: const Center(
                                              child: Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                  ),
                                  // Boton eliminar foto
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () async {
                                        final List<String> updatedPhotos = List.from(p.photos)..removeAt(idx);
                                        final pIdx = _projects.indexWhere((x) => x.id == p.id);
                                        if (pIdx != -1) {
                                          final updated = p.copyWith(photos: updatedPhotos);
                                          setState(() {
                                            _projects[pIdx] = updated;
                                          });
                                          p = updated;
                                          setGalleryState(() {});
                                          await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.delete, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                  // Boton compartir
                                  Positioned(
                                    bottom: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        if (photoFile.existsSync()) {
                                          SharePlus.instance.share(
                                            ShareParams(
                                              files: [XFile(photoPath)],
                                              text: 'Proyecto: ${p.title} - ${p.clientName}',
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.share, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeliveryBadge(ProjectItem p, bool isDark) {
    if (p.deliveryDate == null) {
      return InkWell(
        onTap: () => _changeDeliveryDate(p),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              const SizedBox(width: 4),
              Text(
                '+ Fecha Entrega',
                style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final days = p.daysUntilDelivery!;
    final isCompleted = p.status == '5_finalizado';

    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (isCompleted) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.15);
      fg = const Color(0xFF10B981);
      label = 'Entregado: ${p.deliveryDate!.day}/${p.deliveryDate!.month}';
      icon = Icons.check_circle_outline;
    } else if (days < 0) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      fg = const Color(0xFFEF4444);
      label = 'Vencido: hace ${-days} d (${p.deliveryDate!.day}/${p.deliveryDate!.month})';
      icon = Icons.warning_amber_rounded;
    } else if (days == 0) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.18);
      fg = const Color(0xFFF59E0B);
      label = 'Entrega HOY (${p.deliveryDate!.day}/${p.deliveryDate!.month})';
      icon = Icons.alarm;
    } else if (days == 1) {
      bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      fg = const Color(0xFFF59E0B);
      label = 'Entrega Manana (${p.deliveryDate!.day}/${p.deliveryDate!.month})';
      icon = Icons.schedule;
    } else {
      bg = const Color(0xFF0284C7).withValues(alpha: 0.15);
      fg = const Color(0xFF38BDF8);
      label = 'Entrega: ${p.deliveryDate!.day}/${p.deliveryDate!.month} (en $days d)';
      icon = Icons.event;
    }

    return InkWell(
      onTap: () => _changeDeliveryDate(p),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectPhotosPreview(ProjectItem p, bool isDark) {
    if (p.photos.isEmpty) {
      return InkWell(
        onTap: () => _showProjectGalleryModal(p),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                '+ Fotos de este Trabajo (Catalogo)',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Text(
                    'Fotos en Catalogo (${p.photos.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showProjectGalleryModal(p),
                child: const Text(
                  'Ver / Gestionar',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.photos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (ctx, idx) {
                if (idx == p.photos.length) {
                  return InkWell(
                    onTap: () => _showProjectGalleryModal(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                      ),
                      child: const Center(
                        child: Icon(Icons.add, size: 18, color: Color(0xFF6366F1)),
                      ),
                    ),
                  );
                }

                final filePath = p.photos[idx];
                final file = File(filePath);
                return GestureDetector(
                  onTap: () => _showFullImageDialog(filePath),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: file.existsSync()
                          ? Image.file(file, fit: BoxFit.cover)
                          : Container(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                              child: const Icon(Icons.image, size: 16),
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final totalValue = _projects.fold(0.0, (acc, p) => acc + p.totalUsd);
    final inProgressCount = _projects.where((p) => p.status != '5_finalizado').length;

    return Column(
      children: [
        // Métricas de Embudo (V4 Stitch)
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
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.folder_shared, color: Color(0xFF818CF8), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Embudo Operativo',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$inProgressCount en curso • \$${totalValue.toStringAsFixed(2)} total',
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
                    onPressed: _showAddProjectDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nuevo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Carrusel de Etapas
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _stages.map((st) {
                    final isSelected = _selectedStage == st['id'];
                    final count = st['id'] == 'all'
                        ? _projects.length
                        : _projects.where((p) => p.status == st['id']).length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedStage = st['id']),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF818CF8)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                st['icon'] as IconData,
                                size: 14,
                                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${st['name']} ($count)',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Lista de Proyectos Filtrados
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : _filteredProjects.isEmpty
                  ? Center(
                      child: Text(
                        'Sin proyectos en esta etapa.',
                        style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredProjects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = _filteredProjects[i];
                        final isCompleted = p.status == '5_finalizado';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCompleted
                                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                              : const Color(0xFF6366F1).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getStageLabel(p.status),
                                          style: TextStyle(
                                            color: isCompleted ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      _buildDeliveryBadge(p, isDark),
                                    ],
                                  ),
                                  Row(
                                    children:
                                      [
                                        Text(
                                          '\${p.totalUsd.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: p.status == 'cancelado' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration: p.status == 'cancelado' ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onSelected: (val) {
                                            if (val == 'cancel') {
                                              _confirmCancelProject(p);
                                            } else if (val == 'reactivate') {
                                              _reactivateProject(p);
                                            } else if (val == 'delete') {
                                              _deleteProjectPermanently(p);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            if (p.status != 'cancelado')
                                              const PopupMenuItem(
                                                value: 'cancel',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 16),
                                                    SizedBox(width: 8),
                                                    Text('Cancelar Pedido', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            if (p.status == 'cancelado') ...[
                                              const PopupMenuItem(
                                                value: 'reactivate',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.replay, color: Color(0xFF10B981), size: 16),
                                                    SizedBox(width: 8),
                                                    Text('Reactivar Pedido', style: TextStyle(color: Color(0xFF10B981), fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 16),
                                                    SizedBox(width: 8),
                                                    Text('Eliminar Definitivamente', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.title,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (p.dimensions.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.straighten, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Medidas: ${p.dimensions}',
                                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                              if (p.recipe.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => RecipeConfigModal(
                                        title: p.title,
                                        initialRecipe: p.recipe,
                                        availableProducts: _products,
                                        onSave: (updated, totalCost) async {
                                          final idx = _projects.indexWhere((item) => item.id == p.id);
                                          if (idx != -1) {
                                            setState(() {
                                              _projects[idx] = p.copyWith(recipe: updated);
                                            });
                                            await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.architecture, size: 12, color: Color(0xFF6366F1)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${p.recipe.length} insumos/servicios • Costo: \$${p.totalCostUsd.toStringAsFixed(2)} • Margen: ${p.profitMarginPercent.toStringAsFixed(0)}%',
                                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit, size: 10, color: Color(0xFF818CF8)),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => RecipeConfigModal(
                                        title: p.title,
                                        initialRecipe: const [],
                                        availableProducts: _products,
                                        onSave: (updated, totalCost) async {
                                          final idx = _projects.indexWhere((item) => item.id == p.id);
                                          if (idx != -1) {
                                            setState(() {
                                              _projects[idx] = p.copyWith(recipe: updated);
                                            });
                                            await StorageService.instance.save('proyectos', _projects.map((x) => x.toJson()).toList());
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_circle_outline, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '+ Asignar Insumos y Costos (BOM)',
                                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              // Status de Armador / Mano de Obra
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _showAssignWorkerModal(p),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: p.isAssemblyReady
                                        ? (p.assemblyPaid
                                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                            : const Color(0xFF10B981).withValues(alpha: 0.22))
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: p.isAssemblyReady
                                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        p.isAssemblyReady
                                            ? (p.assemblyPaid ? Icons.check_circle : Icons.monetization_on)
                                            : Icons.handyman,
                                        size: 13,
                                        color: p.isAssemblyReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          p.isAssemblyReady
                                              ? (p.assemblyPaid
                                                  ? 'Armado Liquidado: \$${p.effectiveAssemblyFeeUsd.toStringAsFixed(2)} • ${p.assignedWorkerName ?? "Personal"}'
                                                  : 'Mano de Obra Lista p/ Pago: \$${p.effectiveAssemblyFeeUsd.toStringAsFixed(2)} • ${p.assignedWorkerName ?? "Por Asignar"}')
                                              : (p.effectiveAssemblyFeeUsd > 0
                                                  ? 'Armado en Taller (Por Procesar): \$${p.effectiveAssemblyFeeUsd.toStringAsFixed(2)} • ${p.assignedWorkerName ?? "Sin Asignar"}'
                                                  : '+ Asignar Armador / Mano de Obra'),
                                          style: TextStyle(
                                            color: p.isAssemblyReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.edit,
                                        size: 11,
                                        color: p.isAssemblyReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Fila de Estado de Pago (Abonado vs Saldo Deudor)
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _showProjectDetailsModal(p),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: p.isFullyPaid
                                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: p.isFullyPaid
                                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        p.isFullyPaid ? Icons.check_circle : Icons.account_balance_wallet,
                                        size: 12,
                                        color: p.isFullyPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        p.isFullyPaid
                                            ? 'Pagado 100% (\$${p.totalUsd.toStringAsFixed(2)})'
                                            : 'Abonado: \$${p.totalPaidUsd.toStringAsFixed(2)} • Resta: \$${p.balanceDueUsd.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: p.isFullyPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Fotos del Proyecto / Catalogo
                              _buildProjectPhotosPreview(p, isDark),
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.person_outline, size: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        p.clientName,
                                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showProjectDetailsModal(p),
                                    icon: const Icon(Icons.receipt_long, size: 13),
                                    label: const Text('Ver Detalles', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF6366F1),
                                      side: const BorderSide(color: Color(0xFF6366F1), width: 1),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (p.status == 'cancelado') ...[
                                    TextButton.icon(
                                      onPressed: () => _reactivateProject(p),
                                      icon: const Icon(Icons.replay, size: 14, color: Color(0xFF10B981)),
                                      label: const Text('Reactivar Pedido', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                    ),
                                  ] else if (p.status == '1_aprobacion' || p.status == '2_anticipo') ...[
                                    Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Enviar Cotizacion por WhatsApp',
                                          icon: const Icon(Icons.share, size: 18, color: Color(0xFF10B981)),
                                          onPressed: () => _shareQuotationToClient(p),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () => _showReceiveDepositDialog(p),
                                          icon: const Icon(Icons.payments, size: 13),
                                          label: const Text('Recibir Inicial', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (!isCompleted) ...[
                                    TextButton.icon(
                                      onPressed: () => _advanceProjectStage(p),
                                      icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF38BDF8)),
                                      label: Text(
                                        p.status == '3_taller' ? 'Avanzar a En Sitio' : 'Finalizar y Entregar',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ] else ...[
                                    Row(
                                      children: [
                                        const Icon(Icons.verified, size: 15, color: Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        const Text('Completado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                      ],
                                    ),
                                  ],
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

  String _getStageLabel(String status) {
    switch (status) {
      case '1_aprobacion':
        return '1. Aprobacion';
      case '2_anticipo':
        return '2. Anticipo Pagado';
      case '3_taller':
        return '3. Armado Taller';
      case '4_sitio':
        return '4. En Sitio';
      case '5_finalizado':
        return '5. Entregado';
      case 'catalogo':
        return 'Catalogo';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }
}
