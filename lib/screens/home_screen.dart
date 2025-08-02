import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';
import '../services/messages_service.dart';
import '../services/notification_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/add_friend_modal.dart';
import '../widgets/zap_send_modal.dart';
import '../widgets/zap_success_toast.dart';
import '../widgets/badge_icon.dart';
import '../screens/messages_screen.dart';
import '../theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _authService = AuthServiceFirebaseImpl();
  final _friendsService = FriendsService();
  final _messagesService = MessagesService();
  final _notificationService = NotificationService();
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  bool _isNavigating = false;
  
  // Home shake animation
  late AnimationController _homeShakeController;
  late Animation<double> _homeShakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize home shake animation
    _homeShakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _homeShakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _homeShakeController,
      curve: Curves.easeInOut,
    ));
    
    _loadFriends();
    _loadPendingRequests();
  }

  Future<void> _loadFriends() async {
    try {
      // Listen to friends stream
      _friendsService.getFriendsStream().listen((friends) {
        if (mounted) {
          setState(() {
            _friends = friends;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadPendingRequests() {
    _friendsService.getPendingRequests().listen((requests) {
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    });
  }

  void _showRemoveFriendDialog(Map<String, dynamic> friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Rimuovi Amico',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Sei sicuro di voler rimuovere @${friend['username']} dai tuoi amici? Questa azione non può essere annullata.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annulla',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    try {
      final success = await _friendsService.removeFriendship(friend['id']);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${friend['username']} rimosso dagli amici'),
            backgroundColor: AppTheme.limeAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nella rimozione dell\'amico'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void showAddFriendDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddFriendModal(
        friendsService: _friendsService,
      ),
    );
  }

  void showZapSendDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ZapSendModal(
        friendsService: _friendsService,
      ),
    );
  }

  Future<void> _zapFriend(String friendId) async {
    try {
      // Trigger home shake animation
      _homeShakeController.forward().then((_) {
        _homeShakeController.reverse();
      });
      
      // Get sender info for notification
      final currentUser = _authService.getCurrentUser();
      String senderName = 'Un amico';
      String username = 'amico';
      if (currentUser != null) {
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        senderName = senderDoc.data()?['name'] ?? 'Un amico';
        
        // Get friend info for username
        final friendDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(friendId)
            .get();
        username = friendDoc.data()?['username'] ?? 'amico';
      }

      final success = await _notificationService.sendZapNotification(friendId, senderName);
      
      if (success && mounted) {
        // Show beautiful success toast
        await showZapSuccessToast(context, message: 'ZAP inviato a @$username! ⚡');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _startChat(Map<String, dynamic> friend) async {
    try {
      // Disabilita temporaneamente il pulsante per evitare doppi click
      if (_isNavigating) return;
      _isNavigating = true;
      
      final conversationId = await _messagesService.getOrCreateConversation(friend['id']);
      if (conversationId != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUser: {
                'id': friend['id'],
                'username': friend['username'],
              },
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nell\'avvio della chat: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      _isNavigating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Zap It'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: BadgeIcon(
          icon: Icons.person_add,
          count: _pendingRequests.length,
          onPressed: () => Navigator.pushNamed(context, '/friend-requests'),
          tooltip: 'Richieste Amicizia',
        ),
                 actions: [
           IconButton(
             icon: const Icon(Icons.chat_bubble_outline),
             onPressed: () => Navigator.pushNamed(context, '/messages'),
             tooltip: 'Messaggi',
           ),

         ],
      ),
      body: AnimatedBuilder(
        animation: _homeShakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              _homeShakeAnimation.value * 12 * 
              (1 - _homeShakeAnimation.value) * 
              (1 - _homeShakeAnimation.value), 
              0
            ),
            child: SafeArea(
              child: Column(
                children: [
                  
                  // Main content
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                            ),
                          )
                        : _friends.isEmpty
                            ? _buildEmptyState()
                            : _buildFriendsList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),

    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.limeAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: AppTheme.limeAccent.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.people_outline,
                size: 60,
                color: AppTheme.limeAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nessun amico ancora',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Aggiungi i tuoi amici per iniziare a fare ZAP!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Aggiungi Il Primo Amico',
              onPressed: showAddFriendDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _buildFriendCard(friend);
      },
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return InkWell(
      onTap: () {
        // Navigate to user profile
        Navigator.pushNamed(
          context,
          '/user-profile',
          arguments: {
            'userId': friend['id'],
            'username': friend['username'],
          },
        );
      },
      onLongPress: () {

        // Feedback tattile
        HapticFeedback.heavyImpact();
        _showRemoveFriendDialog(friend);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.limeAccent.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Immagine profilo
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.limeAccent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: friend['profileImageUrl'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        friend['profileImageUrl'],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Icon(
                            Icons.person,
                            size: 30,
                            color: AppTheme.primaryDark,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 30,
                            color: AppTheme.primaryDark,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      size: 30,
                      color: AppTheme.primaryDark,
                    ),
            ),
            const SizedBox(width: 16),
            
            // Info amico
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend['name'] ?? 'Nome Amico',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${friend['username'] ?? 'username'}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.limeAccent,
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottone ZAP con animazioni liquide e vibrazione
            SizedBox(
              width: 120,
              height: 48,
              child: _LiquidZapButton(
                onPressed: () => _zapFriend(friend['id']),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _homeShakeController.dispose();
    super.dispose();
  }
}

class _LiquidZapButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _LiquidZapButton({required this.onPressed});

  @override
  State<_LiquidZapButton> createState() => _LiquidZapButtonState();
}

class _LiquidZapButtonState extends State<_LiquidZapButton>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _rippleController;
  late AnimationController _shakeController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.75,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOutCubic,
    ));

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rippleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    // Trigger haptic feedback
    HapticFeedback.mediumImpact();
    
    // Start animations with delays for better effect
    _scaleController.forward().then((_) => _scaleController.reverse());
    _rippleController.forward().then((_) => _rippleController.reset());
    
    // Shake animation with multiple cycles
    _shakeController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _shakeController.reverse();
      });
    });
    
    // Call the original onPressed
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleController, _rippleController, _shakeController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.translate(
            offset: Offset(
              _shakeAnimation.value * 12 * 
              (1 - _shakeAnimation.value) * 
              (1 - _shakeAnimation.value), 
              0
            ),
            child: Stack(
              children: [
                // Ripple effect
                if (_rippleAnimation.value > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.limeAccent.withOpacity(0.9 * _rippleAnimation.value),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                // Main button
                GestureDetector(
                  onTapDown: (_) => _handleTap(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.limeAccent,
                          AppTheme.limeAccent.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.limeAccent.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'ZAP',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.8,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 