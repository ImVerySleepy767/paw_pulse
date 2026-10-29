import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Duolingo-style daily reminder: "you haven't logged today, don't break
/// your streak." flutter_local_notifications has NO web support at all —
/// every method here is a safe no-op when running on Chrome, so calling
/// code doesn't need its own kIsWeb checks everywhere.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    tz_data.initializeTimeZones();

    // FIX: without this, tz.local silently defaults to UTC, so every
    // "schedule 2 minutes from now" calculation was actually computed in
    // UTC instead of the device's real timezone — the notification was
    // being scheduled for the correct wall-clock time in the WRONG zone,
    // which could land hours away from when the emulator's clock actually
    // showed that time. This is why testing kept "silently failing."
    final String deviceTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimeZone));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Android 13+ requires explicit runtime permission for notifications.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Fires a notification 5 seconds from now — lets you confirm delivery
  /// actually works without waiting for the real scheduled time.
  Future<void> triggerTestNotification() async {
    if (kIsWeb) return;
    await init();

    const androidDetails = AndroidNotificationDetails(
      'daily_log_reminder',
      'Daily Log Reminder',
      channelDescription: "Reminds you to log your pet's health data today",
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);

    final testTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(seconds: 5));

    await _plugin.zonedSchedule(
      999, // separate ID so it never collides with the real daily reminder (ID 0)
      'Test Notification 🐾',
      'If you see this, notifications are working correctly!',
      testTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedules a daily repeating reminder at the given hour/minute
  /// (24-hour format), local time. Re-fires every day automatically —
  /// no need to reschedule manually.
  Future<void> scheduleDailyReminder({int hour = 19, int minute = 0}) async {
    if (kIsWeb) return;
    await init();

    const androidDetails = AndroidNotificationDetails(
      'daily_log_reminder',
      'Daily Log Reminder',
      channelDescription: "Reminds you to log your pet's health data today",
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      0, // fixed ID — reschedule just replaces this one notification
      "Don't break your streak! 🐾",
      "You haven't logged your pet's health today — tap to add today's entry.",
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }

  Future<void> cancelDailyReminder() async {
    if (kIsWeb) return;
    await _plugin.cancel(0);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
