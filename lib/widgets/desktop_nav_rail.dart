import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class DesktopNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopRailItem> items;

  const DesktopNavRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: NavigationRailLabelType.all,
      backgroundColor: Colors.white,
      groupAlignment: 0.0,
      elevation: 5,
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.normal,
        fontSize: 12,
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 28,
      ),
      unselectedIconTheme: IconThemeData(
        color: Colors.grey.shade500,
        size: 24,
      ),
      destinations: items.map((item) {
        return NavigationRailDestination(
          icon: Icon(item.icon),
          selectedIcon: Icon(item.activeIcon),
          label: Text(item.label),
          padding: const EdgeInsets.symmetric(vertical: 12),
        );
      }).toList(),
      leading: Padding(
        padding: const EdgeInsets.only(bottom: 20, top: 20),
        child: Image.asset(
          'assets/images/questor 9.png', // Using app icon as logo
          width: 48,
          height: 48,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.school_rounded,
            size: 40,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class DesktopRailItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const DesktopRailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
