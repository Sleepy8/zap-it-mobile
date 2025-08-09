import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/friend_requests_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/e2ee_setup_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/fallback_screen.dart';
import 'firebase_init.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'widgets/animated_logo.dart';
import 'services/notification_service.dart';
import 'services/online_status_service.dart';
import 'debug_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable debug logging in debug mode
  if (kDebugMode) {
    DebugHelper.log('App starting in debug mode');
    DebugHelper.logPlatformInfo();
  }
  
  // Skip Firebase on iOS for now to test UI
  if (Platform.isIOS) {
    DebugHelper.log('Skipping Firebase initialization on iOS for UI testing');
  } else {
    try {
      // Initialize Firebase with error handling
      await initializeFirebase();
      
      // Initialize services only if Firebase is successful
      await _initializeServices();
      
    } catch (e) {
      DebugHelper.logError('Critical initialization error', e);
      // Continue with app even if services fail
    }
  }
  
  runApp(const ZapItApp());
}

Future<void> _initializeServices() async {
  // Initialize push notifications with better error handling
  try {
    final notificationService = NotificationService();
    await notificationService.initializePushNotifications();
    
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

  // Initialize online status service
  try {
    OnlineStatusService().initialize();
    DebugHelper.log('Online status service initialized');
  } catch (e) {
    DebugHelper.logError('Online status service initialization failed', e);
    // Don't crash the app if online status fails
  }
}

class ZapItApp extends StatelessWidget {
  const ZapItApp({Key? key}) : super(key: key);

  // Global navigator key for notification navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zap It',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Add global navigator key
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
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return ChatScreen(
            conversationId: args['conversationId'],
            otherUser: args['otherUser'],
          );
        },
        '/fallback': (context) => const FallbackScreen(),
        '/privacy-settings': (context) => const PrivacySettingsScreen(),
        '/notification-settings': (context) => const NotificationSettingsScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final AuthService _authService = AuthServiceFirebaseImpl();
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Set a shorter timeout to show login screen if Firebase takes too long
    // iOS needs shorter timeout due to different initialization behavior
    final timeoutDuration = Platform.isIOS ? const Duration(seconds: 2) : const Duration(seconds: 3);
    
    Future.delayed(timeoutDuration, () {
      if (mounted && !_isInitialized) {
        DebugHelper.log('Auth timeout reached, forcing login screen');
        setState(() {
          _isInitialized = true;
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - set online
        OnlineStatusService().setOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - set offline
        OnlineStatusService().setOffline();
        break;
      case AppLifecycleState.inactive:
        // App is inactive - set offline
        OnlineStatusService().setOffline();
        break;
    }
  }

  // Set navigation callback when app is ready
  void _setNavigationCallback() {
    final notificationService = NotificationService();
    notificationService.setNavigationCallback((conversationId, senderId, senderName) {
      print('🎯 Navigation callback called with: conversationId=$conversationId, senderId=$senderId, senderName=$senderName');
      print('🎯 Navigator key available: ${ZapItApp.navigatorKey.currentState != null}');
      
      if (ZapItApp.navigatorKey.currentState != null) {
        print('🎯 Attempting navigation to /chat');
        ZapItApp.navigatorKey.currentState!.pushNamed(
          '/chat',
          arguments: {
            'conversationId': conversationId,
            'otherUser': {
              'id': senderId,
              'username': senderName,
            },
          },
        );
        print('🎯 Navigation command sent');
      } else {
        print('❌ Navigator key not available');
      }
    });
    print('✅ Navigation callback set');
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to listen to Firebase Auth state changes (Instagram style)
    return StreamBuilder<User?>(
      stream: getFirebaseAuthStream(), // Use the safe stream function
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
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
                  ],
                ),
              ),
            ),
          );
        }
        
        // Handle error state or timeout
        if (snapshot.hasError || _hasError) {
          if (snapshot.hasError) {
            DebugHelper.logError('Auth stream error', snapshot.error);
          }
          // Show login screen on error or timeout
          return const LoginScreen();
        }
        
        // User is logged in - show MainScreen
        if (snapshot.hasData && snapshot.data != null) {
          _isInitialized = true;
          // Set navigation callback when user is logged in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setNavigationCallback();
          });
          return const MainScreen();
        }
        
        // User not logged in - show LoginScreen
        _isInitialized = true;
        return const LoginScreen();
      },
    );
  }
}
