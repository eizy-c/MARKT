import 'package:flutter/material.dart';
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
  final businessNameCtrl = TextEditingController(text: 'EIZY STORE');
  final rifCtrl = TextEditingController(text: 'V-28425010');
  final phoneCtrl = TextEditingController(text: '0414-5803945');
  final addressCtrl = TextEditingController(text: 'Lara - Barquisimeto');
  final warrantyNoteCtrl = TextEditingController(
    text: 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.',
  );
  final folioCtrl = TextEditingController(text: '90');

  // Opciones de Impresión
  bool showQrPagoMovil = true;
  bool showBarcode = true;
  bool showSignatureLine = true;
  bool showIvaBreakdown = false;
  String ticketTheme = 'pos_termico';

  @override
  void initState() {
    super.initState();
    final rates = BcvService.instance.currentRates;
    bcvUsdCtrl = TextEditingController(text: rates.usd.toStringAsFixed(2));
    bcvEurCtrl = TextEditingController(text: rates.eur.toStringAsFixed(2));

    BcvService.instance.ratesNotifier.addListener(_onRatesUpdated);
    _loadSavedBusinessProfile();
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
                    const Icon(Icons.storefront, color: Color(0xFF6366F1), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Perfil de Tu Empresa',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
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
          const SizedBox(height: 20),

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
        ],
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
}
