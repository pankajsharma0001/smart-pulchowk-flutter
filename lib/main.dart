import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:smart_pulchowk/core/theme/app_theme.dart';
import 'package:smart_pulchowk/core/theme/theme_provider.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/services/notification_service.dart';
import 'package:smart_pulchowk/core/services/analytics_service.dart';
import 'package:smart_pulchowk/core/services/haptic_service.dart';
import 'package:smart_pulchowk/features/auth/auth.dart';
import 'package:smart_pulchowk/core/services/navigation_service.dart';
import 'package:smart_pulchowk/core/services/favorites_provider.dart';
import 'package:smart_pulchowk/core/widgets/theme_change_animator.dart';
import 'package:smart_pulchowk/core/services/connectivity_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // For notification payloads, OS already displays in background/terminated.
  // We only render local notifications for data-only pushes.
  if (message.notification != null) return;

  final title =
      message.data['title']?.toString() ??
      message.data['notificationTitle']?.toString();
  final body =
      message.data['body']?.toString() ??
      message.data['message']?.toString() ??
      message.data['notificationBody']?.toString();

  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
  );
  await plugin.initialize(initSettings);

  final androidPlugin = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
    ),
  );

  await plugin.show(
    message.hashCode,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: Uri(
      queryParameters: message.data.map((k, v) => MapEntry(k, v.toString())),
    ).query,
  );
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseInitialized = false;

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;

    // Register background handler after initialization
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize Core Services
  await StorageService.init();
  await ConnectivityService.instance.initialize();

  final themeProvider = ThemeProvider();
  final favoritesProvider = FavoritesProvider();
  haptics.init(themeProvider);

  // Initialize notification services
  if (firebaseInitialized) {
    // Capture cold-start notification BEFORE runApp() so the payload
    // is guaranteed to be available when MainLayout mounts.
    RemoteMessage? initialMessage;
    try {
      initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    } catch (e) {
      debugPrint('Failed to get initial message: $e');
    }

    // Initialize notification service (attaches listeners, creates channels)
    // and pass the pre-captured initial message.
    NotificationService.initialize(initialMessage: initialMessage)
        .then((_) {
          NotificationService.ensurePermission().then((granted) {
            if (granted) NotificationService.syncSubscriptions();
          });
        })
        .catchError((e) {
          debugPrint('Notification initialization failed: $e');
        });

    AnalyticsService.logAppOpen().catchError(
      (e) => debugPrint('Analytics logAppOpen failed: $e'),
    );
  }

  runApp(
    SmartPulchowkApp(
      themeProvider: themeProvider,
      favoritesProvider: favoritesProvider,
    ),
  );
}

class SmartPulchowkApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final FavoritesProvider favoritesProvider;

  const SmartPulchowkApp({
    super.key,
    required this.themeProvider,
    required this.favoritesProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeChangeAnimator(
      key: themeAnimatorKey,
      child: ListenableBuilder(
        listenable: themeProvider,
        builder: (context, child) {
          return InheritedThemeProvider(
            notifier: themeProvider,
            child: InheritedFavoritesProvider(
              notifier: favoritesProvider,
              child: MaterialApp(
                title: 'Smart Pulchowk',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                navigatorKey:
                    NavigationService.navigatorKey, // Set global navigator key
                navigatorObservers: AnalyticsService.navigatorObservers,
                home: const AuthWrapper(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
