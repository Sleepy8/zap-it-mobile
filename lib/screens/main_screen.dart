import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/animated_floating_action_button.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'zap_history_screen.dart';
import 'vibe_composer_screen.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _unreadZapCount = 0;
  int _friendsCount = 0;
  bool _friendsListenerSet = false;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthServiceFirebaseImpl();
  Timer? _accountCheckTimer;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _homeScreenKey),
      const LeaderboardScreen(),
      const VibeComposerScreen(),
      const ZapHistoryScreen(),
      const ProfileScreen(),
    ];
    
    // Listen for unread ZAP count
    _notificationService.getUnreadZapCountStream().listen((count) {
      if (mounted) {
        setState(() {
          _unreadZapCount = count;
        });
      }
    });

    // Start account deletion listener
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authService.startAccountDeletionListener(context);
    });

    // Start periodic account existence check (every 30 seconds)
    _accountCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAccountExists();
    });
  }

  Future<void> _checkAccountExists() async {
    try {
      final user = _authService.getCurrentUser();
      if (user != null) {
        final exists = await _authService.checkAccountExists(user.uid);
        if (!exists && mounted) {
          // Account has been deleted, sign out user
          await _authService.logout();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Il tuo account è stato eliminato. Sei stato sloggato.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _authService.stopAccountDeletionListener();
    _accountCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set friends count listener only once
    if (!_friendsListenerSet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _homeScreenKey.currentState?.addFriendsCountListener((count) {
          if (mounted) {
            setState(() {
              _friendsCount = count;
            });
          }
        });
        _friendsListenerSet = true;
      });
    }
    
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: Stack(
        children: [
          _screens[_currentIndex],
          // Custom floating action button for adding friends
          if (_currentIndex == 0)
            AnimatedFloatingActionButton(
              friendsCount: _friendsCount,
              onPressed: () {
                _homeScreenKey.currentState?.showAddFriendDialog();
              },
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Se stiamo uscendo dalla sezione Vibe Composer (indice 2), ferma eventuali vibrazioni
          if (_currentIndex == 2 && index != 2) {
            // Ferma vibrazioni in corso
          }
          
          // Se stiamo uscendo dalla sezione ZAP (indice 3), marca tutti i ZAP come letti
          if (_currentIndex == 3 && index != 3) {
            _notificationService.markAllZapsAsRead();
          }
          
          setState(() {
            _currentIndex = index;
          });
        },
        unreadZapCount: _unreadZapCount,
      ),
    );
  }
} 