import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_pulchowk/core/services/navigation_service.dart';

/// Service to handle FCM and local notifications.
class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize notifications (permission request, channel setup).
  static Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
        'User granted notification permission: ${settings.authorizationStatus}',
      );

      // 1. Listen to background notification clicks (App in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification clicked from background: ${message.data}');
        NavigationService.handleNotificationPayload(message.data);
      });

      // 2. Handle initial notification (App terminated)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          'Notification clicked from terminated: ${initialMessage.data}',
        );
        NavigationService.handleNotificationPayload(initialMessage.data);
      }

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification}',
          );
        }
      });

      // Listen to token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token Refreshed: $newToken');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final idToken = await user.getIdToken();
          if (idToken != null) {
            await ApiService().updateFcmToken(
              fcmToken: newToken,
              firebaseIdToken: idToken,
            );
          }
        }
      });

      // Sync subscriptions if user is already logged in
      if (FirebaseAuth.instance.currentUser != null) {
        await syncSubscriptions();
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  /// Get the current FCM token.
  static Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to a specific topic.
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a specific topic.
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Unsubscribe from all major topics.
  static Future<void> unsubscribeFromAllTopics() async {
    try {
      final topics = [
        'events',
        'books',
        'announcements',
        'lost_found',
        'chat',
        'classroom',
      ];
      await Future.wait(topics.map((t) => unsubscribeFromTopic(t)));
      await _messaging.deleteToken();
      debugPrint('Unsubscribed from all notification topics and cleared token');
    } catch (e) {
      debugPrint('Error unsubscribing from topics: $e');
    }
  }

  /// Check if user has granted notification permissions.
  static Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Sync device topic subscriptions with user preferences in SharedPreferences.
  /// This ensures that new logins or app installs respect the user's settings.
  static Future<void> syncSubscriptions() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        debugPrint('No notification permissions. Skipping subscription sync.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final topics = {
        'events': prefs.getBool('notify_events') ?? true,
        'books': prefs.getBool('notify_books') ?? true,
        'announcements': prefs.getBool('notify_announcements') ?? true,
        'lost_found': prefs.getBool('notify_lost_found') ?? true,
        'chat': prefs.getBool('notify_chat') ?? true,
        'classroom': prefs.getBool('notify_classroom') ?? true,
      };

      debugPrint('Syncing FCM subscriptions: $topics');

      final futures = <Future<void>>[];
      topics.forEach((topic, enabled) {
        if (enabled) {
          futures.add(subscribeToTopic(topic));
        } else {
          futures.add(unsubscribeFromTopic(topic));
        }
      });

      await Future.wait(futures);

      // Special handling for faculty classroom topic if enabled
      if (topics['classroom'] == true) {
        try {
          final profile = await ApiService().getStudentProfile();
          if (profile != null) {
            await subscribeToTopic('faculty_${profile.facultyId}');
          }
        } catch (e) {
          debugPrint('Error syncing faculty topic: $e');
        }
      }
    } catch (e) {
      debugPrint('Error syncing subscriptions: $e');
    }
  }
}
