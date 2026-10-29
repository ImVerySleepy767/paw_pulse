import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the last time a verification email was sent, at the app level
/// (not per-screen-instance). This is what actually prevents re-sends —
/// without it, every remount of EmailVerificationScreen would trigger a
/// fresh send, which is what exhausted Firebase's rate limit.
class LastVerificationSentNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void markSentNow() => state = DateTime.now();
}

final lastVerificationSentProvider =
    NotifierProvider<LastVerificationSentNotifier, DateTime?>(
  LastVerificationSentNotifier.new,
);

/// Minimum time between verification email sends. Keeping this well above
/// Firebase's own internal limit avoids ever hitting too-many-requests
/// from normal use.
const Duration verificationResendCooldown = Duration(seconds: 60);
