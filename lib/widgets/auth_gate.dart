import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/providers/biometric_provider.dart';
import 'package:pawpulse/screens/login_screen.dart';
import 'package:pawpulse/screens/email_verification_screen.dart';
import 'package:pawpulse/screens/biometric_lock_screen.dart';

/// Wraps every protected screen. `MaterialApp.home` only re-checks auth on
/// the very first page load — if the user refreshes the browser or opens a
/// direct URL while sitting on any named route, Flutter Web jumps straight
/// there, skipping that check entirely. This widget re-applies the same
/// login / email-verification / biometric gating no matter how the screen
/// was reached.
class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return const LoginScreen();

        final signedUpWithEmail = user.providerData.any((p) => p.providerId == 'password');
        if (signedUpWithEmail && !user.emailVerified) {
          return const EmailVerificationScreen();
        }

        final biometricEnabled = ref.watch(biometricPreferenceProvider).value ?? false;
        final sessionUnlocked = ref.watch(sessionUnlockedProvider);
        if (biometricEnabled && !sessionUnlocked) {
          return const BiometricLockScreen();
        }

        return child;
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }
}