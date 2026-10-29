import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/providers/email_verification_provider.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  static const String routeName = '/email-verification';
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isSending = false;
  bool _isChecking = false;
  String? _statusMessage;
  Timer? _cooldownTicker;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // No auto-send here. The verification email is sent exactly once, at
    // registration time (see FirebaseService.register). This screen only
    // checks status and offers a manual, cooldown-protected resend.
    final lastSent = ref.read(lastVerificationSentProvider);
    if (lastSent != null && DateTime.now().difference(lastSent) < verificationResendCooldown) {
      _startCooldownTicker(verificationResendCooldown - DateTime.now().difference(lastSent));
    }
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    super.dispose();
  }

  void _startCooldownTicker(Duration remaining) {
    setState(() => _secondsRemaining = remaining.inSeconds.clamp(0, 999));
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  Future<void> _sendVerificationEmail() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      final user = ref.read(firebaseServiceProvider).getCurrentUser();
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ref.read(lastVerificationSentProvider.notifier).markSentNow();
        _startCooldownTicker(verificationResendCooldown);
        if (mounted) {
          setState(() => _statusMessage = 'Verification email sent!');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = e.code == 'too-many-requests'
              ? 'Too many requests — please wait a few minutes before trying again.'
              : e.message ?? 'Error sending verification email.';
        });
      }
      // Still start a cooldown on rate-limit errors so the user doesn't
      // immediately hammer the button again.
      if (e.code == 'too-many-requests') {
        _startCooldownTicker(const Duration(minutes: 5));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Error sending verification email: $e');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerificationStatus() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });
    try {
      final user = ref.read(firebaseServiceProvider).getCurrentUser();
      await user?.reload();
      final refreshedUser = ref.read(firebaseServiceProvider).getCurrentUser();

      if (refreshedUser != null && refreshedUser.emailVerified) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/home');
      } else {
        if (mounted) {
          setState(() => _statusMessage =
              'Email not verified yet. Open the link in your email first, then try again.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Error checking status: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(firebaseServiceProvider).getCurrentUser();
    final onCooldown = _secondsRemaining > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Email Verification Required')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mark_email_unread, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Verification Email Sent!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We have sent a verification link to:\n${user?.email ?? ''}\n\nPlease click the link in your email, then click the button below to continue.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(_statusMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isChecking ? null : _checkVerificationStatus,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: _isChecking
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('I Have Verified, Continue'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: (_isSending || onCooldown) ? null : () => _sendVerificationEmail(),
              child: Text(
                _isSending
                    ? 'Sending...'
                    : onCooldown
                        ? 'Resend available in ${_secondsRemaining}s'
                        : 'Resend Verification Email',
              ),
            ),
            TextButton(
              onPressed: () => ref.read(firebaseServiceProvider).logout(),
              child: const Text('Logout / Back to Login', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}