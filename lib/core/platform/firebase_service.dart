import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase is fully optional in v1: the build applies google-services only
/// when android/app/google-services.json exists, and runtime init is guarded.
/// When Firebase is absent every method degrades to a no-op with an honest
/// `cloudAvailable = false` so the UI can say "Cloud sync: inactive".
class FirebaseService {
  bool _available = false;
  bool get cloudAvailable => _available;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _available = true;
    } catch (_) {
      // No google-services.json (or Play services missing): run local-first.
      _available = false;
    }
  }

  /// Signs in anonymously when cloud is available; otherwise returns null.
  Future<User?> signInQuietly() async {
    if (!_available) return null;
    try {
      final auth = FirebaseAuth.instance;
      return auth.currentUser ?? (await auth.signInAnonymously()).user;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort history sync. Fails silently — local history stays the
  /// source of truth and private content is never synced by default.
  Future<bool> pushHistoryItem(String userId, Map<String, Object?> item) async {
    if (!_available) return false;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('history')
          .add(item);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});
