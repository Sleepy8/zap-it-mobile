import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'encryption_service.dart';

class MessagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EncryptionService _encryptionService = EncryptionService();

  // Timer management for auto-destruction
  final Map<String, Timer> _autoDestructionTimers = {};

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get all conversations for current user
  Stream<List<Map<String, dynamic>>> getConversationsStream() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> conversations = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final otherUserId = (data['participants'] as List)
            .firstWhere((id) => id != currentUserId);
        
        // Get other user data
        final userDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final isArchived = data['isArchived']?[currentUserId] ?? false;
          final isBlocked = data['isBlocked']?[currentUserId] ?? false;
          final isDeleted = data['isDeleted']?[currentUserId] ?? false;
          final isMarkedForDeletion = data['markedForDeletion']?[currentUserId] ?? false;
          
          // Get last message - simplified to handle both encrypted and plain text
          String lastMessage = data['lastMessage'] ?? '';
          if (lastMessage.isNotEmpty) {
            try {
              // Try to decrypt if it's encrypted, otherwise use as-is
              if (data['isLastMessageEncrypted'] == true) {
                lastMessage = await _encryptionService.decryptFromDatabase(lastMessage);
              }
              // If decryption fails or returns error message, show original
              if (lastMessage.contains('[Messaggio') || lastMessage.contains('non leggibile')) {
                lastMessage = data['lastMessage'] ?? '';
              }
            } catch (e) {
              lastMessage = data['lastMessage'] ?? '';
            }
          }
          
          // Determine message status for placeholder
          String messageStatus = '';
          if (lastMessage.isNotEmpty) {
            final lastMessageSenderId = data['lastMessageSenderId'] ?? '';
            final isLastMessageRead = data['isLastMessageRead']?[currentUserId] ?? false;
            
            if (lastMessageSenderId == currentUserId) {
              // Current user sent the last message
              messageStatus = 'Messaggio Inviato';
            } else {
              // Other user sent the last message
              if (isLastMessageRead) {
                messageStatus = 'Ricevuto';
              } else {
                messageStatus = 'Nuovo Messaggio';
              }
            }
          } else {
            // No last message - could be because messages were deleted after 10 seconds
            // Check if there was recent activity
            final lastMessageAt = data['lastMessageAt'];
            if (lastMessageAt != null) {
              DateTime messageTime;
              if (lastMessageAt is Timestamp) {
                messageTime = lastMessageAt.toDate();
              } else if (lastMessageAt is DateTime) {
                messageTime = lastMessageAt;
              } else {
                messageTime = DateTime.now();
              }
              
              final now = DateTime.now();
              final elapsedSeconds = now.difference(messageTime).inSeconds;
              
              // If less than 30 seconds have passed since last activity, show appropriate placeholder
              if (elapsedSeconds < 30) {
                final lastMessageSenderId = data['lastMessageSenderId'] ?? '';
                if (lastMessageSenderId == currentUserId) {
                  messageStatus = 'Messaggio Inviato';
                } else {
                  messageStatus = 'Nuovo Messaggio';
                }
              } else {
                messageStatus = 'Chat vuota';
              }
            } else {
              messageStatus = 'Chat vuota';
            }
          }
          
          // Only add conversation if not deleted locally
          if (!isDeleted) {
            conversations.add({
              'conversationId': doc.id,
              'otherUserId': otherUserId,
              'otherUsername': userData['username'] ?? 'Utente',
              'lastMessage': lastMessage,
              'lastMessageAt': data['lastMessageAt'],
              'messageStatus': messageStatus,
              'unreadCount': data['unreadCount']?[currentUserId] ?? 0,
              'isArchived': isArchived,
              'isBlocked': isBlocked,
              'isMarkedForDeletion': isMarkedForDeletion,
            });
          }
        }
      }
      
      return conversations;
    });
  }

  // Get messages stream for a conversation (with auto-destruction filtering)
  Stream<List<Map<String, dynamic>>> getMessagesStream(String conversationId) {
    if (currentUserId == null) return Stream.value([]);

    // Initialize E2EE for this conversation
    _encryptionService.initializeConversationE2EE(conversationId);
    // Set current conversation ID for encryption
    _encryptionService.setCurrentConversationId(conversationId);

    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .asyncMap((conversationDoc) async {
      if (!conversationDoc.exists) {
        return <Map<String, dynamic>>[];
      }
      
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(50)
          .get();
      
      List<Map<String, dynamic>> messages = [];
      
      for (var doc in messagesSnapshot.docs) {
        final data = doc.data();
        
        // Check if message is auto-destroyed by current user
        final autoDestroyedBy = Map<String, bool>.from(data['autoDestroyedBy'] ?? {});
        if (autoDestroyedBy[currentUserId] == true) {
          // Skip this message as it's auto-destroyed by current user
          continue;
        }
        
        // Get message text - simplified to handle both encrypted and plain text
        String messageText = data['text'] ?? '';
        if (messageText.isNotEmpty) {
          try {
            // Try to decrypt if it's encrypted, otherwise use as-is
            if (data['isEncrypted'] == true) {
              messageText = await _encryptionService.decryptFromDatabase(messageText);
            }
            // If decryption fails or returns error message, show original
            if (messageText.contains('[Messaggio') || messageText.contains('non leggibile')) {
              messageText = data['text'] ?? '';
            }
          } catch (e) {
            messageText = data['text'] ?? '';
          }
        }
        
        messages.add({
          'id': doc.id,
          'senderId': data['senderId'],
          'text': messageText,
          'createdAt': data['createdAt'],
          'isRead': data['isRead'] ?? false,
          'isCurrentUser': data['senderId'] == currentUserId,
          'isEncrypted': data['isEncrypted'] ?? false,
        });
      }
      
      return messages;
    });
  }

  // Send a message
  Future<Map<String, dynamic>> sendMessage(String conversationId, String text) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId == null) {
        return {'success': false, 'conversationId': null};
      }

      String? realConversationId = conversationId;
      String? otherUserId;
      Map<String, dynamic>? conversationData;

      // Check if this is a new conversation (conversationId is actually the otherUserId)
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // This is a new conversation - conversationId is actually the otherUserId
        realConversationId = await _createNewConversation(conversationId);
        if (realConversationId == null) {
          return {'success': false, 'conversationId': null};
        }
        otherUserId = conversationId; // The original conversationId was the other user ID
      } else {
        // This is an existing conversation
        conversationData = conversationDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(conversationData['participants']);
        otherUserId = participants.firstWhere((id) => id != currentUserId);
        realConversationId = conversationId;
      }

      // Get conversation data if not already available
      if (conversationData == null) {
        final conversationDoc = await _firestore.collection('conversations').doc(realConversationId).get();
        if (conversationDoc.exists) {
          conversationData = conversationDoc.data() as Map<String, dynamic>;
        }
      }

      // Set current conversation ID for encryption
      _encryptionService.setCurrentConversationId(realConversationId);

      // Encrypt message for database
      final encryptedText = await _encryptionService.encryptForDatabase(text.trim());
      
      final messageData = {
        'senderId': currentUserId,
        'text': encryptedText,
        'isEncrypted': true,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        // Auto-destruction fields for 10-second chat
        'autoDestroyedBy': {}, // Map of user IDs who have auto-destroyed this message
        'isAutoDestroyed': false, // Global flag for complete destruction
        'hardDeleteAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 15))), // TTL max 15 giorni
      };

      // Add message to conversation
      await _firestore
          .collection('conversations')
          .doc(realConversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation with last message info
      final unreadCount = Map<String, int>.from(conversationData?['unreadCount'] ?? {});
      unreadCount[otherUserId] = (unreadCount[otherUserId] ?? 0) + 1;

      // Encrypt last message for conversation preview
      final encryptedLastMessage = await _encryptionService.encryptForDatabase(text.trim());
      
      await _firestore.collection('conversations').doc(realConversationId).update({
        'lastMessage': encryptedLastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'isLastMessageEncrypted': true,
        'lastMessageSenderId': currentUserId,
        'isLastMessageRead': {currentUserId: true, otherUserId: false},
        'unreadCount': unreadCount,
        'markedForDeletion': {currentUserId: false, otherUserId: false},
      });

      return {'success': true, 'conversationId': realConversationId};
    } catch (e) {
      return {'success': false, 'conversationId': null};
    }
  }

  // Create new conversation
  Future<String?> _createNewConversation(String otherUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return null;

      final conversationData = {
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageSenderId': '',
        'isLastMessageRead': {currentUserId: true, otherUserId: true},
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'isArchived': {currentUserId: false, otherUserId: false},
        'isBlocked': {currentUserId: false, otherUserId: false},
        'isDeleted': {currentUserId: false, otherUserId: false},
        'markedForDeletion': {currentUserId: false, otherUserId: false},
      };

      final docRef = await _firestore.collection('conversations').add(conversationData);
      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final unreadCount = Map<String, int>.from(conversationData['unreadCount'] ?? {});
      final isLastMessageRead = Map<String, bool>.from(conversationData['isLastMessageRead'] ?? {});
      
      unreadCount[currentUserId] = 0;
      isLastMessageRead[currentUserId] = true;

      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': unreadCount,
        'isLastMessageRead': isLastMessageRead,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Chat session management
  Future<void> onChatEnter(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Cancel any existing auto-destruction timer for this conversation
      _cancelAutoDestructionTimer(conversationId);

      // Update user session
      await _firestore
          .collection('chatSessions')
          .doc(conversationId)
          .collection('userSessions')
          .doc(currentUserId)
          .set({
        'lastEnterAt': FieldValue.serverTimestamp(),
        'lastExitAt': null,
        'lastPurgeReadyAt': null,
        'openDevices': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      // Silent error handling
    }
  }

  Future<void> onChatExit(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get current session
      final sessionDoc = await _firestore
          .collection('chatSessions')
          .doc(conversationId)
          .collection('userSessions')
          .doc(currentUserId)
          .get();

      if (sessionDoc.exists) {
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        final currentOpenDevices = sessionData['openDevices'] ?? 0;
        final newOpenDevices = (currentOpenDevices - 1).clamp(0, double.infinity).toInt();

        if (newOpenDevices == 0) {
          // Last device closed, schedule auto-destruction
          final now = FieldValue.serverTimestamp();
          final purgeReadyAt = Timestamp.fromDate(DateTime.now().add(Duration(seconds: 10)));

          await _firestore
              .collection('chatSessions')
              .doc(conversationId)
              .collection('userSessions')
              .doc(currentUserId)
              .update({
            'lastExitAt': now,
            'lastPurgeReadyAt': purgeReadyAt,
            'openDevices': newOpenDevices,
          });

          // Schedule auto-destruction after 10 seconds
          _scheduleAutoDestruction(conversationId, currentUserId);
        } else {
          // Still has other devices open
          await _firestore
              .collection('chatSessions')
              .doc(conversationId)
              .collection('userSessions')
              .doc(currentUserId)
              .update({
            'openDevices': newOpenDevices,
          });
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Schedule auto-destruction after 10 seconds
  void _scheduleAutoDestruction(String conversationId, String userId) {
    // Cancel any existing timer for this conversation
    _cancelAutoDestructionTimer(conversationId);
    
    // Create new timer
    final timer = Timer(Duration(seconds: 10), () async {
      try {
        // Check if user has re-entered the chat
        final sessionDoc = await _firestore
            .collection('chatSessions')
            .doc(conversationId)
            .collection('userSessions')
            .doc(userId)
            .get();

        if (sessionDoc.exists) {
          final sessionData = sessionDoc.data() as Map<String, dynamic>;
          final openDevices = sessionData['openDevices'] ?? 0;

          if (openDevices == 0) {
            // User hasn't re-entered, proceed with auto-destruction
            await _autoDestroyMessagesForUser(conversationId, userId);
          }
        }
        
        // Remove timer from map after completion
        _autoDestructionTimers.remove(conversationId);
      } catch (e) {
        _autoDestructionTimers.remove(conversationId);
      }
    });
    
    // Store the timer
    _autoDestructionTimers[conversationId] = timer;
  }

  // Cancel auto-destruction timer for a conversation
  void _cancelAutoDestructionTimer(String conversationId) {
    final timer = _autoDestructionTimers[conversationId];
    if (timer != null) {
      timer.cancel();
      _autoDestructionTimers.remove(conversationId);
    }
  }

  // Auto-destroy messages for a specific user
  Future<void> _autoDestroyMessagesForUser(String conversationId, String userId) async {
    try {
      // Get all messages not yet auto-destroyed by this user
      final messagesQuery = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('isAutoDestroyed', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (var doc in messagesQuery.docs) {
        final messageData = doc.data();
        final autoDestroyedBy = Map<String, bool>.from(messageData['autoDestroyedBy'] ?? {});
        
        // Mark message as auto-destroyed by this user
        autoDestroyedBy[userId] = true;
        
        // Check if all participants have auto-destroyed
        final participants = await _getConversationParticipants(conversationId);
        bool allDestroyed = true;
        
        for (String participantId in participants) {
          if (!autoDestroyedBy.containsKey(participantId) || !autoDestroyedBy[participantId]!) {
            allDestroyed = false;
            break;
          }
        }
        
        if (allDestroyed) {
          // All participants have auto-destroyed, mark for deletion
          batch.update(doc.reference, {
            'isAutoDestroyed': true,
            'autoDestroyedBy': autoDestroyedBy,
          });
        } else {
          // Only mark as auto-destroyed by this user
          batch.update(doc.reference, {
            'autoDestroyedBy': autoDestroyedBy,
          });
        }
        
        updatedCount++;
      }

      await batch.commit();
    } catch (e) {
      // Error handling
    }
  }

  // Get conversation participants
  Future<List<String>> _getConversationParticipants(String conversationId) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (conversationDoc.exists) {
        final data = conversationDoc.data() as Map<String, dynamic>;
        return List<String>.from(data['participants'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Archive conversation
  Future<void> archiveConversation(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isArchived.$currentUserId': true,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Unarchive conversation
  Future<void> unarchiveConversation(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isArchived.$currentUserId': false,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Block conversation
  Future<void> blockConversation(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isBlocked.$currentUserId': true,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Unblock conversation
  Future<void> unblockConversation(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isBlocked.$currentUserId': false,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Delete conversation locally
  Future<bool> deleteConversationLocally(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return false;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isDeleted.$currentUserId': true,
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  // Reset markedForDeletion when user enters chat (cancels timer) - DEPRECATED
  Future<void> resetMarkedForDeletion(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'markedForDeletion.$currentUserId': false,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Get or create conversation between two users
  Future<String?> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return null;

      // First try to get existing conversation
      final query = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      // If no conversation exists, create one
      return await _createNewConversation(otherUserId);
    } catch (e) {
      return null;
    }
  }

  // Initialize E2EE for current user
  Future<bool> initializeE2EE() async {
    try {
      await _encryptionService.generateKeyPair();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Force E2EE initialization
  Future<bool> forceE2EEInitialization() async {
    try {
      await _encryptionService.forceKeyGeneration();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Block user
  Future<void> blockUser(String conversationId, String otherUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isBlocked.$currentUserId': true,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Unblock user
  Future<void> unblockUser(String conversationId, String otherUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isBlocked.$currentUserId': false,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Delete conversation (legacy method - now calls deleteConversationLocally)
  Future<void> deleteConversation(String conversationId) async {
    await deleteConversationLocally(conversationId);
  }

  // Get conversation by ID
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    try {
      final doc = await _firestore.collection('conversations').doc(conversationId).get();
      if (doc.exists) {
        return {'conversationId': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get conversation between two users
  Future<String?> getConversationId(String otherUserId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return null;

      final query = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants']);
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Restore deleted conversation
  Future<void> restoreConversation(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await _firestore.collection('conversations').doc(conversationId).update({
        'isDeleted.$currentUserId': false,
      });
    } catch (e) {
      // Silent error handling
    }
  }

  // Dispose method to clean up timers
  void dispose() {
    // Cancel all active timers
    for (final timer in _autoDestructionTimers.values) {
      timer.cancel();
    }
    _autoDestructionTimers.clear();
  }
}
