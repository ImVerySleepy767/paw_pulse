import 'package:firebase_auth/firebase_auth.dart';

/// Converts a raw Firebase exception into a short, actionable message for
/// the user, instead of showing raw error codes like
/// "[cloud_firestore/permission-denied] Missing or insufficient permissions."
String friendlyFirebaseError(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return "You don't have permission to do this. Make sure you're "
            "logged in and that Firestore security rules have been "
            "published in the Firebase Console.";
      case 'unavailable':
        return 'Could not reach the server. Check your internet connection '
            'and try again.';
      case 'failed-precondition':
        return 'This query needs a database index that hasn\'t been '
            'created yet. Check the debug console for a link to create it.';
      case 'not-found':
        return 'That record no longer exists — it may have been deleted.';
      case 'already-exists':
        return 'That record already exists.';
      case 'deadline-exceeded':
        return 'The request took too long. Please try again.';
      default:
        return error.message ?? 'Something went wrong (${error.code}).';
    }
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-not-found':
        return 'No account found with that email.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Please choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts — please wait a few minutes before trying again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection and try again.';
      default:
        return error.message ?? 'Authentication error (${error.code}).';
    }
  }

  return error.toString();
}