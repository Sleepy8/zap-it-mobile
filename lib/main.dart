import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/friend_requests_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/e2ee_setup_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/fallback_screen.dart';
import 'firebase_init.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'widgets/animated_logo.dart';
import 'services/notification_service.dart';
import 'debug_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable debug logging in debug mode
  if (kDebugMode) {
    DebugHelper.log('App starting in debug mode');
    DebugHelper.logPlatformInfo();
  }
  
  try {
    // Initialize Firebase with error handling
    await initializeFirebase();
    
    // Initialize services only if Firebase is successful
    await _initializeServices();
    
  } catch (e) {
    DebugHelper.logError('Critical initialization error', e);
    // Continue with app even if services fail
  }
  
  runApp(const ZapItApp());
}

Future<void> _initializeServices() async {
  // Initialize push notifications with better error handling
  try {
    await NotificationService().initializePushNotifications();
    DebugHelper.log('Notification service initialized');
  } catch (e) {
    DebugHelper.logError('Notification service initialization failed', e);
    // Don't crash the app if notifications fail
  }

  // Start background service with better error handling
  try {
    await BackgroundService().start();
    DebugHelper.log('Background service started');
  } catch (e) {
    DebugHelper.logError('Background service initialization failed', e);
    // Don't crash the app if background service fails
  }
}

class ZapItApp extends StatelessWidget {
  const ZapItApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zap It',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/friend-requests': (context) => const FriendRequestsScreen(),
        '/messages': (context) => const MessagesScreen(),
        '/e2ee-setup': (context) => const E2EESetupScreen(),
        '/user-profile': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return UserProfileScreen(
            userId: args['userId'],
            username: args['username'],
          );
        },
        '/fallback': (context) => const FallbackScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthServiceFirebaseImpl();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Set a timeout to show login screen if Firebase takes too long
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_isInitialized) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to listen to Firebase Auth state changes (Instagram style)
    return StreamBuilder<User?>(
      stream: getFirebaseAuthStream(), // Use the safe stream function
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
          return const FallbackScreen();
        }
        
        // Handle error state or timeout
        if (snapshot.hasError || _isInitialized) {
          if (snapshot.hasError) {
            DebugHelper.logError('Auth stream error', snapshot.error);
          }
          // Show login screen on error or timeout
          return const LoginScreen();
        }
        
        // User is logged in - show MainScreen
        if (snapshot.hasData && snapshot.data != null) {
          _isInitialized = true;
          return const MainScreen();
        }
        
        // User not logged in - show LoginScreen
        _isInitialized = true;
        return const LoginScreen();
      },
    );
  }
}