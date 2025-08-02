import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/bottom_navigation.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';
import 'zap_history_screen.dart';
import 'vibe_composer_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _unreadZapCount = 0;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  final NotificationService _notificationService = NotificationService();

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
    

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              heroTag: "main_fab",
              onPressed: () {
                _homeScreenKey.currentState?.showZapSendDialog();
              },
              backgroundColor: AppTheme.limeAccent,
              child: const Icon(
                Icons.person_add,
                color: AppTheme.primaryDark,
              ),
            )
          : null,
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