import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/biometric_provider.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/theme/app_theme.dart';

/// Gate screen shown on app open when the user has biometric lock enabled.
/// Distinct from Firebase Auth — this protects re-entry into an already
/// logged-in session, the way banking apps do.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isChecking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Prompt immediately on entry so the user isn't stuck tapping a button
    // every single time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    setState(() {
      _isChecking = true;
      _error = null;
    });

    final supported = await ref.read(biometricServiceProvider).isDeviceSupported();
    if (!supported) {
      setState(() {
        _isChecking = false;
        _error = 'Biometrics not available on this device/emulator.';
      });
      return;
    }

    final success = await ref.read(biometricServiceProvider).authenticate();
    if (success) {
      ref.read(sessionUnlockedProvider.notifier).unlock();
    } else {
      setState(() {
        _isChecking = false;
        _error = 'Authentication failed or was cancelled.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.terracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint, size: 42, color: AppColors.terracotta),
              ),
              const SizedBox(height: 24),
              const Text('PawPulse is locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Verify your identity to continue.',
                style: TextStyle(color: AppColors.softGrey),
              ),
              const SizedBox(height: 28),
              if (_isChecking)
                const CircularProgressIndicator()
              else ...[
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                ],
                ElevatedButton.icon(
                  onPressed: _tryUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.read(firebaseServiceProvider).logout(),
                  child: const Text('Log out instead', style: TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}