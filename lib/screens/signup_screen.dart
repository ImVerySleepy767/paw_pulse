import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'package:pawpulse/widgets/pawpulse_auth_header.dart';
import 'package:pawpulse/widgets/pawpulse_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  static const String routeName = '/signup';
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref.read(firebaseServiceProvider).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
                const PawPulseAuthHeader(
                  title: 'Join the pack!',
                  subtitle: 'Create your account and give your pet the best care around.',
                ),
                PawPulseTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  validator: (val) => val == null || val.isEmpty ? 'Please provide a full name.' : null,
                ),
                PawPulseTextField(
                  controller: _phoneController,
                  label: 'Phone Number (8 digits)',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.length != 8 ? 'Phone number must be exactly 8 characters.' : null,
                ),
                PawPulseTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
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
                PawPulseTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (val) => val == null || val.length < 6 ? 'Minimum 6 characters required' : null,
                ),
                const SizedBox(height: 8),
                PawPulsePrimaryButton(label: 'Sign Up', onPressed: _register),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'By signing up, you agree to our Terms of Service and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}