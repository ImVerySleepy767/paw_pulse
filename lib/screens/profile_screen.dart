import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/providers/theme_provider.dart';
import 'package:pawpulse/providers/biometric_provider.dart';
import 'package:pawpulse/providers/notification_provider.dart';
import 'package:pawpulse/providers/email_verification_provider.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'change_password_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  static const String routeName = '/profile';
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Held locally so an edit shows immediately — Firebase's authStateChanges()
  // stream does not re-emit just because displayName was updated, only on
  // sign-in/sign-out, so we can't rely on the provider alone for this.
  String? _localDisplayName;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final themeMode = ref.watch(themeModeProvider);
    final biometricEnabledAsync = ref.watch(biometricPreferenceProvider);
    final notificationEnabledAsync = ref.watch(notificationPreferenceProvider);

    final displayName = _localDisplayName ?? user?.displayName;
    final fallbackName = user?.email?.split('@').first ?? 'Pet Parent';
    final shownName = (displayName != null && displayName.trim().isNotEmpty) ? displayName : fallbackName;
    final initial = shownName.isNotEmpty ? shownName[0].toUpperCase() : '?';

    // Theme-aware colors — this is the actual dark mode fix. The old version
    // hardcoded AppColors.cream / Colors.white everywhere, so the screen
    // never changed appearance even though themeModeProvider was working
    // correctly and MaterialApp was already switching theme/darkTheme.
    final scheme = Theme.of(context).colorScheme;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final onSurface = scheme.onSurface;
    final onSurfaceMuted = scheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: scaffoldBg,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: AppColors.terracotta, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () => _editUsername(context, ref, currentValue: shownName == fallbackName ? '' : shownName),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                            border: Border.all(color: scaffoldBg, width: 2),
                          ),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  shownName,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  user?.email ?? 'Unknown User',
                  style: TextStyle(fontSize: 13, color: onSurfaceMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _SettingsSection(
            title: 'Personalisation',
            cardColor: cardColor,
            onSurface: onSurface,
            children: [
              _SettingsRow(
                icon: Icons.dark_mode,
                iconColor: AppColors.charcoal,
                title: 'Dark Mode',
                subtitle: themeMode == ThemeMode.dark
                    ? 'Currently on'
                    : themeMode == ThemeMode.light
                        ? 'Currently off'
                        : 'Following system setting',
                onSurface: onSurface,
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  activeColor: AppColors.terracotta,
                  onChanged: (val) => ref.read(themeModeProvider.notifier).setMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _SettingsSection(
            title: 'Security',
            cardColor: cardColor,
            onSurface: onSurface,
            children: [
              // Authentication method not taught in class: biometric app-lock.
              _SettingsRow(
                icon: Icons.fingerprint,
                iconColor: AppColors.terracotta,
                title: 'Biometric Lock',
                subtitle: 'Require fingerprint/Face ID to reopen the app',
                onSurface: onSurface,
                trailing: Switch(
                  value: biometricEnabledAsync.value ?? false,
                  activeColor: AppColors.terracotta,
                  onChanged: (val) => ref.read(biometricPreferenceProvider.notifier).setEnabled(val),
                ),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.lock_reset,
                iconColor: AppColors.teal,
                title: 'Change Password',
                subtitle: 'Update your account credentials securely',
                onSurface: onSurface,
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: onSurfaceMuted),
                onTap: () => Navigator.of(context).pushNamed(ChangePasswordScreen.routeName),
              ),
              const Divider(height: 1, indent: 68),
              _SettingsRow(
                icon: Icons.mark_email_read,
                iconColor: AppColors.teal,
                title: 'Verify Email Address',
                subtitle: user?.emailVerified == true ? 'Status: Verified' : 'Status: Unverified',
                onSurface: onSurface,
                trailing: Icon(Icons.arrow_forward_ios, size: 14, color: onSurfaceMuted),
                onTap: () async {
                  final lastSent = ref.read(lastVerificationSentProvider);
                  final withinCooldown = lastSent != null &&
                      DateTime.now().difference(lastSent) < verificationResendCooldown;
                  if (withinCooldown) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please wait before requesting another email.')),
                      );
                    }
                    return;
                  }
                  try {
                    await user?.sendEmailVerification();
                    ref.read(lastVerificationSentProvider.notifier).markSentNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification email sent! Check your inbox.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          _SettingsSection(
            title: 'Notifications',
            cardColor: cardColor,
            onSurface: onSurface,
            children: [
              // Local notifications — Duolingo-style daily reminder.
              _SettingsRow(
                icon: Icons.notifications_active_outlined,
                iconColor: AppColors.mustard,
                title: 'Daily Log Reminder',
                subtitle: kIsWeb
                    ? 'Not supported on web — test on Android'
                    : "Get a nudge at 7 PM if you haven't logged today",
                onSurface: onSurface,
                trailing: Switch(
                  value: notificationEnabledAsync.value ?? false,
                  activeColor: AppColors.terracotta,
                  onChanged: kIsWeb
                      ? null
                      : (val) async {
                          try {
                            await ref.read(notificationPreferenceProvider.notifier).setEnabled(val);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(val ? 'Reminder scheduled' : 'Reminder cancelled')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Notification error: $e')),
                              );
                            }
                          }
                        },
                ),
              ),
              if (!kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(left: 68, right: 16, bottom: 12, top: 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        try {
                          await ref.read(notificationServiceProvider).triggerTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Test notification will appear in 5 seconds — minimize the app now')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Test notification error: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.notifications_active, size: 16),
                      label: const Text('Send Test Notification (5s)'),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _editUsername(BuildContext context, WidgetRef ref, {required String currentValue}) async {
    final controller = TextEditingController(text: currentValue);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Enter a display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      await user.updateDisplayName(newName);
      await user.reload();
      if (!mounted) return;
      setState(() => _localDisplayName = newName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update username: $e')),
        );
      }
    }
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color cardColor;
  final Color onSurface;
  const _SettingsSection({
    required this.title,
    required this.children,
    required this.cardColor,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: onSurface.withValues(alpha: 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final Color onSurface;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onSurface,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}