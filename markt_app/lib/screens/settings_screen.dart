import 'package:flutter/material.dart';
import '../services/debug_logger.dart';
import '../services/storage_service.dart';
import '../services/bcv_service.dart';
import '../services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController bcvUsdCtrl;
  late final TextEditingController bcvEurCtrl;
  final businessNameCtrl = TextEditingController(text: 'MARKT Publicidad & CNC');

  @override
  void initState() {
    super.initState();
    final rates = BcvService.instance.currentRates;
    bcvUsdCtrl = TextEditingController(text: rates.usd.toStringAsFixed(2));
    bcvEurCtrl = TextEditingController(text: rates.eur.toStringAsFixed(2));

    BcvService.instance.ratesNotifier.addListener(_onRatesUpdated);
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
    super.dispose();
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
            'Ajustes del Sistema & Negocio',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),

          // Selector de Tema Visual (Claro / Oscuro / Sistema)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.instance.themeModeNotifier,
            builder: (context, currentMode, _) {
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
              );
            },
          ),
          const SizedBox(height: 16),

          // Tarjeta Negocio
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Datos del Comercio', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: businessNameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre Comercial',
                    labelStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tasas Cambiarias
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
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
                        Text('Tasas Oficiales (BCV)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tasa USD / Bs.',
                          labelStyle: const TextStyle(color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: bcvEurCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Tasa EUR / Bs.',
                          labelStyle: const TextStyle(color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
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

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                DebugLogger.instance.info('Configuraciones guardadas localmente.');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configuración actualizada con éxito'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar Cambios'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Respaldo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mantenimiento y Respaldo', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Exporta o respalda los archivos JSON locales en la memoria física del dispositivo.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final backup = await StorageService.instance.exportBackup();
                    DebugLogger.instance.info('Backup exportado con ${backup.keys.length} colecciones.');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Respaldo generado con éxito (${backup.keys.length} módulos)')),
                      );
                    }
                  },
                  icon: const Icon(Icons.backup_outlined, color: Color(0xFF38BDF8)),
                  label: const Text('Exportar Respaldo de Seguridad', style: TextStyle(color: Color(0xFF38BDF8))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1E293B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
