import 'package:flutter/material.dart';
import '../theme.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadZapCount;

  const BottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.unreadZapCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events_rounded,
                label: 'Classifica',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.music_note_outlined,
                activeIcon: Icons.music_note_rounded,
                label: 'Vibe',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.bolt_outlined,
                activeIcon: Icons.bolt_rounded,
                label: 'ZAP',
                index: 3,
                badgeCount: unreadZapCount,
              ),
              _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profilo',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    int badgeCount = 0,
  }) {
    final isActive = currentIndex == index;
    final showBadge = badgeCount > 0 && index == 2;
    
    return GestureDetector(
      onTap: () => onTap(index),
              child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? AppTheme.limeAccent : AppTheme.textSecondary,
                    size: 28,
                  ),
                  if (showBadge)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.limeAccent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryDark,
                            width: 1,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppTheme.limeAccent : AppTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
    );
  }
} 