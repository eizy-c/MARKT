import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF020617),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/icon/logo.png',
                    width: 46,
                    height: 46,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MARTK POS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gestión & Punto de Venta',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              children: [
                _buildDrawerItem(
                  context,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  title: 'Panel Principal',
                ),
                _buildDrawerItem(
                  context,
                  index: 1,
                  icon: Icons.point_of_sale_outlined,
                  activeIcon: Icons.point_of_sale,
                  title: 'Terminal POS (Ventas)',
                ),
                _buildDrawerItem(
                  context,
                  index: 2,
                  icon: Icons.account_balance_wallet_outlined,
                  activeIcon: Icons.account_balance_wallet,
                  title: 'Libro de Caja',
                ),
                _buildDrawerItem(
                  context,
                  index: 3,
                  icon: Icons.request_quote_outlined,
                  activeIcon: Icons.request_quote,
                  title: 'Cuentas por Cobrar',
                ),
                _buildDrawerItem(
                  context,
                  index: 4,
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights,
                  title: 'Analítica Financiera',
                ),
                _buildDrawerItem(
                  context,
                  index: 5,
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder,
                  title: 'Proyectos & Pedidos',
                ),
                _buildDrawerItem(
                  context,
                  index: 6,
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2,
                  title: 'Inventario de Productos',
                ),
                _buildDrawerItem(
                  context,
                  index: 7,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  title: 'Clientes',
                ),
                const Divider(color: Color(0xFF1E293B), height: 24),
                _buildDrawerItem(
                  context,
                  index: 8,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  title: 'Configuración & Tasas',
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Nativo Flutter Dark',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String title,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? const BorderSide(color: Color(0xFF6366F1), width: 1)
              : BorderSide.none,
        ),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
            size: 20,
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          onTap: () {
            Navigator.of(context).pop();
            onDestinationSelected(index);
          },
        ),
      ),
    );
  }
}
