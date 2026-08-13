import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central design tokens for the app. Every screen pulls colors, gradients,
/// and glow specs from here so the "premium dark + glowing accent" language
/// stays consistent across the whole product.
class AppColors {
  AppColors._();

  // Base surfaces
  static const Color background = Color(0xFF07070C);
  static const Color surface = Color(0xFF121218);
  static const Color surfaceElevated = Color(0xFF1B1B24);

  // Glass panel fill/border (used with BackdropFilter blur)
  static const Color glassFill = Color(0x1AFFFFFF); // 10% white
  static const Color glassBorder = Color(0x33FFFFFF); // 20% white

  // Accent system — indigo/violet primary, cyan secondary (sleep = night sky)
  static const Color accentPrimary = Color(0xFF7C6CFF);
  static const Color accentSecondary = Color(0xFF4CD6FF);
  static const Color accentWarm = Color(0xFFFFA26B); // wake / energy states

  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFFA0A0B2);
  static const Color textMuted = Color(0xFF5C5C6E);

  static const Color success = Color(0xFF4CE0A0);
  static const Color danger = Color(0xFFFF6B7A);

  static const LinearGradient primaryGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentPrimary, accentSecondary],
  );

  static const LinearGradient sleepButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF8A78FF), Color(0xFF4C3FCB)],
  );

  static const LinearGradient wakeButtonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFC26B), Color(0xFFCB7A3F)],
  );
}

class AppRadii {
  AppRadii._();
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 28;
  static const double pill = 999;
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentPrimary,
        secondary: AppColors.accentSecondary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
        ),
      ),
    );
  }

  /// Soft glow used behind the primary CTA and key data rings.
  static List<BoxShadow> glow(Color color, {double blur = 40, double opacity = 0.45}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blur,
        spreadRadius: 2,
      ),
    ];
  }
}
