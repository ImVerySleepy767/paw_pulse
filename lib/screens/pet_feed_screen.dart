import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pawpulse/providers/firebase_provider.dart';
import 'package:pawpulse/models/pet_post.dart';
import 'package:pawpulse/theme/app_theme.dart';
import 'package:pawpulse/utils/error_formatter.dart';
import 'package:pawpulse/widgets/confirm_dialog.dart';
import 'package:intl/intl.dart';
import 'create_post_screen.dart';

class PetFeedScreen extends ConsumerWidget {
  static const String routeName = '/pet-feed';
  const PetFeedScreen({super.key});

  /// Writes the base64 image to a temp file so share_plus can attach it
  /// as a real image (the native share sheet needs a file, not raw bytes).
  Future<void> _sharePost(BuildContext context, PetPost post) async {
    try {
      final bytes = base64Decode(post.imageBase64);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pawpulse_share_${post.id}.jpg');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: post.caption.isEmpty ? 'Check out ${post.petName} on PawPulse! 🐾' : post.caption,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(firebaseServiceProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Pet Feed'),
        backgroundColor: AppColors.cream,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.terracotta,
        onPressed: () => Navigator.of(context).pushNamed(CreatePostScreen.routeName),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: service.petPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(friendlyFirebaseError(snapshot.error!), style: const TextStyle(color: Colors.red)),
              ),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pets, size: 56, color: AppColors.softGrey),
                    const SizedBox(height: 12),
                    const Text('No posts yet — be the first to share your pet!', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          final posts = docs.map((d) => PetPost.fromFirestore(d.id, d.data() as Map<String, dynamic>)).toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final post = posts[i];
              final isOwner = post.userId == currentUid;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.terracotta,
                        child: Icon(Icons.pets, color: Colors.white, size: 18),
                      ),
                      title: Text(post.petName.isEmpty ? 'A PawPulse pet' : post.petName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(DateFormat('MMM d, yyyy · h:mm a').format(post.createdAt)),
                      trailing: isOwner
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.grey),
                              onPressed: () async {
                                final confirmed = await confirmDelete(
                                  context,
                                  title: 'Delete this post?',
                                  message: 'This will permanently remove this post from the feed for everyone. This can\'t be undone.',
                                );
                                if (!confirmed) return;
                                await service.deletePetPost(post.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Post deleted')),
                                  );
                                }
                              },
                            )
                          : null,
                    ),
                    AspectRatio(
                      aspectRatio: 1,
                      child: Image.memory(base64Decode(post.imageBase64), fit: BoxFit.cover),
                    ),
                    if (post.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(post.caption),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            onPressed: () => _sharePost(context, post),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}