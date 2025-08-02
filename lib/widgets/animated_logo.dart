import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../theme.dart';

class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool isSplashScreen;
  final VoidCallback? onAnimationComplete;
  final bool showText;

  const AnimatedLogo({
    Key? key,
    this.size = 120,
    this.isSplashScreen = false,
    this.onAnimationComplete,
    this.showText = true,
  }) : super(key: key);

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 5500),
      vsync: this,
    );
    _progress = _mainController;
    _mainController.repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _mainController,
      builder: (context, child) {
        final progress = _progress.value;
        // Animation phases
        // 0.0–0.04: only circle+shadow+bolt+vibrazioni (short pause)
        // 0.04–0.96: archi compaiono, ruotano e scompaiono (fade/grow in/out)
        // 0.96–1.0: only circle+shadow+bolt+vibrazioni (short pause)
        double arcsOpacity = 0;
        double arcsGrow = 0;
        if (progress >= 0.04 && progress <= 0.96) {
          final t = (progress - 0.04) / 0.92;
          // Fade in (0-0.357), fade out (0.357-1)
          if (t < 0.357) {
            final tIn = t / 0.357;
            arcsOpacity = Curves.easeOut.transform(tIn);
            arcsGrow = Curves.easeOutBack.transform(tIn);
          } else {
            final tOut = (t - 0.357) / (1 - 0.357);
            arcsOpacity = Curves.easeIn.transform(1 - tOut);
            arcsGrow = Curves.easeInBack.transform(1 - tOut);
          }
        }
        // Pulsazione sempre attiva per le vibrazioni
        final pulse = 0.98 + 0.15 * math.sin(progress * math.pi * 2);
        // Rotazione archi solo durante la fase centrale
        final angleOffset = arcsGrow * progress * 6 * math.pi;
        return FadeTransition(
          opacity: AlwaysStoppedAnimation(1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Lime shadow (always visible) - disabilitata per splash screen
                    if (!widget.isSplashScreen)
                      Container(
                        width: widget.size * 0.98,
                        height: widget.size * 0.98,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.limeAccent.withOpacity(0.45),
                              blurRadius: widget.size * 0.4,
                              spreadRadius: widget.size * 0.08,
                            ),
                          ],
                        ),
                      ),
                    // Pulsing dark circle
                    Transform.scale(
                      scale: pulse,
                      child: Container(
                        width: widget.size * 0.82,
                        height: widget.size * 0.82,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryDark,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Broken animated arcs (fade/grow in/out)
                    if (arcsOpacity > 0)
                      Opacity(
                        opacity: arcsOpacity,
                        child: CustomPaint(
                          size: Size(widget.size * 0.95, widget.size * 0.95),
                          painter: _BrokenArcsPainter(
                            color: AppTheme.limeAccent,
                            progress: progress,
                            angleOffset: angleOffset,
                            grow: arcsGrow,
                          ),
                        ),
                      ),
                    // Vibrazioni SEMPRE visibili e animate
                    CustomPaint(
                      size: Size(widget.size * 1.2, widget.size * 1.2),
                      painter: _RandomVibePainter(
                        color: AppTheme.limeAccent,
                        time: progress,
                        angleOffset: 0,
                        grow: 1.5,
                      ),
                    ),
                    // Stylized central lightning (thicker)
                    CustomPaint(
                      size: Size(widget.size * 0.5, widget.size * 0.40),
                      painter: _StylizedLightningPainter(color: AppTheme.limeAccent, thickness: widget.size * 0.18),
                    ),
                  ],
                ),
              ),
              if (widget.showText && !widget.isSplashScreen) ...[
                const SizedBox(height: 35),
                Text(
                  'Zap It',
                  style: TextStyle(
                    fontSize: widget.size * 0.30,
                    fontWeight: FontWeight.w900,
                    color: Colors.limeAccent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Stylized lightning bolt painter (classic zig-zag, icon style)
class _StylizedLightningPainter extends CustomPainter {
  final Color color;
  final double thickness;
  _StylizedLightningPainter({required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final path = Path();
    // Classic zig-zag lightning bolt (iconic)
    path.moveTo(w * 0.50, 0.0);         // Top center
    path.lineTo(w * 0.32, h * 0.48);    // Down left
    path.lineTo(w * 0.46, h * 0.48);    // Short right
    path.lineTo(w * 0.28, h * 1.00);    // Down left (bottom)
    path.lineTo(w * 0.68, h * 0.52);    // Up right
    path.lineTo(w * 0.54, h * 0.52);    // Short left
    path.lineTo(w * 0.72, 0.0);         // Up right (top)
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StylizedLightningPainter oldDelegate) => false;
}

// Broken animated arcs painter (with grow/fade)
class _BrokenArcsPainter extends CustomPainter {
  final Color color;
  final double progress;
  final double angleOffset;
  final double grow;
  _BrokenArcsPainter({required this.color, required this.progress, required this.angleOffset, required this.grow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radii = [size.width * 0.36, size.width * 0.44, size.width * 0.52];
    final arcCount = 3;
    final arcSegments = 5;
    final arcSweep = math.pi * 1.2 * grow;
    final arcGap = math.pi * 0.25;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.025 * (0.7 + 0.6 * grow)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < arcCount; i++) {
      final r = radii[i];
      for (int j = 0; j < arcSegments; j++) {
        final start = (arcGap * j) + angleOffset + i * 0.3;
        final sweep = arcSweep / arcSegments * (0.8 + 0.4 * math.sin(progress * math.pi + i + j));
        if (grow > 0.01) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: r),
            start,
            sweep,
            false,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BrokenArcsPainter oldDelegate) => true;
}

// Animated, random vibration painter (smooth sinusoidal, slightly thicker lines)
class _RandomVibePainter extends CustomPainter {
  final Color color;
  final double time;
  final double angleOffset;
  final double grow;
  _RandomVibePainter({required this.color, required this.time, required this.angleOffset, required this.grow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final n = 24;
    final baseRadius = size.width * 0.6;
    final paint = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = size.width * 0.018 * (0.7 + 0.6 * grow)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < n; i++) {
      final angle = (i * 2 * math.pi / n) + angleOffset + math.sin(time * 2 + i) * 0.08;
      // Smooth, continuous length and vibration
      final baseLen = size.width * (0.09 + 0.07 * math.sin(time * 2 * math.pi + i * 1.2));
      final wave = math.sin(time * 4 * math.pi + i);
      final len = baseLen * (0.85 + 0.15 * wave) * grow;
      // Alternate smoothly between straight and zig-zag using a sinusoidal blend
      final zigzagAmount = 0.5 + 0.5 * math.sin(time * 2 * math.pi + i);
      final start = Offset(
        center.dx + math.cos(angle) * baseRadius,
        center.dy + math.sin(angle) * baseRadius,
      );
      final end = Offset(
        center.dx + math.cos(angle) * (baseRadius + len),
        center.dy + math.sin(angle) * (baseRadius + len),
      );
      if (zigzagAmount < 0.2) {
        // Pure straight line
        canvas.drawLine(start, end, paint);
      } else if (zigzagAmount > 0.8) {
        // Pure zig-zag
        final mid1 = Offset(
          center.dx + math.cos(angle) * (baseRadius + len * 0.4) + math.cos(angle + 0.5) * len * 0.15,
          center.dy + math.sin(angle) * (baseRadius + len * 0.4) + math.sin(angle + 0.5) * len * 0.15,
        );
        final mid2 = Offset(
          center.dx + math.cos(angle) * (baseRadius + len * 0.7) + math.cos(angle - 0.5) * len * 0.12,
          center.dy + math.sin(angle) * (baseRadius + len * 0.7) + math.sin(angle - 0.5) * len * 0.12,
        );
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid1.dx, mid1.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, paint);
      } else {
        // Blend between straight and zig-zag
        final mid1 = Offset.lerp(
          end,
          Offset(
            center.dx + math.cos(angle) * (baseRadius + len * 0.4) + math.cos(angle + 0.5) * len * 0.15,
            center.dy + math.sin(angle) * (baseRadius + len * 0.4) + math.sin(angle + 0.5) * len * 0.15,
          ),
          zigzagAmount,
        )!;
        final mid2 = Offset.lerp(
          end,
          Offset(
            center.dx + math.cos(angle) * (baseRadius + len * 0.7) + math.cos(angle - 0.5) * len * 0.12,
            center.dy + math.sin(angle) * (baseRadius + len * 0.7) + math.sin(angle - 0.5) * len * 0.12,
          ),
          zigzagAmount,
        )!;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(mid1.dx, mid1.dy)
          ..lineTo(mid2.dx, mid2.dy)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RandomVibePainter oldDelegate) => true;
}

// Animated splash screen widget
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const AnimatedSplashScreen({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedLogo(
              size: 150,
              isSplashScreen: true,
              onAnimationComplete: widget.onComplete,
            ),
            const SizedBox(height: 40),
            Text(
              'ZAP IT',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.limeAccent,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vibrazioni che parlano',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 

// ARTISTIC SPLASH SCREEN ANIMATION
class SplashStartupAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashStartupAnimation({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SplashStartupAnimation> createState() => _SplashStartupAnimationState();
}

class _SplashStartupAnimationState extends State<SplashStartupAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _glowController;
  late AnimationController _flashController;
  late AnimationController _particleController;
  late AnimationController _textController;

  late Animation<double> _glowAnimation;
  late Animation<double> _flashAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textMoveAnimation;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeOutCubic),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOutExpo),
    );
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeOut),
    );
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textMoveAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutBack),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    _mainController.forward();
    _glowController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _flashController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _particleController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted || _completed) return;
    _completed = true;
    widget.onComplete();
  }

  @override
  void dispose() {
    _completed = true;
    _mainController.dispose();
    _glowController.dispose();
    _flashController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = 160.0;
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Flash expanding
            AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 1.0 - _flashAnimation.value,
                  child: Container(
                    width: size * (1 + _flashAnimation.value * 2),
                    height: size * (1 + _flashAnimation.value * 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.limeAccent.withOpacity(0.25 * (1 - _flashAnimation.value)),
                    ),
                  ),
                );
              },
            ),
            // Glow
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: size * 1.3,
                  height: size * 1.3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.limeAccent.withOpacity(0.5 * _glowAnimation.value),
                        blurRadius: 40 * _glowAnimation.value,
                        spreadRadius: 20 * _glowAnimation.value,
                      ),
                    ],
                  ),
                );
              },
            ),
            // Particles/energy lines
            AnimatedBuilder(
              animation: _particleAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(size * 1.5, size * 1.5),
                  painter: _EnergyPainter(_particleAnimation.value),
                );
              },
            ),
            // Main logo
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.limeAccent,
                    AppTheme.limeAccent.withOpacity(0.8),
                    AppTheme.primaryDark,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.limeAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.flash_on,
                  size: size * 0.55,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
            // App title and subtitle
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textFadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _textMoveAnimation.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ZAP IT',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.limeAccent,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vibrazioni che parlano',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Painter for energy lines/particles
class _EnergyPainter extends CustomPainter {
  final double progress;
  _EnergyPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppTheme.limeAccent.withOpacity(0.7 * (1 - progress))
      ..strokeWidth = 2;
    final lines = 8;
    final radius = size.width * 0.38;
    for (int i = 0; i < lines; i++) {
      final angle = (i * 2 * math.pi / lines) + (progress * 2 * math.pi);
      final start = center + Offset(
        math.cos(angle) * (radius + 10 * progress),
        math.sin(angle) * (radius + 10 * progress),
      );
      final end = center + Offset(
        math.cos(angle) * (radius + 40 * progress),
        math.sin(angle) * (radius + 40 * progress),
      );
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyPainter oldDelegate) => true;
} 