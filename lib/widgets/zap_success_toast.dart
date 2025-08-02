import 'package:flutter/material.dart';
import '../theme.dart';

class ZapSuccessToast extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;

  const ZapSuccessToast({
    Key? key,
    required this.message,
    this.duration = const Duration(milliseconds: 1800),
    this.onDismiss,
  }) : super(key: key);

  @override
  State<ZapSuccessToast> createState() => _ZapSuccessToastState();
}

class _ZapSuccessToastState extends State<ZapSuccessToast>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _iconController;
  late AnimationController _pulseController;
  
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconRotation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Icon rotation controller
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    // Pulse animation controller
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Slide animation (smooth slide down and up)
    _slideAnimation = Tween<double>(
      begin: -2.5,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));

    // Scale animation
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.elasticOut,
    ));

    // Icon rotation animation
    _iconRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOutCubic,
    ));

    // Pulse animation
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _mainController.forward();
    _iconController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);

    // Auto-dismiss with smooth slide up after delay
    Future.delayed(widget.duration, () {
      if (mounted) {
        _mainController.reverse().then((_) {
          if (mounted) {
            widget.onDismiss?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _iconController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 100),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: _buildToastContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToastContent() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(top: 40, left: 20, right: 20, bottom: 100),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withOpacity(0.95),
                  Colors.black.withOpacity(0.90),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.limeAccent.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.limeAccent.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon with pulse effect
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.limeAccent.withOpacity(0.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.limeAccent.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _iconController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _iconRotation.value * 0.1,
                              child: const Icon(
                                Icons.bolt,
                                color: Colors.white,
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                // Text content
                Flexible(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      letterSpacing: 0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Success checkmark - REMOVED
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showZapSuccessToast(BuildContext context, {String? message}) async {
  // Use Overlay instead of showGeneralDialog to avoid FAB interference
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;
  
  overlayEntry = OverlayEntry(
    builder: (context) => ZapSuccessToast(
      message: message ?? 'ZAP inviato! ⚡',
      onDismiss: () {
        overlayEntry.remove();
      },
    ),
  );
  
  overlay.insert(overlayEntry);
} 