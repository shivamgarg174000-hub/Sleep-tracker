import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/glass_nav_bar.dart';
import '../home/home_screen.dart';
import '../home/soundscapes_screen.dart';
import '../home/kitty_ai_screen.dart';
import '../home/settings_screen.dart';

/// Hosts the four primary tabs behind the floating glass nav bar.
/// Sound and AI/health-data screens are stubbed with clear TODO markers —
/// they're built out in Phase 2 (health APIs + background audio), per the
/// brief's instruction to pause after auth + core UI.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    NavItem(icon: Icons.bedtime_outlined, activeIcon: Icons.bedtime, label: 'Sleep'),
    NavItem(icon: Icons.graphic_eq_outlined, activeIcon: Icons.graphic_eq, label: 'Sounds'),
    NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'Kitty AI'),
    NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  final _screens = const [
    HomeScreen(),
    SoundscapesScreen(),
    KittyAiScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: GlassNavBar(
        items: _items,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
