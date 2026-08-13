import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';

import 'firestore_service.dart';

/// Thin, testable wrapper around FirebaseAuth + GoogleSignIn.
/// No mock/demo branches — every path here talks to real Firebase.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirestoreService? firestoreService,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
            ),
        _firestore = firestoreService ?? FirestoreService(),
        _logger = Logger();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirestoreService _firestore;
  final Logger _logger;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  /// Native Google OAuth sign-in. Creates the Firestore user doc on first
  /// login only — never overwrites an existing profile.
  Future<User> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw AuthException('Google sign-in did not return a user.');
      }

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.createInitialProfile(
          uid: user.uid,
          isGuest: false,
          displayName: user.displayName,
        );
      }

      return user;
    } on FirebaseAuthException catch (e) {
      _logger.e('Google sign-in failed', error: e);
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// Fully functional anonymous/guest sign-in. Guest data is real and
  /// persisted — it is not a UI-only stub. A guest can later "upgrade"
  /// to a Google account via [linkGoogleAccount].
  Future<User> signInAsGuest() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;
      if (user == null) {
        throw AuthException('Guest sign-in did not return a user.');
      }

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.createInitialProfile(
          uid: user.uid,
          isGuest: true,
          displayName: 'Guest',
        );
      }

      return user;
    } on FirebaseAuthException catch (e) {
      _logger.e('Guest sign-in failed', error: e);
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// Upgrades an anonymous session to a permanent Google-backed account
  /// without losing the guest's existing Firestore data.
  Future<User> linkGoogleAccount() async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) {
      throw AuthException('No guest session to upgrade.');
    }

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Sign-in was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final linked = await current.linkWithCredential(credential);
    final user = linked.user!;
    await _firestore.updateProfileFields(user.uid, {
      'isGuest': false,
      'displayName': user.displayName ?? 'User',
    });
    return user;
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Store-compliant account deletion: wipes Firestore data first (while
  /// the auth session is still valid enough to satisfy security rules),
  /// then revokes the Firebase Auth identity itself.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('No signed-in user.');

    try {
      await _firestore.deleteAllUserData(user.uid);
      await user.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw AuthException(
          'For your security, please sign in again before deleting your account.',
          requiresReauth: true,
        );
      }
      _logger.e('Account deletion failed', error: e);
      throw AuthException(_mapFirebaseError(e));
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}

class AuthException implements Exception {
  final String message;
  final bool requiresReauth;
  AuthException(this.message, {this.requiresReauth = false});

  @override
  String toString() => message;
}
