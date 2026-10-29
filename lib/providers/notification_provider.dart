import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawpulse/services/notification_service.dart';

const String _notifPrefKey = 'daily_reminder_enabled';

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());

class NotificationPreferenceNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifPrefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifPrefKey, enabled);

    final service = ref.read(notificationServiceProvider);
    if (enabled) {
      await service.scheduleDailyReminder(); // defaults to 7 PM
    } else {
      await service.cancelDailyReminder();
    }
    state = AsyncValue.data(enabled);
  }
}

final notificationPreferenceProvider =
    AsyncNotifierProvider<NotificationPreferenceNotifier, bool>(NotificationPreferenceNotifier.new);