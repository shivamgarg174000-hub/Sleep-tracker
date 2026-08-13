import 'package:cloud_firestore/cloud_firestore.dart';

/// The permanent context window handed to Kitty AI on every request.
/// Written once during onboarding, updated whenever the user edits
/// settings, and re-read (not re-collected) on every AI call.
class UserProfile {
  final String uid;
  final String displayName;
  final bool isGuest;
  final DateTime? birthdate;
  final double? weightKg;
  final double? heightCm;
  final int sleepGoalMinutes; // e.g. 480 = 8 hours
  final int stepGoal;
  final bool onboardingComplete;

  // Bedtime reminder (local notification), independent of general push opt-in.
  final bool bedtimeReminderEnabled;
  final int bedtimeReminderHour; // 24h, local time
  final int bedtimeReminderMinute;

  // General push notifications (FCM) opt-in + last known device token.
  final bool pushNotificationsEnabled;
  final String? fcmToken;

  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.isGuest,
    required this.birthdate,
    required this.weightKg,
    required this.heightCm,
    required this.sleepGoalMinutes,
    required this.stepGoal,
    required this.onboardingComplete,
    required this.bedtimeReminderEnabled,
    required this.bedtimeReminderHour,
    required this.bedtimeReminderMinute,
    required this.pushNotificationsEnabled,
    required this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.newForUid(String uid, {required bool isGuest, String? displayName}) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid,
      displayName: displayName ?? (isGuest ? 'Guest' : 'New User'),
      isGuest: isGuest,
      birthdate: null,
      weightKg: null,
      heightCm: null,
      sleepGoalMinutes: 480,
      stepGoal: 8000,
      onboardingComplete: false,
      bedtimeReminderEnabled: false,
      bedtimeReminderHour: 22,
      bedtimeReminderMinute: 30,
      pushNotificationsEnabled: false,
      fcmToken: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'User',
      isGuest: map['isGuest'] as bool? ?? false,
      birthdate: (map['birthdate'] as Timestamp?)?.toDate(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      sleepGoalMinutes: map['sleepGoalMinutes'] as int? ?? 480,
      stepGoal: map['stepGoal'] as int? ?? 8000,
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
      bedtimeReminderEnabled: map['bedtimeReminderEnabled'] as bool? ?? false,
      bedtimeReminderHour: map['bedtimeReminderHour'] as int? ?? 22,
      bedtimeReminderMinute: map['bedtimeReminderMinute'] as int? ?? 30,
      pushNotificationsEnabled: map['pushNotificationsEnabled'] as bool? ?? false,
      fcmToken: map['fcmToken'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'isGuest': isGuest,
      'birthdate': birthdate == null ? null : Timestamp.fromDate(birthdate!),
      'weightKg': weightKg,
      'heightCm': heightCm,
      'sleepGoalMinutes': sleepGoalMinutes,
      'stepGoal': stepGoal,
      'onboardingComplete': onboardingComplete,
      'bedtimeReminderEnabled': bedtimeReminderEnabled,
      'bedtimeReminderHour': bedtimeReminderHour,
      'bedtimeReminderMinute': bedtimeReminderMinute,
      'pushNotificationsEnabled': pushNotificationsEnabled,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  UserProfile copyWith({
    String? displayName,
    DateTime? birthdate,
    double? weightKg,
    double? heightCm,
    int? sleepGoalMinutes,
    int? stepGoal,
    bool? onboardingComplete,
    bool? bedtimeReminderEnabled,
    int? bedtimeReminderHour,
    int? bedtimeReminderMinute,
    bool? pushNotificationsEnabled,
    String? fcmToken,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      isGuest: isGuest,
      birthdate: birthdate ?? this.birthdate,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
      stepGoal: stepGoal ?? this.stepGoal,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      bedtimeReminderEnabled: bedtimeReminderEnabled ?? this.bedtimeReminderEnabled,
      bedtimeReminderHour: bedtimeReminderHour ?? this.bedtimeReminderHour,
      bedtimeReminderMinute: bedtimeReminderMinute ?? this.bedtimeReminderMinute,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Compact string handed straight into the Gemini system prompt so
  /// Kitty AI always has grounded, current context — never guesses.
  String toAiContextString() {
    final age = birthdate == null
        ? 'unknown'
        : ((DateTime.now().difference(birthdate!).inDays) / 365.25).floor().toString();
    return '''
User profile:
- Name: $displayName
- Age: $age
- Weight: ${weightKg?.toStringAsFixed(1) ?? 'unknown'} kg
- Height: ${heightCm?.toStringAsFixed(1) ?? 'unknown'} cm
- Sleep goal: ${(sleepGoalMinutes / 60).toStringAsFixed(1)} hours/night
- Daily step goal: $stepGoal
''';
  }
}
