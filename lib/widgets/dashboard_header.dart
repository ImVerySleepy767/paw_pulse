import 'package:flutter/material.dart';
import 'package:pawpulse/theme/app_theme.dart';

/// Recreates the "Morning Update" dashboard header from the Figma design:
/// a circular progress ring (today's calorie goal %) plus three colored
/// stat cards (weight, rest, calories) in a row.
class DashboardHeader extends StatelessWidget {
  final String petName;
  final double? latestWeight;
  final int? latestCalories;
  final int? latestRestMinutes;
  final int calorieGoal;

  const DashboardHeader({
    super.key,
    required this.petName,
    required this.latestWeight,
    required this.latestCalories,
    required this.latestRestMinutes,
    this.calorieGoal = 1200,
  });

  @override
  Widget build(BuildContext context) {
    final progress = latestCalories == null
        ? 0.0
        : (latestCalories! / calorieGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Morning Update',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      petName.isEmpty ? 'Your Pet' : petName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Circular calorie-goal progress ring, animated on load.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                        Text(
                          '${(value * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  color: AppColors.mustard,
                  label: 'Weight',
                  value: latestWeight == null ? '—' : '${latestWeight!.toStringAsFixed(1)} kg',
                  icon: Icons.monitor_weight_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  color: AppColors.teal,
                  label: 'Rest',
                  value: latestRestMinutes == null ? '—' : '$latestRestMinutes min',
                  icon: Icons.bedtime_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  color: Colors.white,
                  label: 'Calories',
                  value: latestCalories == null ? '—' : '$latestCalories kcal',
                  icon: Icons.local_fire_department_outlined,
                  darkText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final IconData icon;
  final bool darkText;

  const _StatCard({
    required this.color,
    required this.label,
    required this.value,
    required this.icon,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = darkText ? AppColors.charcoal : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          Text(
            label,
            style: TextStyle(color: textColor.withValues(alpha: 0.75), fontSize: 11),
          ),
        ],
      ),
    );
  }
}