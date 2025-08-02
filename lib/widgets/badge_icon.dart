import 'package:flutter/material.dart';
import '../theme.dart';

class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int? count;
  final VoidCallback? onPressed;
  final String? tooltip;

  const BadgeIcon({
    Key? key,
    required this.icon,
    this.count,
    this.onPressed,
    this.tooltip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed,
          tooltip: tooltip,
        ),
        if (count != null && count! > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.limeAccent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryDark,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                count! > 99 ? '99+' : count.toString(),
                style: const TextStyle(
                  color: AppTheme.primaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
      ],
    );
  }
} 