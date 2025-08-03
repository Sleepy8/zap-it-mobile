import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/animated_logo.dart';

class FallbackScreen extends StatelessWidget {
  const FallbackScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedLogo(
                size: 130,
                isSplashScreen: true,
                showText: true,
              ),
              const SizedBox(height: 30),
              const Text(
                'Zap It',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.limeAccent,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Caricamento...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(
                color: AppTheme.limeAccent,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Force restart the app
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text(
                  'Riprova',
                  style: TextStyle(
                    color: AppTheme.limeAccent,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 