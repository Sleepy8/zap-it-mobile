import 'package:flutter/material.dart';
import '../theme.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
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
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : () {
                _animationController.forward().then((_) {
                  _animationController.reverse();
                });
                widget.onPressed?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.limeAccent,
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ).copyWith(
                backgroundColor: MaterialStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(MaterialState.pressed)) {
                      return AppTheme.limeAccent.withOpacity(0.8);
                    }
                    if (states.contains(MaterialState.disabled)) {
                      return AppTheme.limeAccent.withOpacity(0.5);
                    }
                    return AppTheme.limeAccent;
                  },
                ),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryDark,
                        ),
                      ),
                    )
                  : Text(
                      widget.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
} 