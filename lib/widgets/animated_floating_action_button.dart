import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

class AnimatedFloatingActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final int friendsCount;

  const AnimatedFloatingActionButton({
    Key? key,
    this.onPressed,
    required this.friendsCount,
  }) : super(key: key);

  @override
  State<AnimatedFloatingActionButton> createState() => _AnimatedFloatingActionButtonState();
}

class _AnimatedFloatingActionButtonState extends State<AnimatedFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if no friends
    if (widget.friendsCount == 0) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      right: 16,
      bottom: 20, // Much closer to bottom navigation
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: () {
                // Trigger haptic feedback
                HapticFeedback.mediumImpact();
                
                // Start stable animation (same as CustomButton)
                _animationController.forward().then((_) {
                  _animationController.reverse();
                });
                
                widget.onPressed?.call();
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_add,
                  color: AppTheme.primaryDark,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
