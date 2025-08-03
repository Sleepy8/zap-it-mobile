import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'theme.dart';
import 'debug_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable debug logging in debug mode
  if (kDebugMode) {
    DebugHelper.log('App starting in ULTRA SIMPLE mode');
    DebugHelper.logPlatformInfo();
  }
  
  // NO FIREBASE - NO SERVICES - JUST UI TEST
  DebugHelper.log('Ultra simple mode - testing only UI');
  
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zap It Test',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppTheme.limeAccent,
                  borderRadius: BorderRadius.circular(65),
                ),
                child: const Icon(
                  Icons.flash_on,
                  size: 80,
                  color: Colors.black,
                ),
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
                'Test Mode - UI Working!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  DebugHelper.log('Button pressed - UI is working!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.limeAccent,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Test Button'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}