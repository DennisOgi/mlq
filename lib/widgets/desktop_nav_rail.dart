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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: NavigationRail(
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        backgroundColor: Colors.transparent,
        groupAlignment: 0.0,
        selectedLabelTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Colors.white60,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        selectedIconTheme: const IconThemeData(
          color: Colors.white,
          size: 28,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Colors.white60,
          size: 24,
        ),
        indicatorColor: Colors.white.withValues(alpha: 0.2),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        useIndicator: true,
        destinations: items.map((item) {
          return NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: Text(item.label),
            padding: const EdgeInsets.symmetric(vertical: 8),
          );
        }).toList(),
        leading: Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 20),
          child: Image.asset(
            'assets/images/questor 9.png',
            width: 48,
            height: 48,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.school_rounded,
              size: 40,
              color: Colors.white,
            ),
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
