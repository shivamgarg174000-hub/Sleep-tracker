import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/providers.dart';
import '../../ui/screens/auth/login_screen.dart';
import '../../ui/screens/onboarding/onboarding_screen.dart';
import '../../ui/screens/shell/app_shell.dart';

/// Single source of truth for navigation. Redirect logic:
///   signed out            -> /login
///   signed in, no profile -> /onboarding
///   signed in, complete   -> /home
/// This means no screen ever has to manually push/pop on auth changes —
/// signing out or deleting the account just falls through to /login.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileState = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final user = authState.value;
      final loggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return loggingIn ? null : '/login';
      }

      // Auth resolved but profile stream hasn't emitted yet — hold position.
      if (profileState.isLoading) return null;

      final profile = profileState.value;
      final onboarded = profile?.onboardingComplete ?? false;

      if (!onboarded) {
        return state.matchedLocation == '/onboarding' ? null : '/onboarding';
      }

      if (loggingIn || state.matchedLocation == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const AppShell()),
    ],
  );
});

/// Bridges Riverpod's async auth/profile streams into a Listenable so
/// go_router re-evaluates `redirect` whenever either one changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }
}
