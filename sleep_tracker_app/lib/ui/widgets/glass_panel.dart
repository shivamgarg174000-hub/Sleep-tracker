import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Frosted-glass container: blurred backdrop + translucent fill + hairline
/// border. This is the building block behind the bottom nav, cards, and
/// modal sheets so the "glassmorphism" language stays uniform.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.lg,
    this.blur = 20,
    this.padding,
    this.fillColor,
    this.borderColor,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? fillColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: fillColor ?? AppColors.glassFill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? AppColors.glassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
