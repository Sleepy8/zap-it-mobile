import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'screens/blocked_users_screen.dart';
import 'screens/chat_screen.dart';

import 'screens/fallback_screen.dart';
import 'firebase_init.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'widgets/animated_logo.dart';
import 'services/notification_service.dart';
import 'services/online_status_service.dart';
import 'services/advanced_haptics_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Always try to initialize Firebase, but don't crash if it fails
  bool firebaseInitialized = false;
  try {
    await initializeFirebase();
    firebaseInitialized = true;
  } catch (e) {
    firebaseInitialized = false;
  }
  
  // Initialize services only if Firebase is successful
  if (firebaseInitialized) {
    try {
      await _initializeServices();
    } catch (e) {
      // Continue with app even if services fail
    }
  }
  
  runApp(const ZapItApp());
}

Future<void> _initializeServices() async {
  // Initialize haptics service first
  try {
    final hapticsService = AdvancedHapticsService();
    await hapticsService.initialize();
  } catch (e) {
    // Don't crash the app if haptics fail
  }

  // Initialize push notifications with better error handling
  try {
    final notificationService = NotificationService();
    await notificationService.initializePushNotifications();
  } catch (e) {
    // Don't crash the app if notifications fail
  }

  // Start background service with better error handling
  try {
    await BackgroundService().start();
  } catch (e) {
    // Don't crash the app if background service fails
  }

  // Initialize online status service
  try {
    final onlineStatusService = OnlineStatusService();
    onlineStatusService.initialize();
  } catch (e) {
    // Don't crash the app if online status fails
  }
}

class ZapItApp extends StatefulWidget {
  const ZapItApp({Key? key}) : super(key: key);

  // Global navigator key for notification navigation
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<ZapItApp> createState() => _ZapItAppState();
}

class _ZapItAppState extends State<ZapItApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Update haptics service with app state
    final hapticsService = AdvancedHapticsService();
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground
        hapticsService.setAppForegroundState(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // App is in background or inactive
        hapticsService.setAppForegroundState(false);
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        hapticsService.setAppForegroundState(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zap It',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: widget.navigatorKey, // Add global navigator key
      home: const AuthWrapper(),
      builder: (context, child) {
        // Ensure proper scaling and prevent black screen issues
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
            // Add safe area padding to prevent content from being hidden
            padding: MediaQuery.of(context).padding,
          ),
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
            otherUserId: args['otherUserId'],
            otherUsername: args['otherUsername'],
          );
        },
        '/fallback': (context) => FallbackScreen(),
        '/privacy-settings': (context) => const PrivacySettingsScreen(),
        '/notification-settings': (context) => const NotificationSettingsScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/blocked-users': (context) => const BlockedUsersScreen(),
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize immediately for better UX
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Set a shorter timeout to show login screen if Firebase takes too long
      final timeoutDuration = Platform.isIOS ? const Duration(seconds: 3) : const Duration(seconds: 5);
      
      // Wait for either Firebase to initialize or timeout
      await Future.any([
        _waitForFirebase(),
        Future.delayed(timeoutDuration),
      ]);
      
      // Check if user is already authenticated immediately after Firebase init
      final currentUser = _authService.getCurrentUser();
      final isAuthenticated = currentUser != null;
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
          // If user is already authenticated, we don't need to show login screen
          if (isAuthenticated) {
            _hasError = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _waitForFirebase() async {
    try {
      // Wait for Firebase to be ready
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      // Silent error handling
    }
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
        try {
          OnlineStatusService().setOnline();
        } catch (e) {
          // Silent error handling
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - set offline
        try {
          OnlineStatusService().setOffline();
        } catch (e) {
          // Silent error handling
        }
        break;
      case AppLifecycleState.inactive:
        // App is inactive - set offline
        try {
          OnlineStatusService().setOffline();
        } catch (e) {
          // Silent error handling
        }
        break;
    }
  }

  // Set navigation callback when app is ready
  void _setNavigationCallback() {
    try {
      final notificationService = NotificationService();
      notificationService.setNavigationCallback((conversationId, senderId, senderName) {
        if (ZapItApp.navigatorKey.currentState != null) {
          ZapItApp.navigatorKey.currentState!.pushNamed(
            '/chat',
            arguments: {
              'conversationId': conversationId,
              'otherUserId': senderId,
              'otherUsername': senderName,
            },
          );
        }
      });
      
      // Check for pending navigation after setting callback
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notificationService.checkPendingNavigation();
      });
    } catch (e) {
      // Silent error handling
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while initializing
    if (_isLoading) {
      return const SplashScreen();
    }
    
    // Check if user is already authenticated before showing login screen
    final currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      // User is already authenticated, go directly to MainScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setNavigationCallback();
      });
      return const MainScreen();
    }
    
    // Handle error state or timeout
    if (_hasError) {
      return const LoginScreen();
    }
    
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading screen while initializing
        if (!_isInitialized) {
          return const SplashScreen();
        }
        
        // Handle error state
        if (snapshot.hasError) {
          return const LoginScreen();
        }
        
        // User is logged in - show MainScreen
        if (snapshot.hasData && snapshot.data != null) {
          // Set navigation callback when user is logged in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setNavigationCallback();
          });
          return const MainScreen();
        }
        
        // User not logged in - show LoginScreen
        return const LoginScreen();
      },
    );
  }
}
