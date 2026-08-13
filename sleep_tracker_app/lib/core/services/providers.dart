import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_profile.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

/// Live Firebase auth state — drives the router redirect logic (see
/// lib/core/routing/app_router.dart).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Live profile document for the signed-in user. Null while signed out.
/// This is the single source of truth every screen (including Kitty AI)
/// reads from — no screen queries Firestore directly for profile data.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchProfile(user.uid);
});
