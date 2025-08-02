import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/messages_service.dart';
import '../services/friends_service.dart';
import '../theme.dart';
import '../widgets/profile_picture.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            // MessagesService already processes isArchived and isBlocked correctly
            // Just filter based on the processed values
            final isArchived = conv['isArchived'] ?? false;
            final isBlocked = conv['isBlocked'] ?? false;
            
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
    final conversationId = await _messagesService.getOrCreateConversation(friend['id']);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversationId, // Can be null for new conversations
            otherUser: friend,
            onConversationDeleted: () {
              // Force refresh when conversation is deleted
              _loadData();
            },
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Blocca'),
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
                  final success = await _messagesService.archiveConversation(conversation['conversationId']);
                  if (mounted && success) {
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
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
        title: const Text('💬 Messaggi'),
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
                                title: Text(
                                  conversation['otherUsername'],
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: conversation['unreadCount'] > 0 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      conversation['lastMessage'] ?? 'Nessun messaggio',
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
                                        otherUser: {
                                          'id': conversation['otherUserId'],
                                          'username': conversation['otherUsername'],
                                        },
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
}

// Chat screen will be implemented next
class ChatScreen extends StatefulWidget {
  final String? conversationId; // Can be null for new conversations
  final Map<String, dynamic> otherUser;
  final VoidCallback? onConversationDeleted;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUser,
    this.onConversationDeleted,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messagesService = MessagesService();
  final _textController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  void _loadMessages() {
    if (widget.conversationId != null) {
      _messagesService.getMessagesStream(widget.conversationId!).listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages.reversed.toList(); // Show oldest first
            _isLoading = false;
          });
        }
      });
    } else {
      // New conversation, no messages to load
      setState(() {
        _messages = [];
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Mark messages as read immediately when opening chat (only if conversation exists)
    if (widget.conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messagesService.markMessagesAsRead(widget.conversationId!);
        // Force refresh of conversations list to update unread counts
        setState(() {});
      });
    }
  }

  Future<void> _sendMessage([String? value]) async {
    final text = (value ?? _textController.text).trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() {}); // Update send button state
    final conversationId = widget.conversationId ?? widget.otherUser['id'];
    final success = await _messagesService.sendMessage(conversationId, text);
    if (success && mounted) {
      setState(() {
        _messages.add({
          'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
          'senderId': FirebaseAuth.instance.currentUser!.uid,
          'text': text,
          'createdAt': Timestamp.now(),
          'isRead': false,
          'isCurrentUser': true,
          'isEncrypted': true, // o false se non usi E2EE
        });
      });
    }
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore nell\'invio del messaggio'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';
    
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showChatOptions() {
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
              leading: const Icon(
                Icons.person,
                color: AppTheme.limeAccent,
              ),
              title: Text(
                'Profilo di @${widget.otherUser['username']}',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/user-profile',
                  arguments: {
                    'userId': widget.otherUser['id'],
                    'username': widget.otherUser['username'],
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.notifications_off,
                color: AppTheme.limeAccent,
              ),
              title: Text(
                'Silenzia notifiche',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement mute notifications
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.block,
                color: AppTheme.errorColor,
              ),
              title: Text(
                'Blocca utente',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              onTap: () {
                Navigator.pop(context);
                _showBlockConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: AppTheme.errorColor,
              ),
              title: Text(
                'Archivia chat',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
          ],
        ),
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
          'Blocca @${widget.otherUser['username']}?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Non potrai più ricevere messaggi da questo utente. Puoi sbloccare in qualsiasi momento dalle impostazioni.',
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
                if (widget.conversationId != null) {
                  await _messagesService.blockUser(widget.conversationId!, widget.otherUser['id']);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('@${widget.otherUser['username']} bloccato'),
                      backgroundColor: AppTheme.limeAccent,
                    ),
                  );
                  Navigator.pop(context); // Go back to messages screen
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Errore nel bloccare l\'utente: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Blocca'),
          ),
        ],
      ),
    );
  }

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
                  // Torna indietro alla lista delle conversazioni
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
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
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
        title: Row(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.otherUser['id'])
                  .get(),
              builder: (context, snapshot) {
                String? profileImageUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  profileImageUrl = userData['profileImageUrl'];
                }
                
                return CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.limeAccent.withOpacity(0.2),
                  backgroundImage: profileImageUrl != null 
                      ? NetworkImage(profileImageUrl)
                      : null,
                  child: profileImageUrl == null
                      ? Text(
                (widget.otherUser['username'] as String).substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: AppTheme.limeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                    '@${widget.otherUser['username']}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      ),
                    ),
                        Text(
                    'Online',
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
            // Force refresh when going back to update unread counts
            setState(() {});
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showChatOptions,
            tooltip: 'Opzioni chat',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppTheme.limeAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                    color: AppTheme.limeAccent.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 40,
                                  color: AppTheme.limeAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nessun messaggio',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Inizia la conversazione!',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20), // Increased padding
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isCurrentUser = message['isCurrentUser'];
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16), // Increased margin
                              child: Row(
                                mainAxisAlignment: isCurrentUser 
                                    ? MainAxisAlignment.end 
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isCurrentUser) ...[
                                    ProfilePicture(
                                      userId: widget.otherUser['id'],
                                      size: 32,
                                      showBorder: false,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18, // Increased horizontal padding
                                        vertical: 12, // Increased vertical padding
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCurrentUser 
                                            ? AppTheme.limeAccent 
                                            : AppTheme.surfaceDark,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message['text'],
                                            style: TextStyle(
                                              color: isCurrentUser 
                                                  ? AppTheme.primaryDark 
                                                  : AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatMessageTime(message['createdAt']),
                                            style: TextStyle(
                                              color: isCurrentUser 
                                                  ? AppTheme.primaryDark.withOpacity(0.7)
                                                  : AppTheme.textSecondary,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    const SizedBox(width: 8),
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.limeAccent.withOpacity(0.2),
                                      child: const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: AppTheme.limeAccent,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
            // Message input
            Container(
              padding: const EdgeInsets.all(20), // Increased padding
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                border: Border(
                  top: BorderSide(
                    color: AppTheme.limeAccent.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: AppTheme.limeAccent.withOpacity(0.5),
                          width: 1.5, // Single clean border
                        ),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Scrivi un messaggio...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, // Restored horizontal padding
                            vertical: 12, // Restored vertical padding
                          ),
                        ),
                        onSubmitted: (value) => _sendMessage(value),
                        onChanged: (value) {
                          // Enable/disable send button based on text
                          setState(() {});
                        },
                        textInputAction: TextInputAction.send,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        minLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16), // Increased spacing
                  GestureDetector(
                    onTap: _textController.text.trim().isNotEmpty ? () => _sendMessage() : null,
                    child: Container(
                      width: 52, // Increased size
                      height: 52, // Increased size
                      decoration: BoxDecoration(
                        color: _textController.text.trim().isNotEmpty 
                            ? AppTheme.limeAccent 
                            : AppTheme.limeAccent.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        color: _textController.text.trim().isNotEmpty 
                            ? AppTheme.primaryDark 
                            : AppTheme.textSecondary,
                        size: 22, // Increased icon size
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
} 