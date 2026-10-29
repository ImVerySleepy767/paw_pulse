import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// log_date should always be a String ('yyyy-MM-dd') per the schema used
/// everywhere the app writes it — but a manually-entered Firestore record
/// can accidentally have it stored as a Timestamp instead. This safely
/// handles both so the app never crashes or shows raw Timestamp objects.
String formatLogDate(dynamic logDate) {
  if (logDate is String) return logDate;
  if (logDate is Timestamp) return DateFormat('yyyy-MM-dd').format(logDate.toDate());
  return 'Unknown date';
}
