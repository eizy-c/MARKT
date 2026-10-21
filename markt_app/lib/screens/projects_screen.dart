import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final List<ProjectItem> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
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
        final defaults = [
          ProjectItem(
            id: '1',
            title: 'Aviso Luminoso Neón Flex - Café París',
            clientName: 'Inversiones París C.A.',
            totalUsd: 180.0,
            status: 'in_progress',
            date: DateTime.now(),
          ),
          ProjectItem(
            id: '2',
            title: 'Corte CNC Acrílico 5mm Trofeos',
            clientName: 'Colegio de Médicos',
            totalUsd: 95.0,
            status: 'completed',
            date: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ];
        setState(() {
          _projects.addAll(defaults);
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
    final totalController = TextEditingController();
    String stage = '1_aprobacion';

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
              TextField(
                controller: clientController,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Nombre del Cliente / Empresa',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: totalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Presupuesto Total (\$ USD)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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

                    final newP = ProjectItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: titleController.text.trim(),
                      clientName: clientController.text.trim().isEmpty ? 'Cliente Ocasional' : clientController.text.trim(),
                      totalUsd: amt,
                      status: stage,
                      date: DateTime.now(),
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
        _projects[index] = ProjectItem(
          id: p.id,
          title: p.title,
          clientName: p.clientName,
          totalUsd: p.totalUsd,
          status: nextStage,
          date: p.date,
        );
      });
      await StorageService.instance.save('proyectos', _projects.map((item) => item.toJson()).toList());
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
                              const SizedBox(height: 6),
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
