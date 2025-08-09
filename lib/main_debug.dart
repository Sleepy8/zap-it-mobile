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
import 'screens/test_screen.dart';
import 'screens/fallback_screen.dart';
import 'debug_helper.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable debug logging in debug mode
  if (kDebugMode) {
    DebugHelper.log('App starting in DEBUG mode - NO FIREBASE');
    DebugHelper.logPlatformInfo();
  }
  
  // Skip all Firebase and service initialization for debugging
  DebugHelper.log('Skipping all Firebase and service initialization for debugging');
  
  runApp(const ZapItAppDebug());
}

class ZapItAppDebug extends StatelessWidget {
  const ZapItAppDebug({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zap It - DEBUG',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: true,
      home: const TestScreen(), // Go directly to test screen
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
        '/fallback': (context) => const FallbackScreen(),
        '/privacy-settings': (context) => const PrivacySettingsScreen(),
        '/notification-settings': (context) => const NotificationSettingsScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/test': (context) => const TestScreen(),
      },
    );
  }
}
