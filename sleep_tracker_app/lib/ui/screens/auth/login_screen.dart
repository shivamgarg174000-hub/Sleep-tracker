import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
      // Router redirects automatically once authStateProvider emits a user.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGlow,
                  boxShadow: AppTheme.glow(AppColors.accentPrimary, blur: 50, opacity: 0.5),
                ),
                child: const Icon(Icons.bedtime_rounded, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Kitty Sleep',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Track your sleep. Understand your body.\nLet Kitty AI guide the way.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const Spacer(flex: 3),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : () => _run(auth.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                  label: const Text('Continue with Google'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: const BorderSide(color: AppColors.glassBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md)),
                  ),
                  onPressed: _loading ? null : () => _run(auth.signInAsGuest),
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Continue as Guest'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
