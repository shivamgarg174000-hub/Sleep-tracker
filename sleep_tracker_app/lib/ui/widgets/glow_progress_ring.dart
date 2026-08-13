import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../core/theme/app_theme.dart';

class GlowProgressRing extends StatelessWidget {
  const GlowProgressRing({
    super.key,
    required this.percent,
    required this.centerLabel,
    required this.color,
    this.radius = 34,
  });

  final double percent; // 0.0 - 1.0
  final String centerLabel;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppTheme.glow(color, blur: 22, opacity: 0.35),
      ),
      child: CircularPercentIndicator(
        radius: radius,
        lineWidth: 7,
        percent: percent.clamp(0.0, 1.0),
        backgroundColor: AppColors.glassFill,
        progressColor: color,
        circularStrokeCap: CircularStrokeCap.round,
        animation: true,
        animationDuration: 900,
        center: Text(
          centerLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
