import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/utils/error_formatter.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'package:pawpulse/widgets/image_source_picker.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  static const String routeName = '/calendar';
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  String? _dayPhotoBase64;
  bool _isLoadingPhoto = false;
  bool _isUploading = false;

  // Dates (yyyy-MM-dd) that have at least one log — used to draw markers.
  Set<String> _logDates = {};

  String get _selectedDateString => DateFormat('yyyy-MM-dd').format(_selectedDay);
  String _dateString(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  void initState() {
    super.initState();
    _loadPhotoForSelectedDay();
    _loadLogDates();
  }

  Future<void> _loadLogDates() async {
    final dates = await ref.read(firebaseServiceProvider).getAllLogDates();
    if (mounted) setState(() => _logDates = dates);
  }

  Future<void> _loadPhotoForSelectedDay() async {
    setState(() => _isLoadingPhoto = true);
    try {
      final photo = await ref.read(firebaseServiceProvider).getDayPhoto(_selectedDateString);
      if (mounted) setState(() => _dayPhotoBase64 = photo);
    } catch (_) {
      if (mounted) setState(() => _dayPhotoBase64 = null);
    } finally {
      if (mounted) setState(() => _isLoadingPhoto = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await pickImageFromCameraOrGallery(context);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      await ref.read(firebaseServiceProvider).saveDayPhoto(
            date: _selectedDateString,
            base64Image: base64Image,
          );
      if (mounted) setState(() => _dayPhotoBase64 = base64Image);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyFirebaseError(e))));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(firebaseServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              // A non-empty "event" list for a day makes TableCalendar draw
              // a marker dot under it — used here to flag days with logs.
              eventLoader: (day) => _logDates.contains(_dateString(day)) ? const [true] : const [],
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadPhotoForSelectedDay();
              },
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                selectedDecoration: BoxDecoration(color: AppColors.terracotta, shape: BoxShape.circle),
                markerDecoration: BoxDecoration(color: AppColors.mustard, shape: BoxShape.circle),
                markersMaxCount: 1,
                markerSize: 6,
                markerMargin: EdgeInsets.only(top: 4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.mustard, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('= day has a logged entry', style: TextStyle(fontSize: 12, color: AppColors.softGrey)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(_selectedDay),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // --- Day photo ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_isLoadingPhoto)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )
                  else if (_dayPhotoBase64 != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_dayPhotoBase64!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('No photo for this day yet', style: TextStyle(color: AppColors.softGrey)),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadPhoto,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_a_photo),
                    label: Text(_dayPhotoBase64 == null ? 'Add Photo for this Day' : 'Replace Photo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Logs for selected day ---
          const Text('Logs for this day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<List<QueryDocumentSnapshot>>(
            stream: service.getLogsForDate(_selectedDateString),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(friendlyFirebaseError(snapshot.error!), style: const TextStyle(color: Colors.red)),
                );
              }
              final docs = snapshot.data ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No logs recorded on this day.')),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.pets),
                      title: Text('${data['pet_name']}'),
                      subtitle: Text(
                        'Weight: ${data['weight']}kg | Cal: ${data['calorie_intake']} kcal | Rest: ${data['pet_resttime']} min',
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}