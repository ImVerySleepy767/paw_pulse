import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:pawpulse/utils/date_formatter.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection names centralised as constants so a typo can't cause a
  // silent mismatch again (this is what broke updateHealthLog before).
  static const String _healthLogCollection = 'daily_health_log';
  static const String _usersCollection = 'users';

  // ===========================================================
  // AUTHENTICATION
  // ===========================================================

  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Verification email is sent exactly once, right here at registration —
    // not repeatedly whenever the gate screen happens to open. Simpler to
    // reason about and matches how most real apps handle this.
    await credential.user?.sendEmailVerification();

    // FIX: previously keyed the profile doc by email, but userProfileProvider
    // looks it up by UID. Now keyed by the Firebase Auth UID, matching the
    // Part 1 data dictionary (User_id = Firebase-generated UID).
    if (credential.user != null) {
      await addUserInfo(
        uid: credential.user!.uid,
        email: email,
        fullName: fullName,
        phoneNumber: phoneNumber,
      );
    }
    return credential;
  }

  Future<void> addUserInfo({
    required String uid,
    required String email,
    required String fullName,
    required String phoneNumber,
  }) async {
    await _db.collection(_usersCollection).doc(uid).set({
      'email': email,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(FirebaseAuthException e) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: onError,
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> signInWithSMSCode({
    required String verificationId,
    required String smsCode,
  }) async {
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred while trying to send the reset link.');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    User? user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found.');
    }
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Failed to update password. Verify your current credentials.');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn(
      clientId: '281718353704-gq5q2s4gn2iftr00reegenuhhdorfggd.apps.googleusercontent.com',
    ).signIn();

    if (googleUser == null) throw Exception('Google Sign-In cancelled by user.');

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ===========================================================
  // BASIC CRUD — daily_health_log
  // ===========================================================
/// Buckets a DateTime into Morning (5am–<12pm), Afternoon (12pm–<6pm),
/// or Night (6pm–<5am) so every log can be filtered by time of day.
String _getTimePeriod(DateTime time) {
  final hour = time.hour;
  if (hour >= 5 && hour < 12) return 'Morning';
  if (hour >= 12 && hour < 18) return 'Afternoon';
  return 'Night';
}

Future<void> addHealthLog({
  required String petName,
  required int calorieIntake,
  required double weight,
  required int petRestTime,
}) async {
  final String? uid = _auth.currentUser?.uid;
  if (uid == null) return;

  final now = DateTime.now();
  await _db.collection(_healthLogCollection).add({
    'user_id': uid,
    'pet_name': petName,
    'calorie_intake': calorieIntake,
    'weight': weight,
    'pet_resttime': petRestTime,
    'log_date': now.toIso8601String().split('T')[0],
    'time_period': _getTimePeriod(now),
    'created_at': FieldValue.serverTimestamp(),
  });
}

  Stream<QuerySnapshot> getHealthLogsStream() {
    return _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: _auth.currentUser?.uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // FIX: now targets the same collection everything else uses
  // (daily_health_log, not the non-existent health_logs).
  Future<void> updateHealthLog({
    required String docId,
    required String petName,
    required int calorieIntake,
    required double weight,
    required int petRestTime,
  }) async {
    await _db.collection(_healthLogCollection).doc(docId).update({
      'pet_name': petName,
      'calorie_intake': calorieIntake,
      'weight': weight,
      'pet_resttime': petRestTime,
    });
  }

  Future<void> deleteHealthLog(String logId) async {
    await _db.collection(_healthLogCollection).doc(logId).delete();
  }

/// Fetches the distinct pet names present across this user's logs —
/// used to build the Insights filter dropdown from real data instead
/// of a hardcoded guess that can silently go stale.
Future<List<String>> getDistinctPetNames() async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return [];
  final snapshot = await _db.collection(_healthLogCollection).where('user_id', isEqualTo: uid).get();
  final names = snapshot.docs
      .map((doc) => (doc.data()['pet_name'] ?? '').toString())
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();
  names.sort();
  return names;
}

  // ===========================================================
  // ADVANCED QUERIES (Part 3 rubric — 2.5%)
  // Each of these hits a distinct rubric sub-category so they're kept
  // as separate named methods rather than one mega-query function.
  // ===========================================================

  /// Filter with a criterion OTHER than the identifier (user_id).
  /// Filters logs down to a single pet's records.
/// Filter with a criterion OTHER than the identifier (user_id).
/// Filters logs down to a single pet's records, sorted by date so
/// results stay in a predictable order — equality filters alone don't
/// guarantee any particular ordering from Firestore, which is why dates
/// were appearing scrambled.
Stream<QuerySnapshot> getLogsByPetName(String petName, {bool descending = true}) {
  return _db
      .collection(_healthLogCollection)
      .where('user_id', isEqualTo: _auth.currentUser?.uid)
      .where('pet_name', isEqualTo: petName)
      .orderBy('log_date', descending: descending)
      .snapshots();
}

  /// Multiple filter criteria on the SAME field (weight range).
  Stream<QuerySnapshot> getLogsByWeightRange(double minWeight, double maxWeight) {
    return _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: _auth.currentUser?.uid)
        .where('weight', isGreaterThanOrEqualTo: minWeight)
        .where('weight', isLessThanOrEqualTo: maxWeight)
        .snapshots();
  }

  /// Multiple filter criteria on DIFFERENT fields (pet + minimum calories).
  Stream<QuerySnapshot> getLogsByPetAndMinCalories(String petName, int minCalories) {
    return _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: _auth.currentUser?.uid)
        .where('pet_name', isEqualTo: petName)
        .where('calorie_intake', isGreaterThanOrEqualTo: minCalories)
        .snapshots();
  }

  /// Sort order — most recent first or oldest first.
  Stream<QuerySnapshot> getLogsSorted({bool descending = true}) {
    return _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: _auth.currentUser?.uid)
        .orderBy('log_date', descending: descending)
        .snapshots();
  }
  /// Filter — logs matching a specific time of day (Morning/Afternoon/Night).
/// Filter — logs matching a specific time of day (Morning/Afternoon/Night), sorted by date.
Stream<QuerySnapshot> getLogsByTimePeriod(String timePeriod, {bool descending = true}) {
  return _db
      .collection(_healthLogCollection)
      .where('user_id', isEqualTo: _auth.currentUser?.uid)
      .where('time_period', isEqualTo: timePeriod)
      .orderBy('log_date', descending: descending)
      .snapshots();
}
  /// Aggregation — average calorie intake and weight across all of this
  /// user's logs, computed server-side via Firestore's aggregate query.
  Future<Map<String, double>> getHealthLogAggregates() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {'avgCalories': 0, 'avgWeight': 0, 'count': 0};

    final query = _db.collection(_healthLogCollection).where('user_id', isEqualTo: uid);

    final countSnapshot = await query.count().get();
    final avgCaloriesSnapshot = await query.aggregate(average('calorie_intake')).get();
    final avgWeightSnapshot = await query.aggregate(average('weight')).get();

    return {
      'count': (countSnapshot.count ?? 0).toDouble(),
      'avgCalories': avgCaloriesSnapshot.getAverage('calorie_intake') ?? 0,
      'avgWeight': avgWeightSnapshot.getAverage('weight') ?? 0,
    };
  }

  // ===========================================================
  // NETS PAYMENT — transaction logging (matches Part 1 data dictionary)
  // ===========================================================

  Future<void> recordTransaction({
    required String transactionId,
    required String trainerId,
    required double amount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user found.');

    await _db.collection('transactions').doc(transactionId).set({
      'transaction_id': transactionId,
      'user_id': uid,
      'trainer_id': trainerId,
      'amount': amount,
      'paid_at': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches the most recent log for a pet — used to give the AI
  /// assistant real context about the user's data (Applied AI feature).
  Future<Map<String, dynamic>?> getLatestHealthLog() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final snapshot = await _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  /// Fetches the set of all dates (yyyy-MM-dd) that have at least one log,
  /// used to mark those days on the calendar.
  Future<Set<String>> getAllLogDates() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};
    final snapshot = await _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: uid)
        .get();
    return snapshot.docs
        .map((doc) => formatLogDate(doc.data()['log_date']))
        .where((d) => d.isNotEmpty && d != 'Unknown date')
        .toSet();
  }

  // ===========================================================
  // CALENDAR — per-day logs + day photo
  // Photo stored as base64 text directly in Firestore (same pattern
  // as the MP9 receipt-scanning lab) — avoids needing paid Firebase
  // Storage, which the project spec explicitly disallows.
  // ===========================================================

  /// Fetches all health logs for a specific date (format: yyyy-MM-dd).
  /// Returns logs for a specific day. Filters client-side using
  /// formatLogDate() rather than a server-side `.where('log_date', ...)`
  /// equality check — Firestore's equality filter requires an EXACT type
  /// match, so a record where log_date was accidentally saved as a
  /// Timestamp instead of a String would silently never match a String
  /// query and vanish from results with no error. Filtering client-side
  /// after normalizing both formats avoids that failure mode entirely.
  Stream<List<QueryDocumentSnapshot>> getLogsForDate(String date) {
    final uid = _auth.currentUser?.uid;
    return _db.collection(_healthLogCollection).where('user_id', isEqualTo: uid).snapshots().map(
          (snapshot) => snapshot.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return formatLogDate(data['log_date']) == date;
          }).toList(),
        );
  }

  /// Saves (or overwrites) a base64-encoded photo for a specific day.
  Future<void> saveDayPhoto({required String date, required String base64Image}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user found.');
    await _db.collection('day_photos').doc('${uid}_$date').set({
      'user_id': uid,
      'date': date,
      'image_base64': base64Image,
      'uploaded_at': FieldValue.serverTimestamp(),
    });
  }

  /// Fetches the saved photo (if any) for a specific day.
  Future<String?> getDayPhoto(String date) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('day_photos').doc('${uid}_$date').get();
    if (!doc.exists) return null;
    return doc.data()?['image_base64'] as String?;
  }
  /// single text block for the AI prompt. Following the lab pattern
  /// (build the context string once, reuse it for every message) instead
  /// of re-querying Firestore on every single chat message, which is
  /// slow and burns extra reads for no benefit — the pet's logged data
  /// doesn't change mid-conversation.
  Future<String> getHealthLogsContextText({int limit = 10}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'No pet health data available.';

    final snapshot = await _db
        .collection(_healthLogCollection)
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    if (snapshot.docs.isEmpty) return 'No health logs have been recorded yet.';

    final buffer = StringBuffer();
    for (final doc in snapshot.docs) {
      final d = doc.data();
      buffer.writeln(
        '- ${d['log_date']}: ${d['pet_name']}, weight ${d['weight']}kg, '
        'calorie intake ${d['calorie_intake']}kcal, rest ${d['pet_resttime']}min',
      );
    }
    return buffer.toString();
  }

  // ===========================================================
  // PET FEED — public Instagram-style feed of shared pet photos.
  // Base64-in-Firestore, same pattern as day_photos, keeps images
  // small (image_picker already caps quality/width on capture).
  // ===========================================================

  Future<void> addPetPost({
    required String petName,
    required String caption,
    required String imageBase64,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('No authenticated user found.');
    await _db.collection('pet_posts').add({
      'user_id': uid,
      'pet_name': petName,
      'caption': caption,
      'image_base64': imageBase64,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Public feed — every user's posts, newest first.
  Stream<QuerySnapshot> petPostsStream() {
    return _db.collection('pet_posts').orderBy('created_at', descending: true).snapshots();
  }

  Future<void> deletePetPost(String postId) async {
    await _db.collection('pet_posts').doc(postId).delete();
  }
}