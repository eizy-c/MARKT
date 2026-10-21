import 'package:flutter/material.dart';
import '../models/app_models.dart';

class InvoiceDetailModal extends StatelessWidget {
  final Invoice invoice;

  const InvoiceDetailModal({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior del modal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Comprobante / Ticket',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // FORMATO DEL TICKET / FACTURA
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Encabezado Empresa
                    Text(
                      invoice.business.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RIF: ${invoice.business.rif}',
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                    ),
                    Text(
                      'Telf: ${invoice.business.phone} • ${invoice.business.address}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    const Divider(thickness: 1, height: 1),
                    const SizedBox(height: 10),

                    // Folio y Fecha Automática
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FOLIO: ${invoice.folio}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6366F1)),
                        ),
                        Text(
                          '${invoice.date.day.toString().padLeft(2, '0')}/${invoice.date.month.toString().padLeft(2, '0')}/${invoice.date.year} ${invoice.date.hour.toString().padLeft(2, '0')}:${invoice.date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Vendedor
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VENDEDOR: ${invoice.seller.name}',
                          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'TASA BCV: Bs. ${invoice.rateBcv.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(thickness: 1, height: 1),
                    const SizedBox(height: 10),

                    // Datos del Cliente Completo
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DATOS DEL CLIENTE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF818CF8))),
                          const SizedBox(height: 2),
                          Text('Nombre: ${invoice.client.fullName}', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('C.I. / RIF: ${invoice.client.docId.isNotEmpty ? invoice.client.docId : 'N/A'}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                          if (invoice.client.phone.isNotEmpty)
                            Text('WhatsApp: ${invoice.client.phone}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                          if (invoice.client.address.isNotEmpty)
                            Text('Dirección: ${invoice.client.address}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(thickness: 1, height: 1),
                    const SizedBox(height: 10),

                    // Artículos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DESCRIPCIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...invoice.items.map((it) {
                      final itemBs = it.totalUsd * invoice.rateBcv;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${it.quantity}x ${it.product.name}',
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${it.totalUsd.toStringAsFixed(2)}',
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Bs. ${itemBs.toStringAsFixed(2)}',
                                  style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Divider(thickness: 1, height: 1),
                    const SizedBox(height: 10),

                    // Totales Duales USD y Bs.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL USD:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        Text('\$${invoice.totalUsd.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL EN BS:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('Bs. ${invoice.totalBs.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Forma de Pago:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(invoice.paymentMethod, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),

                    if (invoice.business.showSignatureLine) ...[
                      const SizedBox(height: 24),
                      Container(width: 140, height: 1, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                      const SizedBox(height: 4),
                      Text('Firma Conforme', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      invoice.business.warrantyNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Cerrar'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Comprobante enviado / listo para imprimir')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Imprimir Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
