import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../services/messages_service.dart';
import '../services/encryption_service.dart';
import '../widgets/profile_picture.dart';
import '../widgets/zap_success_toast.dart';
import '../widgets/online_status_indicator.dart';
import '../theme.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUsername;

  const ChatScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessagesService _messagesService = MessagesService();
  final EncryptionService _encryptionService = EncryptionService();
  
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  
  // 10 seconds chat variables
  String? _currentConversationId; // Track the actual conversation ID (for new conversations)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentConversationId = widget.conversationId.isEmpty ? null : widget.conversationId;
    _startListeningToMessages();
    
    // Mark user as entered chat
    if (_currentConversationId != null && _currentConversationId!.isNotEmpty) {
      _messagesService.onChatEnter(_currentConversationId!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final conversationId = _currentConversationId ?? widget.conversationId;
    if (conversationId.isEmpty) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is going to background or being closed
        _messagesService.onChatExit(conversationId);
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        _messagesService.onChatEnter(conversationId);
        break;
      case AppLifecycleState.hidden:
        // App is hidden (iOS specific)
        _messagesService.onChatExit(conversationId);
        break;
    }
  }


  void _startListeningToMessages() {
    // For new conversations (empty conversationId), we don't listen to messages initially
    // Messages will be loaded after the first message is sent and conversation is created
    if (_currentConversationId != null && _currentConversationId!.isNotEmpty) {
      _messagesSubscription = _messagesService
          .getMessagesStream(_currentConversationId!)
          .listen((messages) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Mark messages as read when they appear
        _markMessagesAsRead();
        
        // Scroll to bottom when new message arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      });
    } else {
      setState(() {
        _isLoading = false;
        _messages = []; // Empty messages for new conversation
      });
    }
  }

  void _markMessagesAsRead() {
    final conversationId = _currentConversationId ?? widget.conversationId;
    
    // Don't mark messages as read for new conversations
    if (conversationId.isEmpty) return;
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    bool hasUnreadMessages = false;
    
    for (var message in _messages) {
      final senderId = message['senderId'] as String;
      final isRead = message['isRead'] ?? false;
      
      // Check if there are unread messages from other users
      if (senderId != currentUserId && !isRead) {
        hasUnreadMessages = true;
      }
    }
    
    // If user has read messages, mark as read
    if (hasUnreadMessages) {
      // Mark messages as read in the database
      _messagesService.markMessagesAsRead(conversationId);
    }
  }



  Future<void> _resetMarkedForDeletion() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final conversationId = _currentConversationId ?? widget.conversationId;
      if (conversationId.isEmpty) return;

      // Reset markedForDeletion for current user when entering chat
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        'markedForDeletion.$currentUserId': false,
      });
      
      // Don't cancel timers when entering chat - they should only be cancelled when leaving
      

    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      // If conversationId is empty, use otherUserId to create new conversation
      final conversationId = widget.conversationId.isEmpty ? widget.otherUserId : widget.conversationId;
      
      final result = await _messagesService.sendMessage(
        conversationId,
        messageText,
      );

      // If this was a new conversation and it was created successfully
      if (widget.conversationId.isEmpty && result['success'] == true && result['conversationId'] != null) {
        // Update the conversation ID and start listening to messages
        final newConversationId = result['conversationId'] as String;
        _currentConversationId = newConversationId;
        
        // Cancel current subscription if any
        _messagesSubscription?.cancel();
        
        // Start listening to the new conversation
        _messagesSubscription = _messagesService
            .getMessagesStream(newConversationId)
            .listen((messages) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
          
          // Mark messages as read when they appear
          _markMessagesAsRead();
          
          // Scroll to bottom when new message arrives
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        });
      }

      // Message sent successfully - no notification needed
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }



  Future<void> _blockUser() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block ${widget.otherUsername}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final conversationId = _currentConversationId ?? widget.conversationId;
        if (conversationId.isNotEmpty) {
          await _messagesService.blockUser(conversationId, widget.otherUserId);
        }
        showZapSuccessToast(
          context,
          message: 'User blocked successfully',
        );
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block user: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    
    // Mark user as exited chat
    final conversationId = _currentConversationId ?? widget.conversationId;
    if (conversationId.isNotEmpty) {
      _messagesService.onChatExit(conversationId);
    }
    
    // Dispose the messages service to clean up timers
    _messagesService.dispose();
    
    super.dispose();
  }

  @override
  void deactivate() {
    // This is called when the widget is removed from the widget tree
    final conversationId = _currentConversationId ?? widget.conversationId;
    if (conversationId.isNotEmpty) {
      _messagesService.onChatExit(conversationId);
    }
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ProfilePicture(
              userId: widget.otherUserId,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/user-profile',
                    arguments: {
                      'userId': widget.otherUserId,
                      'username': widget.otherUsername,
                    },
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUsername,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        OnlineStatusIndicator(
                          userId: widget.otherUserId,
                          size: 8,
                        ),
                        const SizedBox(width: 4),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.otherUserId)
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
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.limeAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '10s',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'block':
                  _blockUser();
                  break;
                case 'delete':
                  _showDeleteDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('Block User'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('Delete Conversation'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner informativo per i messaggi temporanei
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.limeAccent.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: AppTheme.limeAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'I messaggi si eliminano automaticamente 10 secondi dopo aver lasciato la chat',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.limeAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.limeAccent),
                  ))
                : _messages.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: AppTheme.textSecondary,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nessun messaggio.\nInizia la conversazione!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isMe = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                            
                            return _buildMessageBubble(message, isMe);
                          },
                        ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.limeAccent : AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message['text'] ?? 'Error',
                  style: TextStyle(
                    color: isMe ? AppTheme.primaryDark : AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.timer,
                  size: 14,
                  color: isMe ? AppTheme.primaryDark.withOpacity(0.7) : AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message['createdAt']),
              style: TextStyle(
                color: isMe ? AppTheme.primaryDark.withOpacity(0.7) : AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: AppTheme.textSecondary.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Scrivi un messaggio (si elimina in 10s)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(25)),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            backgroundColor: AppTheme.limeAccent,
            child: const Icon(Icons.send, color: AppTheme.primaryDark),
            mini: true,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final conversationId = _currentConversationId ?? widget.conversationId;
                if (conversationId.isNotEmpty) {
                  await _messagesService.deleteConversation(conversationId);
                }
                showZapSuccessToast(
                  context,
                  message: 'Conversation deleted',
                );
                Navigator.of(context).pop(); // Return to messages screen
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete conversation: $e'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
          ),
        ],
      ),
    );
  }
}
