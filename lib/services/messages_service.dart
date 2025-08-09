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
    // Set current conversation ID for encryption
    _encryptionService.setCurrentConversationId(conversationId);
    
    // Check if conversation exists first
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .asyncMap((conversationDoc) async {
      if (!conversationDoc.exists) {
        // Return empty list if conversation doesn't exist
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
      // First try to find if this conversation exists
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
        'isEncrypted': true, // Enable encryption
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
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
        'isLastMessageEncrypted': true, // Enable encryption
        'unreadCount': unreadCount,
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

      // Get other user data
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (!otherUserDoc.exists) {
        return null;
      }

      final otherUserData = otherUserDoc.data() as Map<String, dynamic>;
      final otherUsername = otherUserData['username'] ?? 'Unknown';

      // Create conversation document
      final conversationData = {
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'isArchived': {currentUserId: false, otherUserId: false},
        'isBlocked': {currentUserId: false, otherUserId: false},
        'isDeleted': {currentUserId: false, otherUserId: false},
        'unreadCount': {currentUserId: 0, otherUserId: 0},
        // Note: sharedKey will be generated when first message is sent
      };

      final conversationRef = await _firestore.collection('conversations').add(conversationData);
      return conversationRef.id;
    } catch (e) {
      return null;
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

      // User blocked: $otherUserId
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

      // User unblocked: $otherUserId
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

      // Conversation deleted locally: $conversationId
      return true;
    } catch (e) {
      return false;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Get conversation data
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final conversationData = conversationDoc.data() as Map<String, dynamic>;
      final unreadCount = Map<String, int>.from(conversationData['unreadCount'] ?? {});
      
      // Reset unread count for current user
      unreadCount[currentUserId] = 0;

      // Update conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount': unreadCount,
      });

      // Messages marked as read for conversation: $conversationId
    } catch (e) {
      // Silent error handling
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

      // Conversation archived: $conversationId
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

      // Conversation unarchived: $conversationId
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

      // Conversation blocked: $conversationId
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

      // Conversation unblocked: $conversationId
    } catch (e) {
      // Silent error handling
    }
  }

  // Delete conversation locally
  Future<void> deleteConversation(String conversationId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      // Mark conversation as deleted for current user
      await _firestore.collection('conversations').doc(conversationId).update({
        'isDeleted.$currentUserId': true,
      });

      // Conversation deleted locally: $conversationId

      // Check if both users have deleted the conversation
      final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
      if (conversationDoc.exists) {
        final data = conversationDoc.data() as Map<String, dynamic>;
        final participants = List<String>.from(data['participants']);
        final isDeleted = data['isDeleted'] as Map<String, dynamic>? ?? {};
        
        // Check if all participants have deleted the conversation
        bool allDeleted = true;
        for (String participantId in participants) {
          if (isDeleted[participantId] != true) {
            allDeleted = false;
            break;
          }
        }
        
        // If all participants have deleted, remove the conversation from database
        if (allDeleted) {
          // All participants have deleted conversation, removing from database: $conversationId
          
          // Delete all messages in the conversation
          final messagesQuery = await _firestore
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .get();
          
          // Delete messages in batches
          final batch = _firestore.batch();
          for (var doc in messagesQuery.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          
          // Delete the conversation document
          await _firestore.collection('conversations').doc(conversationId).delete();
          
          // Conversation and all messages permanently deleted: $conversationId
        } else {
          // Conversation marked as deleted for current user, waiting for other participant: $conversationId
        }
      }
    } catch (e) {
      // Silent error handling
    }
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

      // Conversation restored: $conversationId
    } catch (e) {
      // Silent error handling
    }
  }
}
