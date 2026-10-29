import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawpulse/services/biometric_service.dart';

const String _biometricPrefKey = 'biometric_lock_enabled';

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

/// Whether the user has turned biometric app-lock ON (persisted across
/// restarts via SharedPreferences — the settings storage taught in MP11,
/// reused here just to remember a toggle, not as the auth method itself).
class BiometricPreferenceNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricPrefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricPrefKey, enabled);
    state = AsyncValue.data(enabled);
  }
}

final biometricPreferenceProvider =
    AsyncNotifierProvider<BiometricPreferenceNotifier, bool>(BiometricPreferenceNotifier.new);

/// Whether the user has already passed the biometric gate THIS app
/// session. Resets to false every cold start, so the lock re-applies
/// each time the app is opened (not just once ever).
class SessionUnlockedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
  void lock() => state = false;
}

final sessionUnlockedProvider = NotifierProvider<SessionUnlockedNotifier, bool>(
  SessionUnlockedNotifier.new,
);
