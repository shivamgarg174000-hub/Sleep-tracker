import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'glass_panel.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem({required this.icon, required this.activeIcon, required this.label});
}

/// Bottom navigation bar: Home / Sounds / Kitty AI / Settings.
/// Floats above the content with rounded glass edges, matching the
/// "translucent blurred nav like iOS Instagram" spec.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: GlassPanel(
        borderRadius: AppRadii.pill,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(items.length, (i) {
            final selected = i == currentIndex;
            final item = items[i];
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    gradient: selected ? AppColors.primaryGlow : null,
                    boxShadow: selected
                        ? AppTheme.glow(AppColors.accentPrimary, blur: 18, opacity: 0.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        color: selected ? Colors.white : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
