import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'package:pawpulse/widgets/pawpulse_auth_header.dart';
import 'package:pawpulse/widgets/pawpulse_widgets.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  static const String routeName = '/reset-password';
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  void _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref.read(firebaseServiceProvider).sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset link sent to your email!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(backgroundColor: AppColors.cream, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.pets, color: AppColors.terracotta, size: 32),
                  ),
                ),
                const SizedBox(height: 20),
                const PawPulseAuthHeader(
                  title: 'Forgot Password?',
                  subtitle: "No worries, it happens to the best of us. Enter your email below and we'll send you a secure reset code.",
                ),
                PawPulseTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  // Strict format check — same as Login/Signup, not just '@'.
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter an email address.';
                    }
                    bool emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim());
                    if (!emailValid) {
                      return 'Please enter a valid email format.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                PawPulsePrimaryButton(label: 'Send Code', onPressed: _sendResetLink),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('← Back to Sign In', style: TextStyle(color: AppColors.softGrey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}