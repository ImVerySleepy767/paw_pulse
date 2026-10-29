import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Shows a small action sheet letting the user pick Camera or Gallery.
/// Returns the picked XFile, or null if cancelled.
Future<XFile?> pickImageFromCameraOrGallery(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take Photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (source == null) return null;

  final picker = ImagePicker();
  return picker.pickImage(source: source, imageQuality: 60, maxWidth: 800);
}
