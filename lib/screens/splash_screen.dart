import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/animated_logo.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _textController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _textMoveAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Text animation controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Glow animation controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Main fade and scale animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    // Text animations
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    _textMoveAnimation = Tween<double>(
      begin: 25.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    ));

    // Glow animation
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOutCubic,
    ));

    _startAnimations();
  }

  void _startAnimations() async {
    // Start main animation
    _mainController.forward();
    
    // Start glow animation after a delay
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      _glowController.forward();
    }
    
    // Start text animation
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _textController.forward();
    }

    // Don't navigate automatically - let AuthWrapper handle navigation
    // Future.delayed(const Duration(seconds: 3), () {
    //   if (mounted) {
    //     Navigator.of(context).pushReplacementNamed('/');
    //   }
    // });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _textController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _mainController,
            _textController,
            _glowController,
          ]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo con glow effect allineati
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glow effect
                        AnimatedBuilder(
                          animation: _glowAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.limeAccent.withOpacity(0.2 * _glowAnimation.value),
                                    blurRadius: 40 * _glowAnimation.value,
                                    spreadRadius: 10 * _glowAnimation.value,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        
                        // Logo centrato sopra il glow
                        AnimatedLogo(
                          size: 130,
                          isSplashScreen: true,
                          showText: false,
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // App title with animation
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textFadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _textMoveAnimation.value),
                            child: Column(
                              children: [
                                Text(
                                  'Zap It',
                                  style: TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.limeAccent,
                                    letterSpacing: 3,
                                    shadows: [
                                      Shadow(
                                        color: AppTheme.limeAccent.withOpacity(0.3),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Vibrazioni che parlano',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 1.5,
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
          },
        ),
      ),
    );
  }
} 