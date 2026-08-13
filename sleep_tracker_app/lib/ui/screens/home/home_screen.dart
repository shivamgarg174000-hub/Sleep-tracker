import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontFeature;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/health_providers.dart';
import '../../../core/services/providers.dart';
import '../../../models/health_models.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/sleep_stage_timeline.dart';
import '../../widgets/glow_progress_ring.dart';

/// The main dashboard. Press-to-start/wake writes a real Firestore
/// sleepSessions doc. Sleep stages / calories / steps now come straight
/// from Health Connect (Android) or HealthKit (iOS) via [HealthService] —
/// when no wearable is connected, the real empty state renders instead of
/// zeros.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _sessionStart;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _saving = false;

  bool get _isTracking => _sessionStart != null;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startSession() {
    setState(() {
      _sessionStart = DateTime.now();
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(_sessionStart!));
    });
  }

  Future<void> _endSession() async {
    final start = _sessionStart;
    if (start == null) return;
    final end = DateTime.now();
    _ticker?.cancel();

    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sleepSessions')
            .add({
          'timeInBedStart': Timestamp.fromDate(start),
          'timeInBedEnd': Timestamp.fromDate(end),
          'timeInBedMinutes': end.difference(start).inMinutes,
          'source': 'manual_button',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      }
      // Wearable-reported sleep for the night will show up in the next
      // health snapshot refresh — pull it in now rather than waiting.
      ref.invalidate(todayHealthSnapshotProvider);
    } finally {
      if (mounted) {
        setState(() {
          _sessionStart = null;
          _saving = false;
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final permissionAsync = ref.watch(healthPermissionProvider);
    final snapshotAsync = ref.watch(todayHealthSnapshotProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final stepGoal = profileAsync.value?.stepGoal ?? 8000;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.accentPrimary,
        backgroundColor: AppColors.surfaceElevated,
        onRefresh: () async {
          ref.invalidate(healthPermissionProvider);
          ref.invalidate(todayHealthSnapshotProvider);
          await ref.read(todayHealthSnapshotProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              sliver: SliverToBoxAdapter(child: _Header()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: _SleepButton(
                    isTracking: _isTracking,
                    saving: _saving,
                    elapsedLabel: _formatDuration(_elapsed),
                    onPressed: _isTracking ? _endSession : _startSession,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  permissionAsync.when(
                    data: (hasPermission) => !hasPermission
                        ? _ConnectWearableCard(
                            onConnect: () async {
                              final granted = await ref
                                  .read(healthServiceProvider)
                                  .requestPermissions();
                              if (granted) {
                                ref.invalidate(healthPermissionProvider);
                                ref.invalidate(todayHealthSnapshotProvider);
                              }
                            },
                          )
                        : snapshotAsync.when(
                            data: (snapshot) => Column(
                              children: [
                                _SleepStagesCard(snapshot: snapshot),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RingMetricCard(
                                        icon: Icons.local_fire_department_outlined,
                                        title: 'Calories',
                                        value: snapshot.activeCaloriesKcal == null
                                            ? '—'
                                            : '${snapshot.activeCaloriesKcal!.round()}',
                                        unit: 'kcal',
                                        percent: snapshot.activeCaloriesKcal == null
                                            ? 0
                                            : (snapshot.activeCaloriesKcal! / 500).clamp(0, 1),
                                        color: AppColors.accentWarm,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _RingMetricCard(
                                        icon: Icons.directions_walk,
                                        title: 'Steps',
                                        value: snapshot.steps?.toString() ?? '—',
                                        unit: 'of $stepGoal',
                                        percent: snapshot.steps == null
                                            ? 0
                                            : (snapshot.steps! / stepGoal).clamp(0, 1),
                                        color: AppColors.accentSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            loading: () => const _LoadingCard(),
                            error: (e, _) => const _ErrorCard(message: 'Could not load health data.'),
                          ),
                    loading: () => const _LoadingCard(),
                    error: (e, _) => const _ErrorCard(message: 'Could not check health permissions.'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 5
        ? 'Still up?'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 2),
            const Text('Your Sleep',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        GlassPanel(
          borderRadius: AppRadii.pill,
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton({
    required this.isTracking,
    required this.saving,
    required this.elapsedLabel,
    required this.onPressed,
  });

  final bool isTracking;
  final bool saving;
  final String elapsedLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gradient = isTracking ? AppColors.wakeButtonGradient : AppColors.sleepButtonGradient;
    final glowColor = isTracking ? AppColors.accentWarm : AppColors.accentPrimary;

    return GestureDetector(
      onTap: saving ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          boxShadow: AppTheme.glow(glowColor, blur: 60, opacity: 0.55),
        ),
        child: Center(
          child: saving
              ? const CircularProgressIndicator(color: Colors.white)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTracking ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isTracking ? 'Press to\nWake Up' : 'Press to\nStart',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (isTracking) ...[
                      const SizedBox(height: 8),
                      Text(
                        elapsedLabel,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _ConnectWearableCard extends StatelessWidget {
  const _ConnectWearableCard({required this.onConnect});
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.watch_outlined, color: AppColors.accentSecondary, size: 24),
          const SizedBox(height: 12),
          const Text('Connect your wearable',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Sync Health Connect or HealthKit to see real sleep stages, calories, and steps from your Fitbit, Apple Watch, or phone sensors.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onConnect, child: const Text('Connect now')),
          ),
        ],
      ),
    );
  }
}

class _SleepStagesCard extends StatelessWidget {
  const _SleepStagesCard({required this.snapshot});
  final DailyHealthSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nights_stay_outlined, color: AppColors.accentSecondary, size: 20),
              const SizedBox(width: 8),
              const Text('Sleep Stages',
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          if (snapshot.hasSleepData)
            SleepStageTimeline(stages: snapshot.sleepStages)
          else
            const Text(
              'No sleep data reported yet today. It will appear here once your wearable syncs.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

class _RingMetricCard extends StatelessWidget {
  const _RingMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
    required this.percent,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final double percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(unit, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
              GlowProgressRing(
                percent: percent,
                centerLabel: '${(percent * 100).round()}%',
                color: color,
                radius: 26,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator(color: AppColors.accentPrimary)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
    );
  }
}
