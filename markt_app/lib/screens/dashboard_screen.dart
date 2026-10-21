import 'package:flutter/material.dart';
import '../services/bcv_service.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de bienvenida
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'MARTK POS & GESTIÓN',
                      style: TextStyle(
                        color: Color(0xFFC7D2FE),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Panel de Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sistema nativo en Flutter con tema Dark AMOLED.',
                  style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 13),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<BcvRates>(
                  valueListenable: BcvService.instance.ratesNotifier,
                  builder: (context, rates, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: rates.isLive ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF475569),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.currency_exchange,
                                    size: 14,
                                    color: rates.isLive ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    rates.isLive ? 'TASA OFICIAL BCV DEL DÍA (EN VIVO)' : 'TASA OFICIAL BCV (REFERENCIA)',
                                    style: TextStyle(
                                      color: rates.isLive ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '1 USD = Bs. ${rates.usd.toStringAsFixed(2)}  •  1 EUR = Bs. ${rates.eur.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.sync, color: Color(0xFF818CF8), size: 18),
                            tooltip: 'Actualizar Tasa',
                            onPressed: () => BcvService.instance.fetchRates(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => onNavigate(1), // Go to POS
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Iniciar Venta POS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // KPIs Grid
          const Text(
            'Métricas Clave',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _buildMetricCard(
                title: 'Ventas de Hoy',
                amount: '\$0.00',
                icon: Icons.payments,
                color: const Color(0xFF10B981),
                onTap: () => onNavigate(1),
              ),
              _buildMetricCard(
                title: 'Saldo en Caja',
                amount: '\$0.00',
                icon: Icons.account_balance_wallet,
                color: const Color(0xFF38BDF8),
                onTap: () => onNavigate(2),
              ),
              _buildMetricCard(
                title: 'Proyectos Activos',
                amount: '0',
                icon: Icons.assignment,
                color: const Color(0xFFF59E0B),
                onTap: () => onNavigate(3),
              ),
              _buildMetricCard(
                title: 'Inventario',
                amount: '0 prod.',
                icon: Icons.inventory_2,
                color: const Color(0xFFA855F7),
                onTap: () => onNavigate(4),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Acciones Rápidas
          const Text(
            'Acceso Rápido',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildQuickTile(
            icon: Icons.point_of_sale,
            title: 'Terminal de Cobro Rápido (POS)',
            subtitle: 'Generación de recibos y facturación',
            color: const Color(0xFF6366F1),
            onTap: () => onNavigate(1),
          ),
          const SizedBox(height: 8),
          _buildQuickTile(
            icon: Icons.account_balance_wallet,
            title: 'Libro de Caja y Movimientos',
            subtitle: 'Registro de ingresos y egresos de efectivo',
            color: const Color(0xFF10B981),
            onTap: () => onNavigate(2),
          ),
          const SizedBox(height: 8),
          _buildQuickTile(
            icon: Icons.folder,
            title: 'Pedidos y Proyectos en Curso',
            subtitle: 'Control de estados y entregas',
            color: const Color(0xFFF59E0B),
            onTap: () => onNavigate(3),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
              ],
            ),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF475569)),
          ],
        ),
      ),
    );
  }
}
