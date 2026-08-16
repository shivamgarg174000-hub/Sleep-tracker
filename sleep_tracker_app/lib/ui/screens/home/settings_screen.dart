import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/providers.dart';
import '../../../core/services/notification_providers.dart';
import '../../../models/user_profile.dart';
import '../../widgets/glass_panel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete account?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This permanently deletes your profile, sleep history, and AI chat data. This cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.danger)),
    );

    try {
      await ref.read(authServiceProvider).deleteAccount();
      // AuthStateProvider will fire null and the router redirects to /login
      // automatically once the account is gone — no manual nav needed.
      if (context.mounted) Navigator.of(context).pop(); // dismiss spinner
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 140),
        children: [
          const Text('Settings',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          profileAsync.when(
            data: (profile) => GlassPanel(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.accentPrimary,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.displayName ?? 'User',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      Text(
                        profile?.isGuest == true ? 'Guest account' : 'Google account',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Preferences'),
          const _SettingsTile(icon: Icons.dark_mode_outlined, title: 'Theme', trailing: 'Dark'),
          const _SettingsTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Health permissions',
              trailing: 'Not connected'),
          const SizedBox(height: 24),
          _SectionLabel('Notifications'),
          profileAsync.when(
            data: (profile) => profile == null
                ? const SizedBox.shrink()
                : _NotificationSettings(profile: profile),
            loading: () => const SizedBox(
                height: 60, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _SectionLabel('Account'),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            onTap: () => ref.read(authServiceProvider).signOut(),
          ),
          _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete account',
            danger: true,
            onTap: () => _confirmAndDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Two independent, functional notification controls:
/// - Bedtime reminder: on-device scheduled local notification, no network.
/// - Push notifications: real FCM opt-in, persists the device token to
///   Firestore so a backend can target this device later.
class _NotificationSettings extends ConsumerStatefulWidget {
  const _NotificationSettings({required this.profile});
  final UserProfile profile;

  @override
  ConsumerState<_NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends ConsumerState<_NotificationSettings> {
  bool _busyBedtime = false;
  bool _busyPush = false;

  Future<void> _toggleBedtime(bool enabled) async {
    setState(() => _busyBedtime = true);
    await setBedtimeReminder(
      
      enabled: enabled,
      hour: widget.profile.bedtimeReminderHour,
      minute: widget.profile.bedtimeReminderMinute,
      sleepGoalMinutes: widget.profile.sleepGoalMinutes,
    );
    if (mounted) setState(() => _busyBedtime = false);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: widget.profile.bedtimeReminderHour,
        minute: widget.profile.bedtimeReminderMinute,
      ),
    );
    if (picked == null) return;

    setState(() => _busyBedtime = true);
    await setBedtimeReminder(
      
      enabled: true,
      hour: picked.hour,
      minute: picked.minute,
      sleepGoalMinutes: widget.profile.sleepGoalMinutes,
    );
    if (mounted) setState(() => _busyBedtime = false);
  }

  Future<void> _togglePush(bool enabled) async {
    setState(() => _busyPush = true);
    if (enabled) {
      final granted = await enablePushNotifications(ref as dynamic);
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification permission was denied.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } else {
      await disablePushNotifications(ref as dynamic);
    }
    if (mounted) setState(() => _busyPush = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final timeLabel = TimeOfDay(
      hour: profile.bedtimeReminderHour,
      minute: profile.bedtimeReminderMinute,
    ).format(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.accentPrimary,
                  value: profile.bedtimeReminderEnabled,
                  onChanged: _busyBedtime ? null : _toggleBedtime,
                  title: const Text('Bedtime reminder',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Daily local notification — no internet required',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  secondary: const Icon(Icons.bedtime_outlined, color: AppColors.textPrimary, size: 20),
                ),
                if (profile.bedtimeReminderEnabled)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _busyBedtime ? null : () => _pickTime(context),
                        icon: const Icon(Icons.schedule, size: 16, color: AppColors.accentSecondary),
                        label: Text('Reminds you at $timeLabel — tap to change',
                            style: const TextStyle(color: AppColors.accentSecondary, fontSize: 12.5)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.accentPrimary,
            value: profile.pushNotificationsEnabled,
            onChanged: _busyPush ? null : _togglePush,
            title: const Text('Push notifications',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: const Text('Kitty AI insights and sleep-trend alerts',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            secondary: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary, size: 20),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color, size: 20),
          title: Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: trailing != null
              ? Text(trailing!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))
              : Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withValues(alpha: 0.6)),
          onTap: onTap,
        ),
      ),
    );
  }
}
