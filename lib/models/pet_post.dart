class PetPost {
  final String id;
  final String userId;
  final String petName;
  final String caption;
  final String imageBase64;
  final DateTime createdAt;

  PetPost({
    required this.id,
    required this.userId,
    required this.petName,
    required this.caption,
    required this.imageBase64,
    required this.createdAt,
  });

  factory PetPost.fromFirestore(String id, Map<String, dynamic> data) {
    return PetPost(
      id: id,
      userId: data['user_id'] ?? '',
      petName: data['pet_name'] ?? '',
      caption: data['caption'] ?? '',
      imageBase64: data['image_base64'] ?? '',
      createdAt: (data['created_at'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }
}
