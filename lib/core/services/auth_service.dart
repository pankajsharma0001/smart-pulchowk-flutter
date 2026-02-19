import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smart_pulchowk/core/services/api_service.dart';
import 'package:smart_pulchowk/core/services/notification_service.dart';
import 'package:smart_pulchowk/core/services/storage_service.dart';
import 'package:smart_pulchowk/core/constants/app_constants.dart';

/// Service to handle authentication using Firebase and Google.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google and sync with backend.
  static Future<bool> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final idToken = await user.getIdToken();
        final fcmToken = await NotificationService.getToken();

        // Sync with backend
        final apiService = ApiService();
        final dbUserId = await apiService.syncUser(
          authStudentId: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Unknown User',
          firebaseIdToken: idToken ?? '',
          image: user.photoURL,
          fcmToken: fcmToken,
        );

        if (dbUserId != null) {
          await StorageService.writeSecure(AppConstants.dbUserIdKey, dbUserId);
          // Sync notification topic subscriptions
          await NotificationService.syncSubscriptions();
          return true;
        } else {
          // Backend sync failed - sign out
          await signOut();
          return false;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error during Google sign-in: $e');
      return false;
    }
  }

  /// Sign out from Firebase and Google.
  static Future<void> signOut() async {
    try {
      final apiService = ApiService();
      final idToken = await _auth.currentUser?.getIdToken();

      // Parallel cleanup
      await Future.wait([
        apiService
            .clearFcmToken(idToken)
            .timeout(const Duration(seconds: 2))
            .catchError((_) => null),
        StorageService.deleteSecure(AppConstants.dbUserIdKey),
        StorageService.deleteSecure(AppConstants.userRoleKey),
        NotificationService.unsubscribeFromAllTopics().catchError((_) => null),
        ApiService.clearCache(),
      ]);

      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error during sign-out: $e');
    }
  }
}
