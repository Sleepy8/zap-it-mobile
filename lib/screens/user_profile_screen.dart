import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../services/messages_service.dart';
import '../services/friends_service.dart';
import '../widgets/online_status_indicator.dart';
import 'messages_screen.dart';
import 'chat_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'edit_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String _friendshipStatus = 'none';
  bool _isBlocked = false;
  final _friendsService = FriendsService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkFriendshipStatus();
    _checkBlockStatus();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists) {
        setState(() {
          _userData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _userData = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _userData = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFriendshipStatus() async {
    final status = await _friendsService.getFriendshipStatus(widget.userId);
    setState(() {
      _friendshipStatus = status;
    });
  }

  Future<void> _checkBlockStatus() async {
    final isBlocked = await _friendsService.isUserBlocked(widget.userId);
    setState(() {
      _isBlocked = isBlocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: Text('@${widget.username}'),
        backgroundColor: AppTheme.surfaceDark,
        titleTextStyle: TextStyle(color: AppTheme.textPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showProfileOptions(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.limeAccent,
              ),
            )
          : _userData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_off,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Utente non trovato',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Header con avatar e nome
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppTheme.limeAccent.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.limeAccent,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  widget.username.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.limeAccent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Column(
                              children: [
                                Text(
                                  '@${widget.username}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    OnlineStatusIndicator(
                                      userId: widget.userId,
                                      size: 10,
                                    ),
                                    const SizedBox(width: 6),
                                    StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(widget.userId)
                                          .snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) return const SizedBox.shrink();
                                        
                                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                        if (userData == null) return const SizedBox.shrink();
                                        
                                        final showOnlineStatus = userData['showOnlineStatus'] ?? true;
                                        final showLastSeen = userData['showLastSeen'] ?? true;
                                        
                                        if (!showOnlineStatus && !showLastSeen) {
                                          return const SizedBox.shrink();
                                        }
                                        
                                        final isOnline = userData['isOnline'] ?? false;
                                        final lastSeen = userData['lastSeen'] as Timestamp?;
                                        
                                        if (isOnline && showOnlineStatus) {
                                          return Text(
                                            'Online',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.limeAccent,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        } else if (lastSeen != null && showLastSeen) {
                                          final now = DateTime.now();
                                          final difference = now.difference(lastSeen.toDate());
                                          
                                          String statusText;
                                          if (difference.inMinutes < 1) {
                                            statusText = 'Ultimo accesso: ora';
                                          } else if (difference.inMinutes < 60) {
                                            statusText = 'Ultimo accesso: ${difference.inMinutes}m fa';
                                          } else if (difference.inHours < 24) {
                                            statusText = 'Ultimo accesso: ${difference.inHours}h fa';
                                          } else {
                                            statusText = 'Ultimo accesso: ${difference.inDays}g fa';
                                          }
                                          
                                          return Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          );
                                        }
                                        
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_userData!['name'] != null)
                              Text(
                                _userData!['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Statistiche
                      Text(
                        'Statistiche',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Grid delle statistiche
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.0,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        children: [
                          _buildStatCard(
                            'ZAP Inviati',
                            '${_userData!['zapsSent'] ?? 0}',
                            Icons.send,
                            AppTheme.limeAccent,
                          ),
                          _buildStatCard(
                            'ZAP Ricevuti',
                            '${_userData!['zapsReceived'] ?? 0}',
                            Icons.favorite,
                            Colors.red,
                          ),
                          _buildStatCard(
                            'Streak',
                            '${_calculateStreak(_userData!)}',
                            Icons.local_fire_department,
                            Colors.orange,
                          ),
                          _buildStatCard(
                            'Membro dal',
                            _formatDate(_userData!['created_at']),
                            Icons.calendar_today,
                            AppTheme.limeAccent,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Informazioni aggiuntive
                      if (_userData!['e2eeEnabled'] == true)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.limeAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.limeAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.security,
                                color: AppTheme.limeAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Crittografia E2EE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.limeAccent,
                                      ),
                                    ),
                                    Text(
                                      'I messaggi sono protetti con crittografia end-to-end',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Bottone Chat
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: ElevatedButton(
                          onPressed: () => _startChat(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.limeAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '💬 Inizia Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  int _calculateStreak(Map<String, dynamic> userData) {
    // Implementazione semplificata dello streak
    // In una versione reale, calcoleresti basandoti sui ZAP consecutivi
    final zapsReceived = userData['zapsReceived'] ?? 0;
    if (zapsReceived == 0) return 0;
    if (zapsReceived < 5) return 1;
    if (zapsReceived < 10) return 2;
    if (zapsReceived < 20) return 3;
    if (zapsReceived < 50) return 4;
    return 5; // Max streak
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      final date = timestamp is Timestamp 
          ? timestamp.toDate() 
          : DateTime.parse(timestamp.toString());
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _startChat() async {
    try {
      // Import MessagesService
      final messagesService = MessagesService();
      
      // Get or create conversation with this user
      final conversationId = await messagesService.getOrCreateConversation(widget.userId);
      
      if (conversationId != null && mounted) {
        // Navigate directly to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUserId: widget.userId,
              otherUsername: widget.username,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nell\'avvio della chat'),
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

  void _sendZap() {
    // TODO: Implement ZAP sending
    // RIMOSSO: feedback locale duplicato
  }

  void _showProfileOptions() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUserId == widget.userId;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Opzioni per il proprio profilo
            if (isOwnProfile) ...[
              ListTile(
                leading: const Icon(
                  Icons.edit,
                  color: AppTheme.limeAccent,
                ),
                title: Text(
                  'Modifica Profilo',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/edit-profile');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.privacy_tip,
                  color: AppTheme.limeAccent,
                ),
                title: Text(
                  'Privacy',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/privacy-settings');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.notifications,
                  color: AppTheme.limeAccent,
                ),
                title: Text(
                  'Notifiche',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notification-settings');
                },
              ),
              const Divider(color: AppTheme.textSecondary),
            ],
            
            // Opzioni per tutti i profili (se non bloccato)
            if (!_isBlocked) ...[
              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppTheme.limeAccent,
                ),
                title: Text(
                  'Inizia Chat',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _startChat();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.send,
                  color: AppTheme.limeAccent,
                ),
                title: Text(
                  'Invia ZAP',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sendZap();
                },
              ),
            ],
            
            // Opzioni per profili di altri utenti
            if (!isOwnProfile) ...[
              if (_friendshipStatus == 'accepted') ...[
                ListTile(
                  leading: const Icon(
                    Icons.person_remove,
                    color: AppTheme.errorColor,
                  ),
                  title: Text(
                    'Rimuovi Amico',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRemoveFriendConfirmation();
                  },
                ),
              ],
              if (!_isBlocked) ...[
                ListTile(
                  leading: const Icon(
                    Icons.block,
                    color: AppTheme.errorColor,
                  ),
                  title: Text(
                    'Blocca Utente',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showBlockConfirmation();
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(
                    Icons.block,
                    color: AppTheme.limeAccent,
                  ),
                  title: Text(
                    'Sblocca Utente',
                    style: TextStyle(color: AppTheme.limeAccent),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showUnblockConfirmation();
                  },
                ),
              ],
              ListTile(
                leading: const Icon(
                  Icons.report,
                  color: AppTheme.errorColor,
                ),
                title: Text(
                  'Segnala Utente',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRemoveFriendConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Rimuovi @${widget.username}?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Sei sicuro di voler rimuovere @${widget.username} dai tuoi amici?',
          style: TextStyle(color: AppTheme.textSecondary),
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
              _removeFriend();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Blocca @${widget.username}?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Non potrai più vedere questo utente o ricevere messaggi da lui. Verrà anche rimosso dai tuoi amici.',
          style: TextStyle(color: AppTheme.textSecondary),
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
              _blockUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Blocca'),
          ),
        ],
      ),
    );
  }

  void _showUnblockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sblocca @${widget.username}?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Vuoi davvero sbloccare @${widget.username}?',
          style: TextStyle(color: AppTheme.textSecondary),
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
              _unblockUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.limeAccent,
            ),
            child: const Text('Sblocca'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFriend() async {
    try {
      final success = await _friendsService.removeFriendship(widget.userId);
      if (success) {
        setState(() {
          _friendshipStatus = 'none';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${widget.username} rimosso dagli amici'),
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

  Future<void> _blockUser() async {
    try {
      final success = await _friendsService.blockUser(widget.userId);
      if (success) {
        setState(() {
          _isBlocked = true;
          _friendshipStatus = 'none';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${widget.username} bloccato'),
            backgroundColor: AppTheme.limeAccent,
          ),
        );
        // Torna alla schermata precedente
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel blocco dell\'utente'),
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

  Future<void> _unblockUser() async {
    try {
      final success = await _friendsService.unblockUser(widget.userId);
      if (success) {
        setState(() {
          _isBlocked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@${widget.username} sbloccato'),
            backgroundColor: AppTheme.limeAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nello sblocco dell\'utente'),
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

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Segnala @${widget.username}',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Seleziona il motivo della segnalazione.',
          style: TextStyle(color: AppTheme.textSecondary),
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
              // TODO: Implement report user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Utente segnalato'),
                  backgroundColor: AppTheme.limeAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text(
              'Segnala',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
} 