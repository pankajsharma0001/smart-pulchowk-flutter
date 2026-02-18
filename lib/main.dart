import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/theme/theme_provider.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/services/notification_service.dart';
import 'package:smart_pulchowk/core/services/analytics_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/features/auth/auth.dart';
import 'package:smart_pulchowk/core/services/navigation_service.dart';
import 'firebase_options.dart';

class GlobalHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = GlobalHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize Core Services
  await StorageService.init();

  final themeProvider = ThemeProvider();
  haptics.init(themeProvider);

  // Initialize async services (non-blocking)
  NotificationService.initialize().catchError(
    (e) => debugPrint('Notification initialization failed: $e'),
  );
  AnalyticsService.logAppOpen().catchError(
    (e) => debugPrint('Analytics logAppOpen failed: $e'),
  );

  runApp(SmartPulchowkApp(themeProvider: themeProvider));
}

class SmartPulchowkApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const SmartPulchowkApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, child) {
        return InheritedThemeProvider(
          notifier: themeProvider,
          child: MaterialApp(
            title: 'Smart Pulchowk',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            navigatorKey:
                NavigationService.navigatorKey, // Set global navigator key
            navigatorObservers: [AnalyticsService.observer],
            home: const AuthWrapper(),
          ),
        );
      },
    );
  }
}
