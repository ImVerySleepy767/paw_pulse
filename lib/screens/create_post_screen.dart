import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'package:pawpulse/widgets/image_source_picker.dart';
import 'package:pawpulse/utils/error_formatter.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  static const String routeName = '/create-post';
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _petNameController = TextEditingController();
  final _captionController = TextEditingController();
  Uint8List? _photoBytes;
  bool _isPosting = false;

  Future<void> _pickPhoto() async {
    final picked = await pickImageFromCameraOrGallery(context);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _post() async {
    if (_photoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo first!')),
      );
      return;
    }
    setState(() => _isPosting = true);
    try {
      await ref.read(firebaseServiceProvider).addPetPost(
            petName: _petNameController.text.trim(),
            caption: _captionController.text.trim(),
            imageBase64: base64Encode(_photoBytes!),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyFirebaseError(e))));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('New Post'),
        backgroundColor: AppColors.cream,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _post,
            child: _isPosting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: _photoBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.softGrey),
                          SizedBox(height: 8),
                          Text('Tap to add a photo', style: TextStyle(color: AppColors.softGrey)),
                        ],
                      ),
                    )
                  : Image.memory(_photoBytes!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _petNameController,
            decoration: const InputDecoration(labelText: "Pet's Name", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _captionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Caption',
              hintText: "What's your pet up to today?",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
