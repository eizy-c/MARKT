import 'package:flutter/material.dart';
import '../models/app_models.dart';
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
    _loadData();
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
    {'id': '1_aprobacion', 'name': '1. Aprobación', 'icon': Icons.assignment_outlined},
    {'id': '2_anticipo', 'name': '2. Pago Anticipo', 'icon': Icons.payments_outlined},
    {'id': '3_taller', 'name': '3. Armado Taller', 'icon': Icons.precision_manufacturing_outlined},
    {'id': '4_sitio', 'name': '4. En Sitio', 'icon': Icons.engineering_outlined},
    {'id': '5_finalizado', 'name': '5. Entregado', 'icon': Icons.verified_outlined},
  ];

  List<ProjectItem> get _filteredProjects {
    if (_selectedStage == 'all') return _projects;
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
                  children: _stages.where((s) => s['id'] != 'all').map((s) {
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
    final feeCtrl = TextEditingController(text: p.effectiveAssemblyFeeUsd > 0 ? p.effectiveAssemblyFeeUsd.toStringAsFixed(2) : '');

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
                        'Asignar Armador & Mano de Obra',
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: feeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: r'Monto Mano de Obra Armado ($ USD)',
                      helperText: 'Se desbloquea al finalizar/procesar el trabajo.',
                      prefixIcon: const Icon(Icons.attach_money, size: 18),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        final fee = double.tryParse(feeCtrl.text) ?? 0.0;
                        final idx = _projects.indexWhere((it) => it.id == p.id);
                        if (idx != -1) {
                          setState(() {
                            _projects[idx] = p.copyWith(
                              assignedWorkerId: selectedWorkerId,
                              assignedWorkerName: selectedWorkerName,
                              assemblyFeeUsd: fee,
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
                                  Text(
                                    '\$${p.totalUsd.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
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
                                  if (!isCompleted)
                                    TextButton.icon(
                                      onPressed: () => _advanceProjectStage(p),
                                      icon: const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF38BDF8)),
                                      label: const Text('Avanzar Etapa', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8))),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  String _getStageLabel(String status) {
    switch (status) {
      case '1_aprobacion':
        return '1. Aprobación';
      case '2_anticipo':
        return '2. Anticipo Pagado';
      case '3_taller':
        return '3. Armado Taller';
      case '4_sitio':
        return '4. En Sitio';
      case '5_finalizado':
        return '5. Entregado';
      default:
        return status;
    }
  }
}
