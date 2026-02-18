import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme mode (light/dark/system) and haptic preferences.
///
/// Persists user preferences to [SharedPreferences] and provides
/// convenient accessors for the current state.
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _hapticsKey = 'haptics_enabled';

  /// Access the [ThemeProvider] from a descendant widget.
  static ThemeProvider of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<InheritedThemeProvider>();
    assert(inherited != null, 'No InheritedThemeProvider found in context');
    return inherited!.notifier!;
  }

  ThemeMode _themeMode = ThemeMode.system;
  bool _hapticsEnabled = true;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// Load saved preferences.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final themeModeIndex = prefs.getInt(_themeKey) ?? 0;
    if (themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    _hapticsEnabled = prefs.getBool(_hapticsKey) ?? true;
    _isInitialized = true;
    notifyListeners();
  }

  /// Set the theme mode and persist.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  /// Cycle through themes: light → dark → system → light...
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
    }
  }

  /// Set haptic feedback preference and persist.
  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticsKey, enabled);

    if (enabled) vibrate();
  }

  /// Light haptic impact (if enabled).
  void vibrate() {
    if (_hapticsEnabled) HapticFeedback.lightImpact();
  }

  /// Selection click haptic (if enabled).
  void selectionClick() {
    if (_hapticsEnabled) HapticFeedback.selectionClick();
  }

  /// Medium impact haptic (if enabled).
  void mediumImpact() {
    if (_hapticsEnabled) HapticFeedback.mediumImpact();
  }

  /// Heavy impact haptic (if enabled).
  void heavyImpact() {
    if (_hapticsEnabled) HapticFeedback.heavyImpact();
  }

  /// Human-readable label for the current theme mode.
  String get themeModeLabel => switch (_themeMode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  /// Icon for the current theme mode.
  IconData get themeModeIcon => switch (_themeMode) {
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
    ThemeMode.system => Icons.brightness_auto_rounded,
  };
}

/// Inherited widget for [ThemeProvider].
class InheritedThemeProvider extends InheritedNotifier<ThemeProvider> {
  const InheritedThemeProvider({
    super.key,
    required super.notifier,
    required super.child,
  });
}
