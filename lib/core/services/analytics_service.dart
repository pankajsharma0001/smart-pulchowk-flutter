import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

/// Service to handle app analytics using Firebase.
class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics? _analytics;

  static bool get _isFirebaseReady => Firebase.apps.isNotEmpty;

  static FirebaseAnalytics? get _instance {
    if (!_isFirebaseReady) return null;
    return _analytics ??= FirebaseAnalytics.instance;
  }

  static List<NavigatorObserver> get navigatorObservers {
    final analytics = _instance;
    if (analytics == null) return const <NavigatorObserver>[];
    return <NavigatorObserver>[FirebaseAnalyticsObserver(analytics: analytics)];
  }

  static Future<void> logAppOpen() async {
    try {
      final analytics = _instance;
      if (analytics == null) return;
      await analytics.logAppOpen();
    } catch (e) {
      debugPrint('Analytics error [logAppOpen]: $e');
    }
  }

  static Future<void> logScreenView(String screenName) async {
    try {
      final analytics = _instance;
      if (analytics == null) return;
      await analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics error [logScreenView]: $e');
    }
  }

  static Future<void> logLogin(String method) async {
    try {
      final analytics = _instance;
      if (analytics == null) return;
      await analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Analytics error [logLogin]: $e');
    }
  }

  static Future<void> logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    try {
      final analytics = _instance;
      if (analytics == null) return;
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Analytics error [logEvent]: $e');
    }
  }
}
