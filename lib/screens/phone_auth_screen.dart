import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'package:pawpulse/widgets/otp_box_input.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  static const String routeName = '/phone-auth';
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();

  String _verificationId = '';
  String _maskedPhone = '';
  bool _isCodeSent = false;
  bool _isLoading = false;

  void _sendSMS() async {
    if (_phoneController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(firebaseServiceProvider).verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        onCodeSent: (verId) {
          setState(() {
            _verificationId = verId;
            _maskedPhone = _maskPhone(_phoneController.text.trim());
            _isCodeSent = true;
            _isLoading = false;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('System Error: $e')));
    }
  }

  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, phone.length - 4)}****';
  }

  void _verifySMS(String code) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(firebaseServiceProvider).signInWithSMSCode(
            verificationId: _verificationId,
            smsCode: code,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Invalid code: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('PawPulse'),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isCodeSent ? _buildVerifyStep() : _buildPhoneStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildShieldIcon(),
        const SizedBox(height: 24),
        const Text('Sign in with Phone', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          "Enter your phone number and we'll send a verification code via SMS.",
          style: TextStyle(color: AppColors.softGrey),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number (e.g., +6581234567)',
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendSMS,
          child: _isLoading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send Code →'),
        ),
      ],
    );
  }

  Widget _buildVerifyStep() {
    return Column(
      key: const ValueKey('verify'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildShieldIcon(),
        const SizedBox(height: 24),
        const Text('Verify your account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code sent to $_maskedPhone to verify your identity.',
          style: const TextStyle(color: AppColors.softGrey),
        ),
        const SizedBox(height: 28),
        OtpBoxInput(onCompleted: _verifySMS),
        const SizedBox(height: 28),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Center(
            child: TextButton(
              onPressed: _sendSMS,
              child: const Text("Didn't receive the code? Resend Code",
                  style: TextStyle(color: AppColors.terracotta)),
            ),
          ),
      ],
    );
  }

  Widget _buildShieldIcon() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.terracotta.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.shield_outlined, color: AppColors.terracotta, size: 28),
    );
  }
}