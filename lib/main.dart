import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/firebase_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/biometric_provider.dart';
import 'theme/app_theme.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/daily_log_screen.dart';
import 'screens/trainer_packages_screen.dart';
import 'screens/phone_auth_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/email_verification_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/food_calorie_screen.dart';
import 'screens/pet_safe_scanner_screen.dart';
import 'screens/nearby_vets_screen.dart';
import 'screens/pet_feed_screen.dart';
import 'screens/create_post_screen.dart';
import 'widgets/auth_gate.dart';
import 'widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PawPulse',
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox()),
      home: authState.when(
        data: (user) {
          if (user == null) return const LoginScreen();

          // Only email/password accounts have an email to verify. Phone-auth
          // users have no email at all (user.email is null), so gating them
          // here would trap them on a screen that can never succeed.
          final signedUpWithEmail = user.providerData.any((p) => p.providerId == 'password');
          if (signedUpWithEmail && !user.emailVerified) {
            return const EmailVerificationScreen();
          }

          // Biometric app-lock gate: only shown if the user has turned it
          // on in Profile, and only once per cold app start (session flag).
          final biometricEnabled = ref.watch(biometricPreferenceProvider).value ?? false;
          final sessionUnlocked = ref.watch(sessionUnlockedProvider);
          if (biometricEnabled && !sessionUnlocked) {
            return const BiometricLockScreen();
          }

          return HomeScreen();
        },
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      ),
      routes: {
        LoginScreen.routeName: (context) => const LoginScreen(),
        SignupScreen.routeName: (context) => const SignupScreen(),
        HomeScreen.routeName: (context) => AuthGate(child: HomeScreen()),
        DailyLogScreen.routeName: (context) => const AuthGate(child: DailyLogScreen()),
        TrainerPackagesScreen.routeName: (context) => const AuthGate(child: TrainerPackagesScreen()),
        PhoneAuthScreen.routeName: (context) => const PhoneAuthScreen(),
        ResetPasswordScreen.routeName: (context) => const ResetPasswordScreen(),
        ChangePasswordScreen.routeName: (context) => const AuthGate(child: ChangePasswordScreen()),
        ProfileScreen.routeName: (context) => const AuthGate(child: ProfileScreen()),
        EmailVerificationScreen.routeName: (context) => const EmailVerificationScreen(),
        AiAssistantScreen.routeName: (context) => const AuthGate(child: AiAssistantScreen()),
        InsightsScreen.routeName: (context) => const AuthGate(child: InsightsScreen()),
        CalendarScreen.routeName: (context) => const AuthGate(child: CalendarScreen()),
        FoodCalorieScreen.routeName: (context) => const AuthGate(child: FoodCalorieScreen()),
        PetSafeScannerScreen.routeName: (context) => const AuthGate(child: PetSafeScannerScreen()),
        NearbyVetsScreen.routeName: (context) => const AuthGate(child: NearbyVetsScreen()),
        PetFeedScreen.routeName: (context) => const AuthGate(child: PetFeedScreen()),
        CreatePostScreen.routeName: (context) => const AuthGate(child: CreatePostScreen()),
      },
    );
  }
}