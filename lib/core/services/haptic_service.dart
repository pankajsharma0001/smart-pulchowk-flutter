import 'package:flutter/services.dart';
import 'package:smart_pulchowk/core/theme/theme_provider.dart';

/// A singleton service to handle haptic feedback throughout the app.
/// Respects the user's feedback preference from [ThemeProvider].
class HapticService {
  static final HapticService _instance = HapticService._();
  static HapticService get instance => _instance;

  ThemeProvider? _themeProvider;
  HapticService._();

  /// Initialize with provider reference.
  void init(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  bool get _isEnabled => _themeProvider?.hapticsEnabled ?? true;

  void lightImpact() {
    if (_isEnabled) HapticFeedback.lightImpact();
  }

  void mediumImpact() {
    if (_isEnabled) HapticFeedback.mediumImpact();
  }

  void heavyImpact() {
    if (_isEnabled) HapticFeedback.heavyImpact();
  }

  void selectionClick() {
    if (_isEnabled) HapticFeedback.selectionClick();
  }

  void vibrate() {
    if (_isEnabled) HapticFeedback.vibrate();
  }

  void success() {
    if (_isEnabled) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        HapticFeedback.lightImpact();
      });
    }
  }

  void error() {
    if (_isEnabled) {
      HapticFeedback.heavyImpact();
    }
  }
}

/// Global instance for easy access.
final haptics = HapticService.instance;
