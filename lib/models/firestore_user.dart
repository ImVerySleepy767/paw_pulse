import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUser {
  final String id;
  final String fullName;
  final String phoneNumber;

  FirestoreUser({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
  });

  // Factory constructor to cleanly convert Firestore documents into a Dart Object
  static FirestoreUser fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return FirestoreUser(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
    );
  }
}