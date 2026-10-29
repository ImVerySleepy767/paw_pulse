import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pawpulse/services/firebase_service.dart';

// exposes our  layer service across the app workspace
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// stream provider listening to real-time login state updates (MP7 Page 6)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

//=  to fetch the current user's profile details from Firestore
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;

  final doc = await FirebaseFirestore.instance.collection('users').doc(authUser.uid).get();
  return doc.data();
});