import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'encryption_service.dart';
import '../widgets/zap_notification.dart';

class MessagesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EncryptionService _encryptionService = EncryptionService();

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
          
          // Decrypt last message if it's encrypted
          String lastMessage = data['lastMessage'] ?? '';
          if (data['isLastMessageEncrypted'] == true) {
            try {
              lastMessage = await _encryptionService.decryptFromDatabase(lastMessage);
              
            } catch (e) {
              
              lastMessage = '[Messaggio crittografato]';
            }
          }
          
          // Only add conversation if not deleted locally
          if (!isDeleted) {
            conversations.add({
              'conversationId': doc.id,
              'otherUserId': otherUserId,
              'otherUsername': userData['username'] ?? 'Unknown',
              'lastMessage': lastMessage,
              'lastMessageAt': data['lastMessageAt'],
              'unreadCount': (data['unreadCount']?[currentUserId] ?? 0) as int,
              'isArchived': isArchived,
              'isBlocked': isBlocked,
            });
          }
        }
      }
      
      return conversations;
    });
  }

  // Get messages for a specific conversation
  Stream<List<Map<String, dynamic>>> getMessagesStream(String conversationId) {
    
    
    // Initialize E2EE for this conversation
    _encryptionService.initializeConversationE2EE(conversationId);
    
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
      
      List<Map<String, dynamic>> messages = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        
        String decryptedText = data['text'];
        
        // Decrypt message if it's encrypted
        if (data['isEncrypted'] == true) {
          try {
            // Decrypt message from database
            decryptedText = await _encryptionService.decryptFromDatabase(data['text']);
            
          } catch (e) {
            
            decryptedText = '[Messaggio crittografato - errore di decrittografia: ${e.toString()}]';
          }
        } else {
          // Handle unencrypted messages (legacy)
          decryptedText = data['text'] ?? '';
          
        }
        
        messages.add({
          'id': doc.id,
          'senderId': data['senderId'],
          'text': decryptedText,
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
  Future<bool> sendMessage(String conversationId, String text) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        
        return false;
      }

      

      // Get the other user ID from conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      String? realConversationId = conversationId;
      String? otherUserId;
      Map<String, dynamic>? conversationData;

      if (!conversationDoc.exists) {
        
        // Create new conversation when first message is sent
        realConversationId = await _createNewConversation(conversationId); // conversationId is the otherUserId
        if (realConversationId == null) {
          
          return false;
        }
        // Get the newly created conversation
        final newDoc = await _firestore.collection('conversations').doc(realConversationId).get();
        if (!newDoc.exists) {
          
          return false;
        }
        conversationData = newDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(conversationData['participants']);
        otherUserId = participants.firstWhere((id) => id != currentUserId);
      } else {
        conversationData = conversationDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(conversationData['participants']);
        otherUserId = participants.firstWhere((id) => id != currentUserId);
      }

      
      

      // Sync encryption keys before sending message
      
      await _encryptionService.syncKeysForConversation(realConversationId!, otherUserId);

      // Always encrypt message for database storage
      
      final encryptedMessage = await _encryptionService.encryptForDatabase(text.trim());
      
      
      final messageData = {
        'senderId': currentUserId,
        'text': encryptedMessage, // Store encrypted message
        'isEncrypted': true, // Mark as encrypted
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      
      // Add message to conversation
      final messageDoc = await _firestore
          .collection('conversations')
          .doc(realConversationId)
          .collection('messages')
          .add(messageData);

      

      // Update conversation metadata with encrypted message
      
      await _firestore
          .collection('conversations')
          .doc(realConversationId)
          .update({
        'lastMessage': encryptedMessage, // Store encrypted message
        'isLastMessageEncrypted': true, // Mark as encrypted
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount.$otherUserId': FieldValue.increment(1),
      });

      

      // Send push notification to the other user via messages collection
      
      await _sendMessageNotification(otherUserId, text, realConversationId);

      
      return true;
    } catch (e) {
      
      
      return false;
    }
  }

  // Send push notification for new message
  Future<void> _sendMessageNotification(String receiverId, String messageText, String conversationId) async {
    try {
      // Get current user info
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();

      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        final currentUserName = currentUserData['name'] ?? currentUserData['username'] ?? 'Un amico';

        // La Cloud Function si attiva automaticamente quando viene creato un messaggio
        // nella subcollection messages della conversazione
        // Non serve inviare nulla di aggiuntivo, la Cloud Function intercetta il nuovo messaggio
        
      }
    } catch (e) {
      
    }
  }

  // Get existing conversation between two users (don't create if not exists)
  Future<String?> getExistingConversation(String otherUserId) async {
    if (currentUserId == null) {
      
      return null;
    }

    try {
      
      
      // Check if conversation already exists
      final existingConversation = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      

      for (var doc in existingConversation.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        
        
        if (participants.contains(otherUserId)) {
          
          
          // Sync encryption keys for existing conversation
          await _encryptionService.syncKeysForConversation(doc.id, otherUserId);
          
          return doc.id;
        }
      }

      
      return null;
    } catch (e) {
      
      
      return null;
    }
  }

  // Create new conversation when first message is sent
  Future<String?> _createNewConversation(String otherUserId) async {
    if (currentUserId == null) {
      
      return null;
    }

    try {
      
      
      // Verify both users exist
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      
      if (!currentUserDoc.exists) {
        
        return null;
      }
      
      if (!otherUserDoc.exists) {
        
        return null;
      }
      
      
      
      final conversationDoc = await _firestore.collection('conversations').add({
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        'isArchived': {currentUserId: false, otherUserId: false},
        'isBlocked': {currentUserId: false, otherUserId: false},
        'isDeleted': {currentUserId: false, otherUserId: false},
        'createdBy': currentUserId, // Track who created the conversation
      });

      

      // Initialize encryption for new conversation
      await _encryptionService.initializeConversationEncryption(conversationDoc.id, otherUserId);

      return conversationDoc.id;
    } catch (e) {
      
      
      return null;
    }
  }

  // Create or get conversation between two users
  Future<String?> getOrCreateConversation(String otherUserId) async {
    // First try to get existing conversation
    final existingConversationId = await getExistingConversation(otherUserId);
    if (existingConversationId != null) {
      return existingConversationId;
    }

    // If no conversation exists, create a temporary one for the sender only
    // The conversation will be properly created when the first message is sent
    
    return null;
  }

  // Notify other user about new conversation
  Future<void> _notifyNewConversation(String otherUserId, String conversationId) async {
    try {
      // Get current user info
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
        final currentUserName = currentUserData['name'] ?? currentUserData['username'] ?? 'Un amico';

        // Create a notification for the other user
        await _firestore.collection('notifications').add({
          'receiverId': otherUserId,
          'senderId': currentUserId,
          'type': 'new_conversation',
          'title': 'Nuova Chat',
          'body': '$currentUserName ha iniziato una conversazione con te',
          'data': {
            'conversationId': conversationId,
            'senderName': currentUserName,
          },
          'created_at': FieldValue.serverTimestamp(),
          'read': false,
        });

        
      }
    } catch (e) {
      
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    if (currentUserId == null) return;

    try {
      // Mark all unread messages as read
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isNotEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Reset unread count
      batch.update(
        _firestore.collection('conversations').doc(conversationId),
        {'unreadCount.$currentUserId': 0},
      );

      await batch.commit();
    } catch (e) {
      
    }
  }

  // Archive conversation for current user only
  Future<bool> archiveConversation(String conversationId) async {
    if (currentUserId == null) return false;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isArchived.$currentUserId': true,
      });
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Unarchive conversation
  Future<void> unarchiveConversation(String conversationId) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isArchived.$currentUserId': false,
      });
    } catch (e) {
      
    }
  }

  // Block user
  Future<void> blockUser(String conversationId, String otherUserId) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isBlocked.$currentUserId': true,
      });
    } catch (e) {
      
    }
  }

  // Unblock user
  Future<void> unblockUser(String conversationId, String otherUserId) async {
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isBlocked.$currentUserId': false,
      });
    } catch (e) {
      
    }
  }

  // Delete conversation locally for current user
  Future<bool> deleteConversationLocally(String conversationId) async {
    if (currentUserId == null) return false;

    try {
      // Mark conversation as deleted for current user
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'isDeleted.$currentUserId': true,
      });

      // Check if both users have deleted the conversation
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return false;

      final data = conversationDoc.data() as Map<String, dynamic>;
      final isDeleted = data['isDeleted'] as Map<String, dynamic>? ?? {};
      
      // Check if both users have deleted the conversation
      final participants = List<String>.from(data['participants']);
      bool bothDeleted = true;
      
      for (String participantId in participants) {
        if (!(isDeleted[participantId] ?? false)) {
          bothDeleted = false;
          break;
        }
      }

      if (bothDeleted) {
        // Both users deleted, clean up the database
        
        
        // Delete all messages in the conversation subcollection
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .get();

        for (var doc in messagesSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete all messages from the messages collection for this conversation
        final messagesCollectionSnapshot = await _firestore
            .collection('messages')
            .where('chatId', isEqualTo: conversationId)
            .get();

        for (var doc in messagesCollectionSnapshot.docs) {
          await doc.reference.delete();
        }

        // Delete the conversation document
        await conversationDoc.reference.delete();
        
        return true;
      } else {
        
        return true;
      }
    } catch (e) {
      
      return false;
    }
  }

  // Delete conversation completely (only if both users archived it) - DEPRECATED
  Future<bool> deleteConversation(String conversationId) async {
    return await deleteConversationLocally(conversationId);
  }

  // Get unread messages count
  Stream<int> getUnreadCountStream() {
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount']?[currentUserId] ?? 0) as int;
        final isArchived = data['isArchived']?[currentUserId] ?? false;
        if (!isArchived) {
          totalUnread += unreadCount;
        }
      }
      return totalUnread;
    });
  }

  // Initialize E2EE for user
  Future<bool> initializeE2EE() async {
    if (currentUserId == null) return false;

    try {
      // Generate key pair for current user
      final keyPair = await _encryptionService.generateKeyPair();
      
      // Store public key in Firestore for other users to access
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .update({
        'publicKey': keyPair['publicKey'],
        'keyFingerprint': _encryptionService.generateKeyFingerprint(keyPair['publicKey']!),
        'e2eeEnabled': true,
        'keyGeneratedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Get public key for a user
  Future<String?> getUserPublicKey(String userId) async {
    try {
      // First try to get from local storage
      String? publicKey = await _encryptionService.getPublicKey(userId);
      
      if (publicKey == null) {
        // If not found locally, get from Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          publicKey = userData['publicKey'];
          
          if (publicKey != null) {
            // Store locally for future use
            await _encryptionService.storePublicKey(userId, publicKey);
          }
        }
      }
      
      return publicKey;
    } catch (e) {
      
      return null;
    }
  }

  // Verify E2EE status for a conversation
  Future<bool> verifyE2EEStatus(String conversationId) async {
    try {
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (!conversationDoc.exists) return false;
      
      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(conversationData['participants']);
      
      // Check if all participants have E2EE enabled
      for (String participantId in participants) {
        final userDoc = await _firestore
            .collection('users')
            .doc(participantId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          if (userData['e2eeEnabled'] != true) {
            return false;
          }
        } else {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Force E2EE initialization for current user
  Future<bool> forceE2EEInitialization() async {
    try {
      return await _encryptionService.initializeE2EE();
    } catch (e) {
      
      return false;
    }
  }

  // Check if current user has E2EE enabled (always true now)
  Future<bool> isCurrentUserE2EEEnabled() async {
    try {
      if (currentUserId == null) return false;
      // E2EE is always enabled now
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Show in-app notification for new message
  void showMessageNotification(BuildContext context, String senderName, String messageText) {
    // RIMOSSO: showZapNotification, usa solo la toast custom se serve
  }

  // Listen for new messages and show notifications
  void startMessageNotifications(BuildContext context) {
    if (currentUserId == null) return;

    

    _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .listen((conversationsSnapshot) {
      for (var conversationDoc in conversationsSnapshot.docs) {
        final conversationData = conversationDoc.data();
        final lastMessageAt = conversationData['lastMessageAt'] as Timestamp?;
        
        if (lastMessageAt != null) {
          // Listen for new messages in this conversation
          _firestore
              .collection('conversations')
              .doc(conversationDoc.id)
              .collection('messages')
              .where('senderId', isNotEqualTo: currentUserId)
              .where('isRead', isEqualTo: false)
              .orderBy('createdAt', descending: true)
              .limit(1)
              .snapshots()
              .listen((messagesSnapshot) {
            if (messagesSnapshot.docs.isNotEmpty) {
              final messageData = messagesSnapshot.docs.first.data();
              final senderId = messageData['senderId'] as String;
              
              // Get sender info
              _firestore
                  .collection('users')
                  .doc(senderId)
                  .get()
                  .then((userDoc) {
                if (userDoc.exists) {
                  final userData = userDoc.data() as Map<String, dynamic>;
                  final senderName = userData['name'] ?? userData['username'] ?? 'Un amico';
                  
                  // Show notification
                  showMessageNotification(context, senderName, 'Nuovo messaggio');
                }
              });
            }
          });
        }
      }
    });
  }
}
