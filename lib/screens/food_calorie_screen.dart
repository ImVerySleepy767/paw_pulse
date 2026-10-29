import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pawpulse/config/gemini_config.example.dart';
import 'package:pawpulse/widgets/image_source_picker.dart';
import 'package:pawpulse/theme/app_theme.dart';

class FoodCalorieScreen extends StatefulWidget {
  static const String routeName = '/food-calorie';
  const FoodCalorieScreen({super.key});

  @override
  State<FoodCalorieScreen> createState() => _FoodCalorieScreenState();
}

class _FoodCalorieScreenState extends State<FoodCalorieScreen> {
  late final GenerativeModel _model = GenerativeModel(
    model: GeminiConfig.modelName,
    apiKey: GeminiConfig.apiKey,
  );

  Uint8List? _photoBytes;
  bool _isAnalyzing = false;
  String? _result;
  String? _error;

  Future<void> _pickPhoto() async {
    final picked = await pickImageFromCameraOrGallery(context);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_photoBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _error = null;
      _result = null;
    });

    try {
      final prompt = TextPart(
        "You're looking at a photo of pet food (dog or cat food, wet or dry, "
        "kibble, or a home-prepared meal). Based on what you can see — the "
        "portion size, food type, and any visible packaging — give a rough "
        "estimated calorie count for this serving. Be clear this is an "
        "approximation, not a precise measurement. Keep the whole response "
        "under 80 words, plain text, no markdown formatting.",
      );
      final imagePart = DataPart('image/jpeg', _photoBytes!);

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      setState(() => _result = response.text ?? 'No response received — try again.');
    } catch (e) {
      setState(() => _error = 'Could not analyze the photo: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Food Calorie Estimator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Snap a photo of your pet\'s food and get a rough calorie estimate.',
            style: TextStyle(color: AppColors.softGrey),
          ),
          const SizedBox(height: 16),

          if (_photoBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_photoBytes!, height: 220, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant, size: 48, color: AppColors.softGrey),
            ),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.add_a_photo),
            label: Text(_photoBytes == null ? 'Take or Choose a Photo' : 'Retake Photo'),
          ),
          const SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _photoBytes == null || _isAnalyzing ? null : _analyze,
            icon: _isAnalyzing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_isAnalyzing ? 'Analyzing...' : 'Estimate Calories'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.terracotta, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 20),

          if (_result != null)
            Card(
              color: AppColors.teal.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: AppColors.teal, size: 18),
                        SizedBox(width: 6),
                        Text('Estimate', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_result!),
                  ],
                ),
              ),
            ),

          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
