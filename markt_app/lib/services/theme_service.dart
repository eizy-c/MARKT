import 'package:flutter/material.dart';
import 'storage_service.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._internal();
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  ThemeMode get currentThemeMode => themeModeNotifier.value;
  bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  Future<void> init() async {
    try {
      final saved = await StorageService.instance.load('app_theme_mode');
      if (saved != null) {
        if (saved == 'light') {
          themeModeNotifier.value = ThemeMode.light;
        } else if (saved == 'system') {
          themeModeNotifier.value = ThemeMode.system;
        } else {
          themeModeNotifier.value = ThemeMode.dark;
        }
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    String modeStr = 'dark';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.system) modeStr = 'system';
    await StorageService.instance.save('app_theme_mode', modeStr);
  }
}
