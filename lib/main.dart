import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/friend_requests_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/e2ee_setup_screen.dart';
import 'screens/user_profile_screen.dart';
import 'firebase_init.dart';
import 'services/background_service.dart';
import 'services/auth_service.dart';
import 'widgets/animated_logo.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await initializeFirebase();
  
  // Inizializza notifiche push
  await NotificationService().initializePushNotifications();

  // Start background service
  await BackgroundService().start();
  
  runApp(const ZapItApp());
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

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to listen to Firebase Auth state changes (Instagram style)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppTheme.primaryDark,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedLogo(
                    size: 130,
                    isSplashScreen: true,
                    showText: false,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    color: AppTheme.limeAccent,
                  ),
                ],
              ),
            ),
          );
        }
        
        // User is logged in - show MainScreen
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }
        
        // User not logged in - show LoginScreen
        return const LoginScreen();
      },
    );
  }
}