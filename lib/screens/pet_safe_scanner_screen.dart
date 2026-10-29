import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:pawpulse/config/gemini_config.example.dart';
import 'package:pawpulse/widgets/image_source_picker.dart';
import 'package:pawpulse/theme/app_theme.dart';

/// Repurposes the old "Scan to Pay" camera slot — NETS QR now has its own
/// dedicated payment flow, so this camera feature does something the app
/// actually needs: is this food/product safe to give my dog?
class PetSafeScannerScreen extends StatefulWidget {
  static const String routeName = '/pet-safe-scanner';
  const PetSafeScannerScreen({super.key});

  @override
  State<PetSafeScannerScreen> createState() => _PetSafeScannerScreenState();
}

enum _Verdict { safe, caution, unsafe, unknown }

class _PetSafeScannerScreenState extends State<PetSafeScannerScreen> {
  late final GenerativeModel _model = GenerativeModel(
    model: GeminiConfig.modelName,
    apiKey: GeminiConfig.apiKey,
  );

  dynamic _photoBytes;
  bool _isAnalyzing = false;
  String? _result;
  _Verdict _verdict = _Verdict.unknown;
  String? _error;

  Future<void> _pickPhoto() async {
    final picked = await pickImageFromCameraOrGallery(context);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _result = null;
      _error = null;
      _verdict = _Verdict.unknown;
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
        "You're looking at a photo of a food item, ingredient label, or "
        "product. Determine whether it is SAFE, something to give with "
        "CAUTION (in moderation, or depends on quantity), or UNSAFE/TOXIC "
        "for dogs. Start your response with exactly one word — SAFE, "
        "CAUTION, or UNSAFE — then a colon, then a 2-3 sentence explanation "
        "naming the specific ingredient(s) of concern if any. Keep the "
        "whole response under 70 words, plain text, no markdown.",
      );
      final imagePart = DataPart('image/jpeg', _photoBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final text = response.text ?? 'No response received — try again.';
      setState(() {
        _result = text;
        _verdict = _parseVerdict(text);
      });
    } catch (e) {
      setState(() => _error = 'Could not analyze the photo: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  _Verdict _parseVerdict(String text) {
    final upper = text.trim().toUpperCase();
    if (upper.startsWith('UNSAFE')) return _Verdict.unsafe;
    if (upper.startsWith('CAUTION')) return _Verdict.caution;
    if (upper.startsWith('SAFE')) return _Verdict.safe;
    return _Verdict.unknown;
  }

  Color get _verdictColor {
    switch (_verdict) {
      case _Verdict.safe:
        return const Color(0xFF3A8A5C);
      case _Verdict.caution:
        return AppColors.mustard;
      case _Verdict.unsafe:
        return const Color(0xFFC0392B);
      case _Verdict.unknown:
        return AppColors.softGrey;
    }
  }

  IconData get _verdictIcon {
    switch (_verdict) {
      case _Verdict.safe:
        return Icons.check_circle;
      case _Verdict.caution:
        return Icons.warning_amber_rounded;
      case _Verdict.unsafe:
        return Icons.dangerous;
      case _Verdict.unknown:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Is This Pet-Safe?'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Snap a photo of any food, treat, or ingredient label — we'll check if it's safe for your dog.",
            style: TextStyle(color: AppColors.softGrey),
          ),
          const SizedBox(height: 16),
          if (_photoBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_photoBytes, height: 220, width: double.infinity, fit: BoxFit.cover),
            )
          else
            Container(
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.restaurant_menu, size: 48, color: AppColors.softGrey),
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
                : const Icon(Icons.pets),
            label: Text(_isAnalyzing ? 'Checking...' : 'Check if Pet-Safe'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.terracotta, foregroundColor: Colors.white),
          ),
          const SizedBox(height: 20),
          if (_result != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _verdictColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _verdictColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_verdictIcon, color: _verdictColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_result!, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          const Text(
            'This is an AI estimate, not veterinary advice — when in doubt, call your vet or the ASPCA Animal Poison Control hotline.',
            style: TextStyle(fontSize: 11, color: AppColors.softGrey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
