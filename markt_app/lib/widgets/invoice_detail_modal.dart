import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
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

                    // Título Dinámico de Comprobante
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getVoucherColor(invoice.voucherType).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getVoucherTitle(invoice.voucherType),
                        style: TextStyle(
                          color: _getVoucherColor(invoice.voucherType),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Folio y Fecha Automática
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FOLIO: ${invoice.folio}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _getVoucherColor(invoice.voucherType)),
                        ),
                        Text(
                          '${invoice.date.day.toString().padLeft(2, '0')}/${invoice.date.month.toString().padLeft(2, '0')}/${invoice.date.year} ${invoice.date.hour.toString().padLeft(2, '0')}:${invoice.date.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Vendedor y Tasa
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VENDEDOR: ${invoice.seller.name}',
                          style: TextStyle(color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'TASA ${invoice.rateCurrency}: Bs. ${invoice.rateBcv.toStringAsFixed(2)}',
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

                    // CONDICIONES ESPECÍFICAS DE PRESUPUESTO / COTIZACIÓN
                    if (invoice.voucherType == 'cotizacion') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Vigencia del Presupuesto:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                Text('${invoice.validityDays} DÍAS HÁBILES', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0284C7))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Inicial Requerida (${invoice.requiredDownPaymentPercent.toStringAsFixed(0)}%):', style: const TextStyle(fontSize: 11)),
                                Text('\$${invoice.requiredDownPaymentAmountUsd.toStringAsFixed(2)} (Bs. ${(invoice.requiredDownPaymentAmountUsd * invoice.rateBcv).toStringAsFixed(2)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Estado de la Inicial:', style: TextStyle(fontSize: 11)),
                                Text(
                                  invoice.isInitialPaid ? 'PAGADA / EN TALLER' : 'PENDIENTE POR PAGAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: invoice.isInitialPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                            if (invoice.isInitialPaid) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Saldo Restante contra Entrega:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Text(
                                    '\$${invoice.remainingBalanceUsd.toStringAsFixed(2)} (Bs. ${(invoice.remainingBalanceUsd * invoice.rateBcv).toStringAsFixed(2)})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Forma de Pago:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(invoice.paymentMethod, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (invoice.bankName != null && invoice.bankName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Banco Destino:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          Text(invoice.bankName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                        ],
                      ),
                    ],
                    if (invoice.paymentReference != null && invoice.paymentReference!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Referencia / Ref:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          Text(invoice.paymentReference!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                    ],

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
              const SizedBox(height: 18),
              // Botones de Acción de Comprobante (Imprimir PDF, Compartir PDF y Enviar a WhatsApp)
              Column(
                children: [
                  Row(
                    children: [
                      // Botón WhatsApp Directo
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sendToWhatsApp(context),
                          icon: const Icon(Icons.chat, size: 18),
                          label: const Text('Enviar WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón Imprimir / PDF
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _printOrSavePdf(context),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Descargar PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // Botón Compartir Archivo
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _sharePdfFile(context),
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Compartir Archivo'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(color: Color(0xFF6366F1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botón Cerrar
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cerrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<pw.Document> _buildPdfDocument() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                invoice.business.name.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text('RIF: ${invoice.business.rif}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Telf: ${invoice.business.phone}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(invoice.business.address, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
              pw.Divider(thickness: 0.5),
              pw.Text(
                _getVoucherTitle(invoice.voucherType),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('FOLIO: ${invoice.folio}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.Text(
                    '${invoice.date.day.toString().padLeft(2, '0')}/${invoice.date.month.toString().padLeft(2, '0')}/${invoice.date.year}',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Vendedor: ${invoice.seller.name}', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('Tasa: Bs. ${invoice.rateBcv.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CLIENTE: ${invoice.client.fullName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    pw.Text('CI/RIF: ${invoice.client.docId.isNotEmpty ? invoice.client.docId : "N/A"}', style: const pw.TextStyle(fontSize: 8)),
                    if (invoice.client.phone.isNotEmpty)
                      pw.Text('Telf: ${invoice.client.phone}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
              pw.Divider(thickness: 0.5),
              ...invoice.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text('${item.quantity}x ${item.product.name}', style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Text('\$${item.totalUsd.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      ],
                    ),
                  )),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL USD:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('\$${invoice.totalUsd.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL BS.:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text('Bs. ${invoice.totalBs.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              if (invoice.paymentMethod.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Pago: ${invoice.paymentMethod}', style: const pw.TextStyle(fontSize: 8)),
              ],
              pw.SizedBox(height: 10),
              pw.Text(invoice.business.warrantyNote, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 6)),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  Future<void> _printOrSavePdf(BuildContext context) async {
    try {
      final pdf = await _buildPdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Ticket_${invoice.folio}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar PDF: $e')),
        );
      }
    }
  }

  Future<void> _sharePdfFile(BuildContext context) async {
    try {
      final pdf = await _buildPdfDocument();
      final bytes = await pdf.save();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/Ticket_${invoice.folio}.pdf');
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Comprobante ${invoice.folio}',
          text: 'Comprobante ${invoice.folio} de ${invoice.business.name}',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir comprobante: $e')),
        );
      }
    }
  }

  Future<void> _sendToWhatsApp(BuildContext context) async {
    final clientPhone = invoice.client.phone.replaceAll(RegExp(r'[^0-9]'), '');
    String phoneParam = clientPhone;
    if (phoneParam.startsWith('0')) {
      phoneParam = '58${phoneParam.substring(1)}';
    } else if (!phoneParam.startsWith('58') && phoneParam.length == 10) {
      phoneParam = '58$phoneParam';
    }

    final buffer = StringBuffer();
    buffer.writeln('*${invoice.business.name.toUpperCase()}*');
    buffer.writeln('RIF: ${invoice.business.rif}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*${_getVoucherTitle(invoice.voucherType)}*');
    buffer.writeln('Folio: *${invoice.folio}*');
    buffer.writeln('Fecha: ${invoice.date.day.toString().padLeft(2, '0')}/${invoice.date.month.toString().padLeft(2, '0')}/${invoice.date.year}');
    buffer.writeln('Cliente: ${invoice.client.fullName}');
    if (invoice.client.docId.isNotEmpty) {
      buffer.writeln('CI/RIF: ${invoice.client.docId}');
    }
    buffer.writeln('Vendedor: ${invoice.seller.name}');
    buffer.writeln('Tasa BCV: Bs. ${invoice.rateBcv.toStringAsFixed(2)}');
    buffer.writeln('--------------------------------');
    buffer.writeln('*DETALLE DE PRODUCTOS:*');
    for (final item in invoice.items) {
      buffer.writeln('• ${item.quantity}x ${item.product.name} = \$${item.totalUsd.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('*TOTAL A PAGAR:*');
    buffer.writeln('USD: *\$${invoice.totalUsd.toStringAsFixed(2)}*');
    buffer.writeln('Bs.: *Bs. ${invoice.totalBs.toStringAsFixed(2)}*');
    if (invoice.paymentMethod.isNotEmpty) {
      buffer.writeln('Forma de Pago: ${invoice.paymentMethod}');
    }
    buffer.writeln('--------------------------------');
    buffer.writeln(invoice.business.warrantyNote);

    final encodedText = Uri.encodeComponent(buffer.toString());
    final urlStr = phoneParam.isNotEmpty
        ? 'https://wa.me/$phoneParam?text=$encodedText'
        : 'https://wa.me/?text=$encodedText';

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    }
  }

  String _getVoucherTitle(String type) {
    switch (type.toLowerCase()) {
      case 'cotizacion':
        return 'PRESUPUESTO / COTIZACIÓN';
      case 'egreso':
        return 'COMPROBANTE DE EGRESO DE CAJA';
      case 'abono':
        return 'RECIBO DE CAJA / ABONO A CUENTA';
      case 'factura':
      default:
        return 'FACTURA DE VENTA DIRECTA';
    }
  }

  Color _getVoucherColor(String type) {
    switch (type.toLowerCase()) {
      case 'cotizacion':
        return const Color(0xFF38BDF8); // Azul celeste
      case 'egreso':
        return const Color(0xFFEF4444); // Rojo
      case 'abono':
        return const Color(0xFFF59E0B); // Ámbar / Dorado
      case 'factura':
      default:
        return const Color(0xFF10B981); // Verde esmeralda
    }
  }
}
