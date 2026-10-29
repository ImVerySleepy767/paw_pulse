import 'package:local_auth/local_auth.dart';

/// Wraps device biometric authentication (fingerprint / Face ID).
/// Not covered anywhere in the MP6/7 Firebase Auth curriculum — this is
/// a separate, device-level authentication layer on top of Firebase Auth,
/// not a replacement for it.
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isDeviceSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock PawPulse to continue',
        options: const AuthenticationOptions(
          biometricOnly: false, // allows device PIN/pattern as fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
