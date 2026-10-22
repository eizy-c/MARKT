import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';
import '../services/bcv_service.dart';
import '../services/theme_service.dart';
import '../models/app_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController bcvUsdCtrl;
  late final TextEditingController bcvEurCtrl;

  // Datos del Negocio
  final businessNameCtrl = TextEditingController(text: '');
  final rifCtrl = TextEditingController(text: '');
  final phoneCtrl = TextEditingController(text: '');
  final addressCtrl = TextEditingController(text: '');
  final warrantyNoteCtrl = TextEditingController(
    text: 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.',
  );
  final folioCtrl = TextEditingController(text: '0');

  // Opciones de Impresión
  bool showQrPagoMovil = true;
  bool showBarcode = true;
  bool showSignatureLine = true;
  bool showIvaBreakdown = false;
  String ticketTheme = 'pos_termico';

  // Cuentas Bancarias del Negocio
  final List<BankAccount> _bankAccounts = [];

  // Vendedores del Negocio
  final List<Seller> _sellers = [];

  @override
  void initState() {
    super.initState();
    final rates = BcvService.instance.currentRates;
    bcvUsdCtrl = TextEditingController(text: rates.usd.toStringAsFixed(2));
    bcvEurCtrl = TextEditingController(text: rates.eur.toStringAsFixed(2));

    BcvService.instance.ratesNotifier.addListener(_onRatesUpdated);
    _loadSavedBusinessProfile();
    _loadBankAccounts();
    _loadSellers();
  }

  Future<void> _loadSellers() async {
    try {
      final raw = await StorageService.instance.load('sellers');
      if (raw != null && raw is List) {
        setState(() {
          _sellers.clear();
          for (final s in raw) {
            _sellers.add(Seller.fromJson(Map<String, dynamic>.from(s)));
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBankAccounts() async {
    try {
      final raw = await StorageService.instance.load('bank_accounts');
      if (raw != null && raw is List) {
        setState(() {
          _bankAccounts.clear();
          for (final b in raw) {
            _bankAccounts.add(BankAccount.fromJson(Map<String, dynamic>.from(b)));
          }
        });
      } else {
        setState(() => _bankAccounts.clear());
      }
    } catch (_) {}
  }

  Future<void> _loadSavedBusinessProfile() async {
    try {
      final raw = await StorageService.instance.load('business_profile');
      if (raw != null && raw is Map<String, dynamic>) {
        final bp = BusinessProfile.fromJson(raw);
        setState(() {
          businessNameCtrl.text = bp.name;
          rifCtrl.text = bp.rif;
          phoneCtrl.text = bp.phone;
          addressCtrl.text = bp.address;
          warrantyNoteCtrl.text = bp.warrantyNote;
          folioCtrl.text = bp.folioCounter.toString();
          showQrPagoMovil = bp.showQrPagoMovil;
          showBarcode = bp.showBarcode;
          showSignatureLine = bp.showSignatureLine;
          showIvaBreakdown = bp.showIvaBreakdown;
          ticketTheme = bp.ticketTheme;
        });
      }
    } catch (_) {}
  }

  void _onRatesUpdated() {
    final rates = BcvService.instance.currentRates;
    bcvUsdCtrl.text = rates.usd.toStringAsFixed(2);
    bcvEurCtrl.text = rates.eur.toStringAsFixed(2);
  }

  @override
  void dispose() {
    BcvService.instance.ratesNotifier.removeListener(_onRatesUpdated);
    bcvUsdCtrl.dispose();
    bcvEurCtrl.dispose();
    businessNameCtrl.dispose();
    rifCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    warrantyNoteCtrl.dispose();
    folioCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAllSettings() async {
    final bp = BusinessProfile(
      name: businessNameCtrl.text.trim(),
      rif: rifCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      address: addressCtrl.text.trim(),
      warrantyNote: warrantyNoteCtrl.text.trim(),
      folioCounter: int.tryParse(folioCtrl.text) ?? 90,
      showQrPagoMovil: showQrPagoMovil,
      showBarcode: showBarcode,
      showSignatureLine: showSignatureLine,
      showIvaBreakdown: showIvaBreakdown,
      ticketTheme: ticketTheme,
    );

    await StorageService.instance.save('business_profile', bp.toJson());
    DebugLogger.instance.info('Perfil de negocio y preferencias de ticket guardadas.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferencias del negocio y factura guardadas con éxito'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajustes & Preferencias de Factura',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // 1. Selector de Tema Visual (Claro / Oscuro / Auto)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.themeModeNotifier,
            builder: (context, currentMode, _) {
              return Material(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          currentMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                          color: const Color(0xFF6366F1),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tema Visual Adaptable',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.dark_mode,
                              size: 16,
                              color: currentMode == ThemeMode.dark ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                            ),
                            label: const Center(child: Text('Oscuro')),
                            selected: currentMode == ThemeMode.dark,
                            selectedColor: const Color(0xFF6366F1),
                            labelStyle: TextStyle(
                              color: currentMode == ThemeMode.dark ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => ThemeService.instance.setThemeMode(ThemeMode.dark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.light_mode,
                              size: 16,
                              color: currentMode == ThemeMode.light ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                            ),
                            label: const Center(child: Text('Claro')),
                            selected: currentMode == ThemeMode.light,
                            selectedColor: const Color(0xFF6366F1),
                            labelStyle: TextStyle(
                              color: currentMode == ThemeMode.light ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => ThemeService.instance.setThemeMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            avatar: Icon(
                              Icons.brightness_auto,
                              size: 16,
                              color: currentMode == ThemeMode.system ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                            ),
                            label: const Center(child: Text('Auto')),
                            selected: currentMode == ThemeMode.system,
                            selectedColor: const Color(0xFF6366F1),
                            labelStyle: TextStyle(
                              color: currentMode == ThemeMode.system ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => ThemeService.instance.setThemeMode(ThemeMode.system),
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
          const SizedBox(height: 16),

          // 2. Perfil de Tu Empresa (V4 Match)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon/logo.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perfil de Tu Empresa',
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Logotipo del sistema MARKT POS activo',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: businessNameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Nombre Comercial / Empresa *',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: rifCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'RIF / C.I. / NIT *',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Teléfono / WhatsApp',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: addressCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Dirección Fiscal & Ciudad',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: warrantyNoteCtrl,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Nota de Pie de Página / Garantía',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Preferencias de Impresión Ticket & Factura
          Material(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.print_outlined, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Preferencias Permanentes de Impresión',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildSwitchRow(
                    title: 'Mostrar QR Suiche 7B Pago Móvil',
                    subtitle: 'Código QR al pie de factura para pago directo',
                    value: showQrPagoMovil,
                    isDark: isDark,
                    onChanged: (val) => setState(() => showQrPagoMovil = val),
                  ),
                  const Divider(height: 16),

                  _buildSwitchRow(
                    title: 'Mostrar Código de Barras',
                    subtitle: 'Gráfico de barras correlativo bajo el folio',
                    value: showBarcode,
                    isDark: isDark,
                    onChanged: (val) => setState(() => showBarcode = val),
                  ),
                  const Divider(height: 16),

                  _buildSwitchRow(
                    title: 'Mostrar Línea de Firma',
                    subtitle: 'Espacio para firma de conformidad del cliente',
                    value: showSignatureLine,
                    isDark: isDark,
                    onChanged: (val) => setState(() => showSignatureLine = val),
                  ),
                  const Divider(height: 16),

                  _buildSwitchRow(
                    title: 'Mostrar Cuadro Detalle IVA',
                    subtitle: 'Tabla de desglose de base imponible e impuestos',
                    value: showIvaBreakdown,
                    isDark: isDark,
                    onChanged: (val) => setState(() => showIvaBreakdown = val),
                  ),
                  const SizedBox(height: 14),

                  // Contador de Folio
                  TextField(
                    controller: folioCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Número Secuencial de Folio Correlativo',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      prefixText: 'No. FES-0',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. Tasas Oficiales BCV
          Container(
            padding: const EdgeInsets.all(16),
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
                    const Row(
                      children: [
                        Icon(Icons.currency_exchange, color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 8),
                        Text('Tasas Oficiales (BCV)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: BcvService.instance.isLoading,
                      builder: (context, loading, _) {
                        return TextButton.icon(
                          onPressed: loading ? null : () => BcvService.instance.fetchRates(),
                          icon: loading
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)))
                              : const Icon(Icons.sync, size: 16, color: Color(0xFF38BDF8)),
                          label: Text(
                            loading ? 'Consultando...' : 'Actualizar Hoy',
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: bcvUsdCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Tasa USD / Bs.',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: bcvEurCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Tasa EUR / Bs.',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 4. Cuentas Bancarias & Pago Móvil del Negocio (CRUD)
          _buildBankAccountsCrud(isDark),
          const SizedBox(height: 16),

          // 5. Equipo de Vendedores & Asesores (CRUD)
          _buildSellersCrud(isDark),
          const SizedBox(height: 16),

          // Botón Guardar Preferencias
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saveAllSettings,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar Preferencias & Ajustes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Políticas de Privacidad & Registro de Cambios (V4 Planificación)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Acerca del Sistema & Privacidad',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => _showPrivacyPolicyModal(context, isDark),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Políticas de Privacidad (Cero Rastreo)',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '100% de datos en memoria física del dispositivo',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
                const Divider(height: 20),
                InkWell(
                  onTap: () => _showChangelogModal(context, isDark),
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.history_toggle_off, color: Color(0xFF818CF8), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registro de Cambios (Changelog v4.0.0)',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Ver novedades de cada fase implementada',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 20, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Copia de Seguridad & Migración de Dispositivo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_sync_outlined, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Copia de Seguridad & Migración',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Exporta un archivo seguro con todos tus productos, clientes, facturas y caja para migrar a otro teléfono o guardar respaldo.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Exportar Copia de Seguridad
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _exportBackupToFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 20),
                    label: const Text('Exportar Respaldo (Guardar / Compartir)'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Botón Importar Copia de Seguridad
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _importBackupFromFile,
                    icon: const Icon(Icons.download_for_offline_outlined, size: 20),
                    label: const Text('Importar Respaldo desde Archivo JSON'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 6),

                // Botón Limpiar Todos los Datos de Prueba
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: TextButton.icon(
                    onPressed: _confirmClearAllData,
                    icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 20),
                    label: const Text(
                      'Limpiar App (Borrar Datos de Prueba)',
                      style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showPrivacyPolicyModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                Row(
                  children: [
                    const Icon(Icons.privacy_tip, color: Color(0xFF10B981), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Políticas de Privacidad',
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Color(0xFF10B981), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Declaración de Cero Rastreo (Zero Analytics, Zero Telemetry).',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '1. Almacenamiento 100% Local y Físico:\n'
              'Toda la información del negocio (ventas, catálogo de productos, cuentas por cobrar, clientes y tasas) se almacena exclusivamente en la memoria física interna de su dispositivo mediante MarktNativeStorage.\n\n'
              '2. Sin Servidores Externos Obligatorios:\n'
              'MARKT POS no envía sus registros financieros, márgenes de ganancia ni datos de sus clientes a ninguna base de datos remota ni entidad externa.\n\n'
              '3. Tasa Oficial BCV:\n'
              'La aplicación únicamente realiza solicitudes de lectura pública para consultar las tasas oficiales de referencia del Banco Central de Venezuela.\n\n'
              '4. Listo para Tiendas Oficiales:\n'
              'Cumple con los estándares de privacidad exigidos por Google Play Store y Apple App Store para aplicaciones de gestión empresarial offline-first.',
              style: TextStyle(
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Entendido', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangelogModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
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
                    const Icon(Icons.history_edu, color: Color(0xFF818CF8), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Registro de Cambios',
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
            const SizedBox(height: 8),
            Text(
              'Versión 4.0.0 • Sistema Operativo Universal de Negocios',
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildChangelogSection('Fase 1: Catálogos Universales con Costos y Márgenes', [
                    'Costos (\$ USD) y precios con cálculo de margen % en vivo.',
                    'Control de Stock mínimo con alertas visuales inmediatas.',
                  ], isDark),
                  _buildChangelogSection('Fase 2: Libro de Caja & Movimientos Integrados', [
                    'Registro automático de cada cobro POS en el Libro de Caja.',
                    'Desglose por método de pago (Pago Móvil, Efectivo USD, Zelle).',
                  ], isDark),
                  _buildChangelogSection('Fase 3: Cuentas por Cobrar ("Quién me debe")', [
                    'Gestión de ventas a crédito y cuentas por cobrar.',
                    'Abonos parciales que alimentan automáticamente la caja.',
                    'Recordatorio amable formateado para enviar por WhatsApp en 1 clic.',
                  ], isDark),
                  _buildChangelogSection('Fase 4: Perfil de Negocio & Factura Legal', [
                    'Datos de empresa (RIF, Teléfono, Dirección fiscal).',
                    'Opciones de impresión: QR Suiche 7B, Código de barras, Firma y desglose IVA.',
                    'Selección de vendedor y captura automática de fecha y hora.',
                  ], isDark),
                  _buildChangelogSection('Fase 5: Analítica Financiera & Reportes Gerenciales', [
                    'Filtro por períodos (Hoy, Semana, Mes, Histórico).',
                    'Cálculo de COGS (Costo de Mercancía) y Utilidad Neta Real.',
                    'Rendimiento y comisiones ganadas por vendedores.',
                    'Exportación de balance financiero a WhatsApp.',
                  ], isDark),
                  _buildChangelogSection('Arquitectura 100% Nativa Flutter', [
                    'Eliminación de dependencias de JavaScript y WebViews en UI.',
                    'Doble Tema: Dark AMOLED y Claro adaptables con persistencia.',
                  ], isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangelogSection(String title, List<String> items, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...items.map((it) => Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        it,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBankAccountsCrud(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  const Icon(Icons.account_balance, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Cuentas Bancarias & Pago Móvil',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditBankModal(null, isDark),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir Banco', style: TextStyle(fontSize: 12)),
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
          const SizedBox(height: 6),
          Text(
            'Bancos destino para Pago Móvil, Transferencias y Punto de Venta.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_bankAccounts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay bancos registrados aún.',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bankAccounts.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final b = _bankAccounts[i];
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.bankName,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Telf: ${b.phone} • CI/RIF: ${b.docId}',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Cuenta: ${b.accountNumber} (${b.accountHolder})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                      onPressed: () => _showAddEditBankModal(b, isDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                      onPressed: () async {
                        setState(() => _bankAccounts.removeAt(i));
                        await StorageService.instance.save('bank_accounts', _bankAccounts.map((a) => a.toJson()).toList());
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddEditBankModal(BankAccount? account, bool isDark) {
    final bankNameCtrl = TextEditingController(text: account?.bankName ?? '');
    final phoneCtrl = TextEditingController(text: account?.phone ?? '');
    final docIdCtrl = TextEditingController(text: account?.docId ?? '');
    final holderCtrl = TextEditingController(text: account?.accountHolder ?? '');
    final accNumCtrl = TextEditingController(text: account?.accountNumber ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
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
                      account == null ? 'Añadir Cuenta / Banco' : 'Editar Cuenta Bancaria',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankNameCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Nombre del Banco (ej. Banesco, Venezuela, Mercantil)',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'Teléfono Pago Móvil',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: docIdCtrl,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          labelText: 'C.I. / RIF del Titular',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: holderCtrl,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Nombre o Razón Social del Titular',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accNumCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    labelText: 'Número de Cuenta (20 dígitos)',
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (bankNameCtrl.text.trim().isEmpty) return;
                      final updated = BankAccount(
                        id: account?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        bankName: bankNameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        docId: docIdCtrl.text.trim(),
                        accountHolder: holderCtrl.text.trim(),
                        accountNumber: accNumCtrl.text.trim(),
                      );
                      setState(() {
                        if (account != null) {
                          final idx = _bankAccounts.indexWhere((a) => a.id == account.id);
                          if (idx >= 0) _bankAccounts[idx] = updated;
                        } else {
                          _bankAccounts.add(updated);
                        }
                      });
                      await StorageService.instance.save('bank_accounts', _bankAccounts.map((a) => a.toJson()).toList());
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(account == null ? 'Guardar Banco' : 'Actualizar Banco'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSellersCrud(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Equipo de Trabajo: Vendedores & Armadores',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddEditSellerModal(null, isDark),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Añadir Personal', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Gestiona asesores de ventas y técnicos armadores de taller para comisiones y mano de obra.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_sellers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay personal registrado aún.',
                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sellers.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final s = _sellers[i];
                final roleColor = s.role == 'armador'
                    ? const Color(0xFFF59E0B)
                    : s.role == 'ambos'
                        ? const Color(0xFF10B981)
                        : const Color(0xFF6366F1);
                final roleLabel = s.role == 'armador'
                    ? 'Armador / Taller'
                    : s.role == 'ambos'
                        ? 'Ventas & Taller'
                        : 'Vendedor';

                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        s.role == 'armador' ? Icons.build_circle_outlined : Icons.person_pin,
                        color: roleColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                s.name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleLabel,
                                  style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Código: ${s.code} • Comisión Ventas: ${s.commissionPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF6366F1)),
                      onPressed: () => _showAddEditSellerModal(s, isDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                      onPressed: () async {
                        setState(() => _sellers.removeAt(i));
                        await StorageService.instance.save('sellers', _sellers.map((e) => e.toJson()).toList());
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddEditSellerModal(Seller? seller, bool isDark) {
    final nameCtrl = TextEditingController(text: seller?.name ?? '');
    final codeCtrl = TextEditingController(text: seller?.code ?? '');
    final comCtrl = TextEditingController(text: seller?.commissionPercent.toString() ?? '5.0');
    String selectedRole = seller?.role ?? 'vendedor';

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
                        seller == null ? 'Nuevo Integrante del Personal' : 'Editar Integrante',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Nombre y Apellido *',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Rol / Función en el Negocio:',
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        avatar: const Icon(Icons.point_of_sale, size: 16),
                        label: const Text('Vendedor / Asesor', style: TextStyle(fontSize: 11)),
                        selected: selectedRole == 'vendedor',
                        selectedColor: const Color(0xFF6366F1),
                        labelStyle: TextStyle(color: selectedRole == 'vendedor' ? Colors.white : null),
                        onSelected: (val) => setModalState(() => selectedRole = 'vendedor'),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.build, size: 16),
                        label: const Text('Armador / Técnico', style: TextStyle(fontSize: 11)),
                        selected: selectedRole == 'armador',
                        selectedColor: const Color(0xFFF59E0B),
                        labelStyle: TextStyle(color: selectedRole == 'armador' ? Colors.white : null),
                        onSelected: (val) => setModalState(() => selectedRole = 'armador'),
                      ),
                      ChoiceChip(
                        avatar: const Icon(Icons.engineering, size: 16),
                        label: const Text('Ambos Roles', style: TextStyle(fontSize: 11)),
                        selected: selectedRole == 'ambos',
                        selectedColor: const Color(0xFF10B981),
                        labelStyle: TextStyle(color: selectedRole == 'ambos' ? Colors.white : null),
                        onSelected: (val) => setModalState(() => selectedRole = 'ambos'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Código / Alias (ej. OP-01)',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: comCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            labelText: 'Comisión Ventas %',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        final updated = Seller(
                          id: seller?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameCtrl.text.trim(),
                          code: codeCtrl.text.trim().isEmpty ? 'OP' : codeCtrl.text.trim(),
                          commissionPercent: double.tryParse(comCtrl.text) ?? 5.0,
                          role: selectedRole,
                        );
                        setState(() {
                          if (seller != null) {
                            final idx = _sellers.indexWhere((s) => s.id == seller.id);
                            if (idx >= 0) _sellers[idx] = updated;
                          } else {
                            _sellers.add(updated);
                          }
                        });
                        await StorageService.instance.save('sellers', _sellers.map((s) => s.toJson()).toList());
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(seller == null ? 'Guardar Integrante' : 'Actualizar Integrante'),
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
  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: const Color(0xFF6366F1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _exportBackupToFile() async {
    try {
      final backup = await StorageService.instance.exportBackup();
      if (backup.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos guardados para exportar.')),
        );
        return;
      }

      final jsonStr = jsonEncode(backup);
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File('${tempDir.path}/MARKT_Respaldo_$dateStr.json');
      await file.writeAsString(jsonStr, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Copia de Seguridad MARKT POS',
          text: 'Respaldo de datos del sistema MARKT POS ($dateStr)',
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Respaldo generado con exito. Compartelo o guardalo en Google Drive / WhatsApp.'),
        ),
      );
    } catch (e, stack) {
      DebugLogger.instance.error('Error exportando respaldo: $e', stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar respaldo: $e')),
      );
    }
  }

  Future<void> _importBackupFromFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty || files.single.path == null) {
        return;
      }

      final filePath = files.single.path!;
      final file = File(filePath);
      final content = await file.readAsString();
      final dynamic decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formato de archivo invalido. Debe ser un respaldo MARKT valido.')),
        );
        return;
      }

      final success = await StorageService.instance.importBackup(decoded);
      if (!mounted) return;

      if (success) {
        _loadBankAccounts();
        _loadSavedBusinessProfile();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos importados y restaurados con exito. Reinicia o navega por los modulos.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar e importar los datos.')),
        );
      }
    } catch (e, stack) {
      DebugLogger.instance.error('Error importando archivo: $e', stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al importar archivo: $e')),
      );
    }
  }

  void _confirmClearAllData() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('¿Limpiar Toda la App?'),
          ],
        ),
        content: const Text(
          'Esta accion eliminara todos los productos de prueba, clientes de muestra, facturas y registros de caja.\n\nLa app quedara limpia en blanco lista para tu operacion real.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await StorageService.instance.clearAllData();
              if (mounted) {
                if (success) {
                  setState(() {
                    _bankAccounts.clear();
                    _sellers.clear();
                    businessNameCtrl.clear();
                    rifCtrl.clear();
                    phoneCtrl.clear();
                    addressCtrl.clear();
                    folioCtrl.text = '0';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Datos de prueba eliminados. La app esta limpia en 0.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al limpiar datos.')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Si, Limpiar Todo'),
          ),
        ],
      ),
    );
  }
}
