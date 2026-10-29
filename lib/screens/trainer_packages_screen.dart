import 'package:flutter/material.dart';
import 'nets_payment_screen.dart';
import 'package:pawpulse/theme/app_theme.dart';

class TrainerPackagesScreen extends StatelessWidget {
  static const String routeName = '/trainer-packages';
  const TrainerPackagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // trainer_id values match the `trainers` table in the Part 1 data dictionary
    final List<Map<String, dynamic>> packages = [
      {
        'trainerId': 'train_jenkins44',
        'title': 'Single Session',
        'price': 85.00,
        'desc': 'A quick, focused 1-on-1 with a certified trainer.',
        'features': ['1 x 45-minute session', 'Basic obedience focus', 'Progress notes after session'],
        'featured': false,
      },
      {
        'trainerId': 'train_wilson09',
        'title': '5-Session Pack',
        'price': 360.00,
        'desc': 'Build lasting habits with a structured weekly plan.',
        'features': ['5 x 45-minute sessions', 'Advanced behavioral plan', 'Weekly progress check-ins', 'Priority scheduling'],
        'featured': true,
      },
      {
        'trainerId': 'train_moreau21',
        'title': '10-Session Pack',
        'price': 680.00,
        'desc': 'Full transformation program for lasting results.',
        'features': ['10 x 45-minute sessions', 'Fully customized plan', 'Direct trainer messaging', 'Free follow-up consult'],
        'featured': false,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('Find Your Expert Trainer'), backgroundColor: AppColors.cream, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Choose a package that fits your goals",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "Whether you're looking for a quick tune-up or a complete transformation, we've got a plan for you.",
            style: TextStyle(color: AppColors.softGrey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ...packages.map((item) => _PackageCard(item: item)).toList(),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PackageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final bool featured = item['featured'] as bool;
    final bg = featured ? AppColors.charcoal : Colors.white;
    final textColor = featured ? Colors.white : AppColors.charcoal;
    final subColor = featured ? Colors.white70 : AppColors.softGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: featured ? Border.all(color: AppColors.terracotta, width: 2) : null,
        boxShadow: [
          if (!featured)
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.terracotta, borderRadius: BorderRadius.circular(20)),
              child: const Text('MOST POPULAR', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          Text(item['title'], style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text(item['desc'], style: TextStyle(fontSize: 13, color: subColor)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${(item['price'] as double).toStringAsFixed(0)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textColor)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text('SGD', style: TextStyle(fontSize: 13, color: subColor)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List<String>.from(item['features']).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: featured ? AppColors.terracotta : AppColors.teal),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f, style: TextStyle(fontSize: 13, color: textColor))),
                  ],
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NetsPaymentScreen(
                      trainerId: item['trainerId'],
                      packageTitle: item['title'],
                      amount: item['price'],
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: featured ? AppColors.terracotta : AppColors.charcoal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Buy Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}