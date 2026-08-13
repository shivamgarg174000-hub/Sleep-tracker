/// One contiguous stage segment pulled from Health Connect / HealthKit.
class SleepStageSegment {
  final DateTime start;
  final DateTime end;
  final SleepStageType stage;

  const SleepStageSegment({required this.start, required this.end, required this.stage});

  Duration get duration => end.difference(start);
}

enum SleepStageType { awake, rem, light, deep, inBed, unknown }

extension SleepStageTypeX on SleepStageType {
  String get label {
    switch (this) {
      case SleepStageType.awake:
        return 'Awake';
      case SleepStageType.rem:
        return 'REM';
      case SleepStageType.light:
        return 'Light';
      case SleepStageType.deep:
        return 'Deep';
      case SleepStageType.inBed:
        return 'In Bed';
      case SleepStageType.unknown:
        return 'Unknown';
    }
  }
}

/// Aggregated view for a single day, built from whatever the connected
/// wearable actually reported. Any field can be null/empty — the UI must
/// render an honest empty state rather than a zero when data is missing.
class DailyHealthSnapshot {
  final List<SleepStageSegment> sleepStages;
  final int? steps;
  final double? activeCaloriesKcal;
  final double? totalCaloriesKcal;
  final DateTime fetchedAt;

  const DailyHealthSnapshot({
    required this.sleepStages,
    required this.steps,
    required this.activeCaloriesKcal,
    required this.totalCaloriesKcal,
    required this.fetchedAt,
  });

  bool get hasSleepData => sleepStages.isNotEmpty;

  Duration get totalSleepDuration => sleepStages
      .where((s) => s.stage != SleepStageType.awake && s.stage != SleepStageType.inBed)
      .fold(Duration.zero, (sum, s) => sum + s.duration);

  Duration durationOf(SleepStageType type) => sleepStages
      .where((s) => s.stage == type)
      .fold(Duration.zero, (sum, s) => sum + s.duration);

  factory DailyHealthSnapshot.empty() => DailyHealthSnapshot(
        sleepStages: const [],
        steps: null,
        activeCaloriesKcal: null,
        totalCaloriesKcal: null,
        fetchedAt: DateTime.now(),
      );
}
