import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/health_models.dart';
import 'health_service.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

/// Whether the app currently has read permission for sleep/steps/calories.
/// Screens watch this to decide between the "Connect wearable" CTA and the
/// real data view.
final healthPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(healthServiceProvider);
  await service.configure();
  return service.hasPermissions();
});

/// Today's snapshot (midnight -> now). `refresh()` is exposed via
/// `ref.invalidate(todayHealthSnapshotProvider)` after the user grants
/// permission or pulls to refresh.
final todayHealthSnapshotProvider = FutureProvider<DailyHealthSnapshot>((ref) async {
  final hasPermission = await ref.watch(healthPermissionProvider.future);
  if (!hasPermission) return DailyHealthSnapshot.empty();

  final service = ref.watch(healthServiceProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return service.fetchSnapshot(start: startOfDay, end: now);
});
