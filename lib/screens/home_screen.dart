import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pawpulse/utils/date_formatter.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/providers/biometric_provider.dart';
import 'package:pawpulse/widgets/dashboard_header.dart';
import 'package:pawpulse/widgets/confirm_dialog.dart';
import 'package:pawpulse/screens/daily_log_screen.dart';
import 'package:pawpulse/screens/trainer_packages_screen.dart';
import 'package:pawpulse/screens/profile_screen.dart';
import 'package:pawpulse/screens/edit_log_screen.dart';
import 'package:pawpulse/screens/ai_assistant_screen.dart';
import 'package:pawpulse/screens/insights_screen.dart';
import 'package:pawpulse/screens/calendar_screen.dart';
import 'package:pawpulse/screens/pet_safe_scanner_screen.dart';
import 'package:pawpulse/screens/nearby_vets_screen.dart';
import 'package:pawpulse/screens/pet_feed_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const String routeName = '/home';
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final logsStream = ref.watch(firebaseServiceProvider).getHealthLogsStream();

    return Scaffold(
      appBar: AppBar(
        title: const Text('PawPulse'),
        actions: [
          IconButton(
            tooltip: 'Nearby Vets',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.of(context).pushNamed(NearbyVetsScreen.routeName),
          ),
          IconButton(
            tooltip: 'Pet Feed',
            icon: const Icon(Icons.dynamic_feed),
            onPressed: () => Navigator.of(context).pushNamed(PetFeedScreen.routeName),
          ),
          IconButton(
            tooltip: 'Is This Pet-Safe?',
            icon: const Icon(Icons.pets),
            onPressed: () => Navigator.of(context).pushNamed(PetSafeScannerScreen.routeName),
          ),
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.of(context).pushNamed(CalendarScreen.routeName),
          ),
          IconButton(
            tooltip: 'Insights',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).pushNamed(InsightsScreen.routeName),
          ),
          IconButton(
            tooltip: 'AI Assistant',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AiAssistantScreen.routeName),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionUnlockedProvider.notifier).lock();
              ref.read(firebaseServiceProvider).logout();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: logsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Error loading logs:\n${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final latest = docs.isNotEmpty ? docs.first.data() as Map<String, dynamic> : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DashboardHeader(
                petName: latest?['pet_name'] ?? '',
                latestWeight: (latest?['weight'] as num?)?.toDouble(),
                latestCalories: (latest?['calorie_intake'] as num?)?.toInt(),
                latestRestMinutes: (latest?['pet_resttime'] as num?)?.toInt(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Recent Logs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No pet health records found. Add one below!')),
                )
              else
                ...docs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value.data() as Map<String, dynamic>;
                  final docId = entry.value.id;

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 300 + (index * 60)),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 16),
                          child: child,
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.pets)),
                        title: Text('${data['pet_name']} (${formatLogDate(data['log_date'])})'),
                        subtitle: Text(
                          'Weight: ${data['weight']}kg | Cal: ${data['calorie_intake']} kcal\nRest: ${data['pet_resttime']} mins',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.of(context).push(
                                  PageRouteBuilder(
                                    transitionDuration: const Duration(milliseconds: 250),
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        EditLogScreen(docId: docId, initialData: data),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirmed = await confirmDelete(
                                  context,
                                  title: 'Delete this log?',
                                  message: "This will permanently delete ${data['pet_name'] ?? 'this'}'s log entry. This can't be undone.",
                                );
                                if (!confirmed) return;
                                await ref.read(firebaseServiceProvider).deleteHealthLog(docId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Log entry deleted')),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-log-fab',
        onPressed: () => Navigator.of(context).pushNamed(DailyLogScreen.routeName),
        tooltip: 'Add Pet Log',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            Navigator.of(context).pushNamed(TrainerPackagesScreen.routeName).then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
          } else if (index == 2) {
            Navigator.of(context).pushNamed(ProfileScreen.routeName).then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Marketplace'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}