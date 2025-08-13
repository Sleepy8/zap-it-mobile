import 'package:flutter/material.dart';
import '../theme.dart';

class HorizontalVibeTrack extends StatefulWidget {
  final double intensity;
  final ValueChanged<double>? onIntensityChanged;
  final ValueChanged<Offset>? onPositionChanged;
  final VoidCallback? onTapStart;
  final VoidCallback? onTapEnd;
  final bool isActive;
  final bool showGrid;

  const HorizontalVibeTrack({
    Key? key,
    required this.intensity,
    this.onIntensityChanged,
    this.onPositionChanged,
    this.onTapStart,
    this.onTapEnd,
    this.isActive = false,
    this.showGrid = true,
  }) : super(key: key);

  @override
  State<HorizontalVibeTrack> createState() => _HorizontalVibeTrackState();
}

class _HorizontalVibeTrackState extends State<HorizontalVibeTrack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant HorizontalVibeTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateIntensityFromPosition(Offset position) {
    final height = 120.0;
    final padding = 10.0;
    final usableHeight = height - 2 * padding;

    double normalizedY = (position.dy - padding) / usableHeight;
    normalizedY = 1.0 - normalizedY;

    double newIntensity = normalizedY.clamp(0.0, 1.0);

    if (widget.onIntensityChanged != null) {
      widget.onIntensityChanged!(newIntensity);
    }
    if (widget.onPositionChanged != null) {
      widget.onPositionChanged!(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        widget.onTapStart?.call();
        _updateIntensityFromPosition(details.localPosition);
      },
      onPanUpdate: (details) {
        _updateIntensityFromPosition(details.localPosition);
      },
      onPanEnd: (details) {
        widget.onTapEnd?.call();
      },
      onTapDown: (details) {
        widget.onTapStart?.call();
        _updateIntensityFromPosition(details.localPosition);
      },
      onTapUp: (details) {
        widget.onTapEnd?.call();
      },
      onTapCancel: () {
        widget.onTapEnd?.call();
      },
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (widget.showGrid) _buildBackgroundGrid(),
            _buildRippleEffect(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    return CustomPaint(
      painter: HorizontalGridPainter(
        intensity: widget.intensity,
        isActive: widget.isActive,
      ),
      size: const Size(double.infinity, 120),
    );
  }

  Widget _buildRippleEffect() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(20),
              gradient: RadialGradient(
                colors: [
                  _getIntensityColor(widget.intensity).withValues(alpha: 0.3),
                  _getIntensityColor(widget.intensity).withValues(alpha: 0.0),
                ],
                stops: [0.0, 1.0],
                center: Alignment.center,
                radius: 0.5 + (_animation.value * 0.5),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getIntensityColor(double intensity) {
    if (intensity > 0.8) return AppTheme.limeAccent;
    if (intensity > 0.6) return AppTheme.limeAccent.withValues(alpha: 0.8);
    if (intensity > 0.4) return AppTheme.limeAccent.withValues(alpha: 0.6);
    if (intensity > 0.2) return AppTheme.limeAccent.withValues(alpha: 0.4);
    return AppTheme.limeAccent.withValues(alpha: 0.2);
  }
}

class HorizontalGridPainter extends CustomPainter {
  final double intensity;
  final bool isActive;

  HorizontalGridPainter({required this.intensity, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textSecondary.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 5; i++) {
      final y = (i / 5) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);

      final intensityLabel = _getIntensityLabel(i);
      final textPainter = TextPainter(
        text: TextSpan(
          text: intensityLabel,
          style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - textPainter.width - 8, y - textPainter.height / 2));
    }

    for (int i = 0; i <= 8; i++) {
      final x = (i / 8) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    if (isActive) {
      final indicatorY = size.height * (1.0 - intensity);
      final indicatorPaint = Paint()
        ..color = _getIntensityColor(intensity)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(0, indicatorY), Offset(size.width, indicatorY), indicatorPaint);

      final currentIntensityLabel = '${(intensity * 100).round()}%';
      final currentTextPainter = TextPainter(
        text: TextSpan(
          text: currentIntensityLabel,
          style: TextStyle(
            color: _getIntensityColor(intensity),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      currentTextPainter.layout();
      currentTextPainter.paint(canvas, Offset(8, indicatorY - currentTextPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(HorizontalGridPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.isActive != isActive;
  }

  Color _getIntensityColor(double intensity) {
    if (intensity > 0.8) return AppTheme.limeAccent;
    if (intensity > 0.6) return AppTheme.limeAccent.withValues(alpha: 0.8);
    if (intensity > 0.4) return AppTheme.limeAccent.withValues(alpha: 0.6);
    if (intensity > 0.2) return AppTheme.limeAccent.withValues(alpha: 0.4);
    return AppTheme.limeAccent.withValues(alpha: 0.2);
  }

  String _getIntensityLabel(int index) {
    switch (index) {
      case 0: return 'MAX';
      case 1: return 'HIGH';
      case 2: return 'MED';
      case 3: return 'LOW';
      case 4: return 'MIN';
      case 5: return '0%';
      default: return '';
    }
  }
}
