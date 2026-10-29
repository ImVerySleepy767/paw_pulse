import 'package:flutter/material.dart';
import 'package:pawpulse/theme/app_theme.dart';

/// Shared branded header used across all auth screens (Login, Signup,
/// Forgot Password, Reset Password) — matches the Figma design's
/// consistent "PawPulse" wordmark + heart badge treatment.
class PawPulseAuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const PawPulseAuthHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PawPulse',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.terracotta,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.terracotta,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 12),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.softGrey, fontSize: 14),
          ),
        ],
        const SizedBox(height: 28),
      ],
    );
  }
}
