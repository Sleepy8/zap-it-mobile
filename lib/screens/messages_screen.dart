import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messages_service.dart';
import '../services/friends_service.dart';
import '../theme.dart';
import '../widgets/profile_picture.dart';
import '../widgets/online_status_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _messagesService = MessagesService();
  final _friendsService = FriendsService();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Force refresh when returning to this screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh if we're actually returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }

  // Force immediate refresh of conversations
  void _refreshConversations() {
    setState(() {
      _conversations = _allConversations.where((conv) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        bool isArchived = false;
        bool isBlocked = false;
        bool isLocallyDeleted = false;
        
        if (currentUserId != null) {
          // Handle both old format (bool) and new format (Map)
          final archivedValue = conv['isArchived'];
          final blockedValue = conv['isBlocked'];
          
          if (archivedValue is Map<String, dynamic>) {
            isArchived = archivedValue[currentUserId] ?? false;
          } else if (archivedValue is bool) {
            isArchived = archivedValue;
          }
          
          if (blockedValue is Map<String, dynamic>) {
            isBlocked = blockedValue[currentUserId] ?? false;
          } else if (blockedValue is bool) {
            isBlocked = blockedValue;
          }
          
          // Check if current user has deleted this conversation locally
          final localDeletion = List<String>.from(conv['localDeletion'] ?? []);
          isLocallyDeleted = localDeletion.contains(currentUserId);
        }
        
        // Don't show conversations that are locally deleted
        if (isLocallyDeleted) {
          return false;
        }
        
        if (_showArchived) {
          return isArchived && !isBlocked;
        } else {
          return !isArchived && !isBlocked;
        }
      }).toList();
    });
  }

  StreamSubscription? _conversationsSubscription;
  List<Map<String, dynamic>> _allConversations = [];

  void _loadData() {
    // Cancel previous subscription
    _conversationsSubscription?.cancel();
    
    _conversationsSubscription = _messagesService.getConversationsStream().listen((conversations) {
      if (mounted) {
        setState(() {
          _allConversations = conversations;
          _conversations = conversations.where((conv) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final isArchived = conv['isArchived'] ?? false;
            final isBlocked = conv['isBlocked'] ?? false;
            
            // Check if current user has deleted this conversation locally
            bool isLocallyDeleted = false;
            if (currentUserId != null) {
              final localDeletion = List<String>.from(conv['localDeletion'] ?? []);
              isLocallyDeleted = localDeletion.contains(currentUserId);
            }
            
            // Don't show conversations that are locally deleted
            if (isLocallyDeleted) {
              return false;
            }
            
            if (_showArchived) {
              // Show only archived conversations (not blocked)
              return isArchived && !isBlocked;
            } else {
              // Show active conversations (not archived, not blocked)
              return !isArchived && !isBlocked;
            }
          }).toList();
          
          _isLoading = false;
        });
      }
    });

    _friendsService.getFriendsStream().listen((friends) {
      if (mounted) {
        setState(() {
          _friends = friends;
        });
      }
    });

    // Set loading to false after a timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Force refresh conversations
  void _forceRefreshConversations() {
    _loadData();
  }

  // Helper methods to check conversation status for current user
  bool _getConversationArchivedStatus(Map<String, dynamic> conversation) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    
    final archivedValue = conversation['isArchived'];
    if (archivedValue is Map<String, dynamic>) {
      return archivedValue[currentUserId] ?? false;
    } else if (archivedValue is bool) {
      return archivedValue;
    }
    return false;
  }

  bool _getConversationBlockedStatus(Map<String, dynamic> conversation) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;
    
    final blockedValue = conversation['isBlocked'];
    if (blockedValue is Map<String, dynamic>) {
      return blockedValue[currentUserId] ?? false;
    } else if (blockedValue is bool) {
      return blockedValue;
    }
    return false;
  }

  void _showNewMessageDialog() {
    if (_friends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non hai ancora amici. Aggiungi amici per iniziare a chattare!'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

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
            Text(
              'Seleziona Amico',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, index) {
                  final friend = _friends[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.limeAccent.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.limeAccent.withOpacity(0.2),
                        child: Text(
                          (friend['username'] as String).substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.limeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        friend['username'],
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        friend['name'] ?? '',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppTheme.limeAccent,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _startConversation(friend);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startConversation(Map<String, dynamic> friend) async {
    // Don't create conversation immediately, just pass the friend ID
    // The conversation will be created when the first message is sent
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: '', // empty string means new conversation
            otherUserId: friend['id'],
            otherUsername: friend['username'],
          ),
        ),
      ).then((_) {
        // Force refresh when returning from chat
        if (mounted) {
          _loadData();
        }
      });
    }
  }

  void _showConversationOptions(Map<String, dynamic> conversation) {
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
            ListTile(
              leading: Icon(
                _getConversationArchivedStatus(conversation) ? Icons.unarchive : Icons.archive,
                color: AppTheme.limeAccent,
              ),
              title: Text(
                _getConversationArchivedStatus(conversation) ? 'Ripristina' : 'Archivia',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  if (_getConversationArchivedStatus(conversation)) {
                    await _messagesService.unarchiveConversation(conversation['conversationId']);
                    if (mounted) {
                      // Update local conversation immediately
                      final index = _allConversations.indexWhere((conv) => conv['conversationId'] == conversation['conversationId']);
                      if (index != -1) {
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        if (currentUserId != null) {
                          _allConversations[index]['isArchived'] = {currentUserId: false};
                        }
                        _refreshConversations();
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Chat con @${conversation['otherUsername']} ripristinata'),
                          backgroundColor: AppTheme.limeAccent,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else {
                    await _messagesService.archiveConversation(conversation['conversationId']);
                    if (mounted) {
                      // Update local conversation immediately
                      final index = _allConversations.indexWhere((conv) => conv['conversationId'] == conversation['conversationId']);
                      if (index != -1) {
                        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                        if (currentUserId != null) {
                          _allConversations[index]['isArchived'] = {currentUserId: true};
                        }
                        _refreshConversations();
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Chat con @${conversation['otherUsername']} archiviata'),
                          backgroundColor: AppTheme.limeAccent,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(
                _getConversationBlockedStatus(conversation) ? Icons.block : Icons.block,
                color: AppTheme.errorColor,
              ),
              title: Text(
                _getConversationBlockedStatus(conversation) ? 'Sblocca' : 'Blocca',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                if (_getConversationBlockedStatus(conversation)) {
                  _messagesService.unblockUser(
                    conversation['conversationId'],
                    conversation['otherUserId'],
                  );
                } else {
                  _showBlockConfirmation(conversation);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: AppTheme.errorColor,
              ),
              title: Text(
                'Elimina Chat',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(conversation);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(Map<String, dynamic> conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Blocca Utente',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Sei sicuro di voler bloccare @${conversation['otherUsername']}? Non potrai più ricevere messaggi da questo utente.',
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
              _messagesService.blockUser(
                conversation['conversationId'],
                conversation['otherUserId'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text(
              'Blocca',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showChatOptions(Map<String, dynamic> conversation) {
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
            Text(
              'Opzioni Chat',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.archive,
                  color: AppTheme.warningColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Archivia',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Sposta nelle archiviate',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await _messagesService.archiveConversation(conversation['conversationId']);
                  if (mounted) {
                    _refreshConversations();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chat archiviata'),
                        backgroundColor: AppTheme.limeAccent,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore nell\'archiviare la chat: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(color: AppTheme.textSecondary, height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              title: Text(
                'Elimina',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Elimina localmente (se entrambi eliminano, si cancella dal DB)',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final success = await _messagesService.deleteConversationLocally(conversation['conversationId']);
                  if (mounted && success) {
                    _refreshConversations();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chat eliminata'),
                        backgroundColor: AppTheme.limeAccent,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore nell\'eliminare la chat: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Annulla',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}g fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h fa';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m fa';
    } else {
      return 'Ora';
    }
  }

  // Sposto qui la funzione
  void _showDeleteConfirmation([Map<String, dynamic>? conversation]) {
    final username = conversation?['otherUsername'] ?? '';
    final conversationId = conversation?['conversationId'];
    
    // If no conversation exists, show a message
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessuna conversazione da eliminare'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Elimina chat con @$username?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'La chat verrà eliminata solo per te. Se anche l\'altro utente elimina la chat, allora verrà cancellata definitivamente dal database.',
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                final success = await _messagesService.deleteConversationLocally(conversationId);
                if (mounted) {
                  // Aggiorna la lista delle conversazioni
                  _refreshConversations();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chat con @$username eliminata'),
                        backgroundColor: AppTheme.limeAccent,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore nell\'eliminare la chat'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                  await Future.delayed(const Duration(milliseconds: 300));
                  Navigator.pop(context); // Go back to messages screen
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore nell\'archiviare la chat: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text(
              'Elimina',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      appBar: AppBar(
        title: const Text('Messaggi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: () => Navigator.pushNamed(context, '/e2ee-setup'),
            tooltip: 'Sicurezza E2EE',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showArchived = false;
                        });
                        _loadData(); // Force reload
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_showArchived ? AppTheme.limeAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Chat Attive',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_showArchived ? AppTheme.primaryDark : AppTheme.textSecondary,
                            fontWeight: !_showArchived ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showArchived = true;
                        });
                        _loadData(); // Force reload
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _showArchived ? AppTheme.limeAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Archiviate',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _showArchived ? AppTheme.primaryDark : AppTheme.textSecondary,
                            fontWeight: _showArchived ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Conversations list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                      ),
                    )
                  : _conversations.isEmpty
                      ? Center(
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
                                child: Icon(
                                  _showArchived ? Icons.archive : Icons.chat_bubble_outline,
                                  size: 60,
                                  color: AppTheme.limeAccent,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _showArchived ? 'Nessuna chat archiviata' : 'Nessuna conversazione',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _showArchived 
                                    ? 'Le chat archiviate appariranno qui'
                                    : 'Inizia una conversazione con i tuoi amici!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final conversation = _conversations[index];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(16),
                                border: conversation['unreadCount'] > 0
                                    ? Border.all(color: AppTheme.limeAccent, width: 1)
                                    : null,
                              ),
                              child: ListTile(
                                leading: Stack(
                                  children: [
                                    ProfilePicture(
                                      userId: conversation['otherUserId'],
                                      size: 48,
                                      showBorder: conversation['unreadCount'] > 0,
                                      borderColor: conversation['unreadCount'] > 0 
                                          ? AppTheme.limeAccent 
                                          : null,
                                    ),
                                    if (conversation['unreadCount'] > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.limeAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            '${conversation['unreadCount']}',
                                            style: TextStyle(
                                              color: AppTheme.primaryDark,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      conversation['otherUsername'],
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: conversation['unreadCount'] > 0 
                                            ? FontWeight.bold 
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        OnlineStatusIndicator(
                                          userId: conversation['otherUserId'],
                                          size: 8,
                                        ),
                                        const SizedBox(width: 4),
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(conversation['otherUserId'])
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
                                                  fontSize: 10,
                                                  color: AppTheme.limeAccent,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              );
                                            } else if (lastSeen != null && showLastSeen) {
                                              final now = DateTime.now();
                                              final difference = now.difference(lastSeen.toDate());
                                              
                                              String statusText;
                                              if (difference.inMinutes < 1) {
                                                statusText = 'ora';
                                              } else if (difference.inMinutes < 60) {
                                                statusText = '${difference.inMinutes}m fa';
                                              } else if (difference.inHours < 24) {
                                                statusText = '${difference.inHours}h fa';
                                              } else {
                                                statusText = '${difference.inDays}g fa';
                                              }
                                              
                                              return Text(
                                                statusText,
                                                style: TextStyle(
                                                  fontSize: 10,
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
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      _getMessagePreview(conversation),
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: conversation['unreadCount'] > 0 
                                            ? FontWeight.w500 
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimestamp(conversation['lastMessageAt']),
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () => _showConversationOptions(conversation),
                                  color: AppTheme.textSecondary,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        conversationId: conversation['conversationId'],
                                        otherUserId: conversation['otherUserId'],
                                        otherUsername: conversation['otherUsername'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "messages_fab",  // Tag unico per questo FAB
        onPressed: _showNewMessageDialog,
        backgroundColor: AppTheme.limeAccent,
        child: const Icon(
          Icons.edit,
          color: AppTheme.primaryDark,
        ),
      ),
    );
  }

  String _getMessagePreview(Map<String, dynamic> conversation) {
    final unreadCount = conversation['unreadCount'] ?? 0;
    final lastMessage = conversation['lastMessage'] ?? '';
    final lastMessageAt = conversation['lastMessageAt'];
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final markedForDeletion = conversation['markedForDeletion'] as Map<String, dynamic>? ?? {};
    
    // Check if current user has deleted this conversation locally
    if (currentUserId != null && markedForDeletion[currentUserId] == true) {
      return 'Nessun messaggio';
    }
    
    // Use the messageStatus from the service if available (this handles the 10-second logic)
    final messageStatus = conversation['messageStatus'] ?? '';
    if (messageStatus.isNotEmpty) {
      return messageStatus;
    }
    
    // Fallback logic if messageStatus is not available
    final lastMessageSenderId = conversation['lastMessageSenderId'];
    bool isSender = currentUserId != null && lastMessageSenderId == currentUserId;
    
    if (unreadCount > 0) {
      return 'Nuovo messaggio';
    } else if (lastMessage.isNotEmpty) {
      if (isSender) {
        return 'Messaggio inviato';
      } else {
        return 'Ricevuto';
      }
    } else {
      return 'Nessun messaggio';
    }
  }
}

// Chat screen implementation moved to chat_screen.dart 