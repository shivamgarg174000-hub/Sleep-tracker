import 'package:health/health.dart';
import 'package:logger/logger.dart';

import '../../models/health_models.dart';

/// Wraps the `health` plugin, which talks to Health Connect on Android and
/// HealthKit on iOS through one unified API. No mock data path exists —
/// every method either returns what the OS reports or an empty/null result.
class HealthService {
  HealthService() : _logger = Logger();

  final Logger _logger;
  final Health _health = Health();

  static const _sleepTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_IN_BED,
  ];

  static const _activityTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  List<HealthDataType> get _allTypes => [..._sleepTypes, ..._activityTypes];

  Future<void> configure() async {
    await _health.configure();
  }

  /// Triggers the native Health Connect / HealthKit permission sheet.
  /// Returns true only if the user actually granted read access.
  Future<bool> requestPermissions() async {
    try {
      final types = _allTypes;
      final permissions = types.map((_) => HealthDataAccess.READ).toList();

      final hasPermissions =
          await _health.hasPermissions(types, permissions: permissions) ?? false;
      if (hasPermissions) return true;

      return await _health.requestAuthorization(types, permissions: permissions);
    } catch (e) {
      _logger.e('Health permission request failed', error: e);
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    final types = _allTypes;
    final permissions = types.map((_) => HealthDataAccess.READ).toList();
    return await _health.hasPermissions(types, permissions: permissions) ?? false;
  }

  /// Pulls sleep + activity data for the given range and normalizes it into
  /// [DailyHealthSnapshot]. If the user has no connected wearable, every
  /// field comes back null/empty — the caller renders that as an honest
  /// "connect a wearable" state, never a fabricated number.
  Future<DailyHealthSnapshot> fetchSnapshot({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: _allTypes,
        startTime: start,
        endTime: end,
      );
      final deduped = _health.removeDuplicates(points);

      final stages = <SleepStageSegment>[];
      int? steps;
      double? activeCalories;
      double? totalCalories;

      for (final point in deduped) {
        final stageType = _mapSleepType(point.type);
        if (stageType != null) {
          stages.add(SleepStageSegment(
            start: point.dateFrom,
            end: point.dateTo,
            stage: stageType,
          ));
          continue;
        }

        final value = point.value;
        if (value is! NumericHealthValue) continue;
        final numeric = value.numericValue.toDouble();

        switch (point.type) {
          case HealthDataType.STEPS:
            steps = (steps ?? 0) + numeric.round();
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            activeCalories = (activeCalories ?? 0) + numeric;
            break;
          case HealthDataType.TOTAL_CALORIES_BURNED:
            totalCalories = (totalCalories ?? 0) + numeric;
            break;
          default:
            break;
        }
      }

      stages.sort((a, b) => a.start.compareTo(b.start));

      return DailyHealthSnapshot(
        sleepStages: stages,
        steps: steps,
        activeCaloriesKcal: activeCalories,
        totalCaloriesKcal: totalCalories,
        fetchedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.e('Failed to fetch health snapshot', error: e);
      return DailyHealthSnapshot.empty();
    }
  }

  SleepStageType? _mapSleepType(HealthDataType type) {
    switch (type) {
      case HealthDataType.SLEEP_AWAKE:
        return SleepStageType.awake;
      case HealthDataType.SLEEP_REM:
        return SleepStageType.rem;
      case HealthDataType.SLEEP_LIGHT:
        return SleepStageType.light;
      case HealthDataType.SLEEP_DEEP:
        return SleepStageType.deep;
      case HealthDataType.SLEEP_IN_BED:
        return SleepStageType.inBed;
      case HealthDataType.SLEEP_ASLEEP:
        return SleepStageType.light; // generic "asleep" bucket if stage detail is unavailable
      default:
        return null;
    }
  }
}
