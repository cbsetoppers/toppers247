import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

class AppThemeState {
  final Color primaryColor;
  final Brightness brightness;

  AppThemeState({required this.primaryColor, required this.brightness});

  AppThemeState copyWith({Color? primaryColor, Brightness? brightness}) {
    return AppThemeState(
      primaryColor: primaryColor ?? this.primaryColor,
      brightness: brightness ?? this.brightness,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeState>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeState> {
  static const Color defaultColor = Color(0xFFFFD700); // Golden

  ThemeNotifier()
      : super(AppThemeState(
            primaryColor: defaultColor, brightness: Brightness.light)) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('theme_color');
    final isLight = prefs.getBool('theme_light') ?? true; // Default to Light

    Color color = defaultColor;
    if (colorValue != null) {
      color = Color(colorValue);
    }

    final brightness = isLight ? Brightness.light : Brightness.dark;
    AppTheme.setTheme(color, brightness);
    
    state = AppThemeState(
      primaryColor: color,
      brightness: brightness,
    );
  }

  Future<void> setColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
    AppTheme.setTheme(color, state.brightness);
    state = state.copyWith(primaryColor: color);
  }

  Future<void> toggleBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    final newBrightness = state.brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    await prefs.setBool('theme_light', newBrightness == Brightness.light);
    AppTheme.setTheme(state.primaryColor, newBrightness);
    state = state.copyWith(brightness: newBrightness);
  }
}
