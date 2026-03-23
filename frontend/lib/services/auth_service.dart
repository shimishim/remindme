import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps FirebaseAuth and exposes sign-in / sign-out helpers.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of auth state changes (null = logged out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sign in with email & password
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Register a new user with email & password
  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  /// Get a fresh Firebase ID token (auto-refreshes if expired)
  Future<String?> getIdToken() async {
    return _auth.currentUser?.getIdToken();
  }

  Future<void> signOut() => _auth.signOut();

  /// Sign in anonymously (no email/password needed)
  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream of the current Firebase User (null when logged out)
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = FirebaseAuth.instance;

  developer.log('authStateProvider: subscribing to authStateChanges',
      name: 'AuthService');

  return auth.authStateChanges().map((user) {
    developer.log('authStateProvider: user = \u001b[33m${user?.uid}\u001b[0m',
        name: 'AuthService');
    return user;
  });
});

/// The current user's UID — throws if called while signed out
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) throw Exception('Not authenticated');
  return user.uid;
});
