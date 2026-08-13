import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/health_models.dart';

/// Horizontal timeline visualizing Awake/REM/Light/Deep stages as
/// proportionally-sized, color-coded segments with a soft gradient sheen —
/// deliberately lighter-weight than a full fl_chart bar chart since this is
/// a single stacked timeline, not a multi-axis plot.
class SleepStageTimeline extends StatelessWidget {
  const SleepStageTimeline({super.key, required this.stages});

  final List<SleepStageSegment> stages;

  static const _stageColors = {
    SleepStageType.awake: Color(0xFFFF8A65),
    SleepStageType.rem: Color(0xFF4CD6FF),
    SleepStageType.light: Color(0xFF7C6CFF),
    SleepStageType.deep: Color(0xFF3B2FA0),
    SleepStageType.inBed: Color(0xFF2A2A38),
    SleepStageType.unknown: Color(0xFF2A2A38),
  };

  @override
  Widget build(BuildContext context) {
    if (stages.isEmpty) return const SizedBox.shrink();

    final totalMs = stages.fold<int>(
        0, (sum, s) => sum + s.duration.inMilliseconds);
    if (totalMs == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: SizedBox(
            height: 14,
            child: Row(
              children: stages.map((s) {
                final flex = (s.duration.inMilliseconds / totalMs * 1000).round().clamp(1, 1000);
                return Expanded(
                  flex: flex,
                  child: Container(color: _stageColors[s.stage]),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            SleepStageType.awake,
            SleepStageType.rem,
            SleepStageType.light,
            SleepStageType.deep,
          ].map((type) {
            final duration = stages
                .where((s) => s.stage == type)
                .fold(Duration.zero, (sum, s) => sum + s.duration);
            return _LegendChip(
              color: _stageColors[type]!,
              label: type.label,
              minutes: duration.inMinutes,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label, required this.minutes});
  final Color color;
  final String label;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · ${minutes}m',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        ),
      ],
    );
  }
}
