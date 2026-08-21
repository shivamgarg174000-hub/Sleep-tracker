import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';
import 'providers.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  service.init();
  return service;
});

final notificationPermissionProvider = FutureProvider<bool>((ref) async {
  return ref.watch(notificationServiceProvider).hasPermission();
});

/// Turns push notifications on: requests OS permission, grabs the FCM
/// token, saves both the opt-in flag and token to the user's profile, and
/// starts listening for token rotation. Returns false if the user denied
/// the permission prompt.
Future<bool> enablePushNotifications(Ref ref) async {
  final notif = ref.read(notificationServiceProvider);
  final granted = await notif.requestPermission();
  if (!granted) return false;

  final uid = FirebaseAuth.instance.currentUser?.uid;
  final token = await notif.getToken();
  if (uid != null) {
    await ref.read(firestoreServiceProvider).updateProfileFields(uid, {
      'pushNotificationsEnabled': true,
      if (token != null) 'fcmToken': token,
    });

    notif.onTokenRefresh.listen((newToken) {
      ref.read(firestoreServiceProvider).updateProfileFields(uid, {'fcmToken': newToken});
    });
  }

  ref.invalidate(notificationPermissionProvider);
  return true;
}

Future<void> disablePushNotifications(Ref ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  await ref.read(firestoreServiceProvider).updateProfileFields(uid, {
    'pushNotificationsEnabled': false,
  });
}

/// Turns the daily bedtime local reminder on/off and (re)schedules it
/// whenever the saved time changes. Called from Settings.
 Future<void> setBedtimeReminder(
  WidgetRef ref, // or Ref ref
  {
    required bool enabled,
    required int hour,
    required int minute,
    required int sleepGoalMinutes,
  }
)
async {
  final notif = ref.read(notificationServiceProvider);
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (enabled) {
    final granted = await notif.requestPermission();
    if (!granted) return;
    await notif.scheduleBedtimeReminder(
      hour: hour,
      minute: minute,
      sleepGoalMinutes: sleepGoalMinutes,
    );
  } else {
    await notif.cancelBedtimeReminder();
  }

  if (uid != null) {
    await ref.read(firestoreServiceProvider).updateProfileFields(uid, {
      'bedtimeReminderEnabled': enabled,
      'bedtimeReminderHour': hour,
      'bedtimeReminderMinute': minute,
    });
  }
}
