import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/utils/error_formatter.dart';
import 'package:pawpulse/widgets/image_source_picker.dart';
import 'food_calorie_screen.dart';

class DailyLogScreen extends ConsumerStatefulWidget {
  static const String routeName = '/daily-log';
  const DailyLogScreen({super.key});

  @override
  ConsumerState<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends ConsumerState<DailyLogScreen> {
  final _formKey = GlobalKey<FormState>();

  String _petName = '';
  int _calories = 0;
  int _restTime = 0;
  double _weight = 0.0;

  Uint8List? _photoBytes;
  bool _isPickingPhoto = false;

  Future<void> _attachPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final picked = await pickImageFromCameraOrGallery(context);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _photoBytes = bytes);
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      await ref.read(firebaseServiceProvider).addHealthLog(
        petName: _petName,
        calorieIntake: _calories,
        weight: _weight,
        petRestTime: _restTime,
      );

      // Optional: attach the photo to today's calendar entry too.
      if (_photoBytes != null) {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        await ref.read(firebaseServiceProvider).saveDayPhoto(
              date: today,
              base64Image: base64Encode(_photoBytes!),
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet metric recorded successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyFirebaseError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Daily Pet Log')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
            children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Pet Name'),
              validator: (val) => val == null || val.isEmpty ? 'Enter pet name' : null,
              onSaved: (val) => _petName = val!.trim(),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Calorie Intake (kcal)'),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter calories';
                if (int.tryParse(val) == null) return 'Please enter a valid number';
                return null;
              },
              onSaved: (val) => _calories = int.parse(val!),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(FoodCalorieScreen.routeName),
                icon: const Icon(Icons.restaurant, size: 16),
                label: const Text('Not sure? Estimate from a photo'),
              ),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Rest Duration (Minutes)'),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter rest time';
                if (int.tryParse(val) == null) return 'Please enter a valid number';
                return null;
              },
              onSaved: (val) => _restTime = int.parse(val!),
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Current Weight (kg)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Enter weight';
                if (double.tryParse(val) == null) return 'Please enter a valid decimal number';
                return null;
              },
              onSaved: (val) => _weight = double.parse(val!),
            ),
            const SizedBox(height: 16),

            // Optional photo attachment (Camera or Gallery).
            if (_photoBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_photoBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isPickingPhoto ? null : _attachPhoto,
              icon: _isPickingPhoto
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_photoBytes == null ? 'Attach a Photo (optional)' : 'Change Photo'),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveForm,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Save Metric'),
            )
          ],
        ),
      ),
    );
  }
}