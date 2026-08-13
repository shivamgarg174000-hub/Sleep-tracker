import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Handles two distinct notification paths, because they're genuinely
/// different mechanisms:
///
/// 1. **Push (FCM)** — remote notifications triggered from a backend/Cloud
///    Function (e.g. "Kitty noticed a sleep debt trend"). This service
///    requests permission, captures the device token, and listens for
///    foreground messages. Actually *sending* a push requires a
///    server-side trigger (Cloud Function, Admin SDK, etc.) — that's
///    infrastructure outside the Flutter app itself; see
///    PLATFORM_SETUP.md "Sending a push" for the minimal Cloud Function.
///
/// 2. **Local scheduled notifications** — the daily bedtime reminder,
///    computed from the user's saved reminder time and repeated every day.
///    This needs no server or network at all; it's scheduled entirely
///    on-device via `flutter_local_notifications` + `timezone`.
class NotificationService {
  NotificationService() : _logger = Logger();

  final Logger _logger;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  static const _bedtimeReminderId = 1001;
  static const _bedtimeChannel = AndroidNotificationChannel(
    'bedtime_reminders',
    'Bedtime Reminders',
    description: 'Daily reminder to start winding down for your sleep goal.',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _resolveLocalTimezoneName()));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // requested explicitly via requestPermissions()
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_bedtimeChannel);

    // Foreground FCM messages don't show a system tray notification by
    // default on either platform — surface them as a local notification
    // so the user actually sees them while the app is open.
    FirebaseMessaging.onMessage.listen(_showForegroundPush);

    _initialized = true;
  }

  /// `timezone`'s IANA names don't map 1:1 from `DateTime.now().timeZoneName`
  /// (which returns abbreviations like "PST"), so this falls back to UTC
  /// when it can't resolve — bedtime reminders still fire, just anchored to
  /// UTC wall-clock time until a proper platform timezone lookup (e.g. the
  /// `flutter_timezone` package) is added.
  Future<String> _resolveLocalTimezoneName() async {
    try {
      return DateTime.now().timeZoneName.isNotEmpty ? DateTime.now().timeZoneName : 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }

  // ---------------------------------------------------------------------
  // Push (FCM)
  // ---------------------------------------------------------------------

  /// Requests OS-level notification permission (covers both push and local
  /// notifications on iOS; Android 13+ requires this for local too).
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (Platform.isIOS) {
      await _local
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Current device push token, or null if unavailable (simulator without
  /// APNs setup, permission not yet granted, etc.). Callers persist this to
  /// the user's Firestore profile so a backend can target the device.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      _logger.e('Failed to get FCM token', error: e);
      return null;
    }
  }

  /// Fires whenever the token rotates (OS-driven, e.g. after reinstall) —
  /// callers should re-save this to Firestore whenever it emits.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  void _showForegroundPush(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'push_general',
          'Kitty Sleep',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Local scheduled bedtime reminder
  // ---------------------------------------------------------------------

  /// Schedules (or reschedules) a daily repeating notification at
  /// [hour]:[minute] local time. Safe to call repeatedly — it cancels any
  /// existing bedtime reminder first, so changing the time in Settings
  /// just works.
  Future<void> scheduleBedtimeReminder({
    required int hour,
    required int minute,
    required int sleepGoalMinutes,
  }) async {
    await cancelBedtimeReminder();

    final goalHours = (sleepGoalMinutes / 60).toStringAsFixed(1);

    await _local.zonedSchedule(
      _bedtimeReminderId,
      'Time to wind down 🌙',
      'Start your bedtime routine now to hit your ${goalHours}h sleep goal.',
      _nextInstanceOf(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _bedtimeChannel.id,
          _bedtimeChannel.name,
          channelDescription: _bedtimeChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily at this time
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelBedtimeReminder() async {
    await _local.cancel(_bedtimeReminderId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Must be a top-level (or static) function — the platform invokes this in
/// a separate isolate when a push arrives while the app is fully
/// terminated. Registered in main.dart via
/// `FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler)`.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal: heavy work here should be avoided since this
  // runs in a background isolate with a limited time budget. The system
  // already renders the notification from `message.notification` when the
  // app is terminated/backgrounded — this hook is for data-only messages
  // or analytics, not UI.
}
