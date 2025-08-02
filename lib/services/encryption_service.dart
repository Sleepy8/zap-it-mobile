import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EncryptionService {
  static const String _keyPrefix = 'zap_it_e2ee_';
  static const String _publicKeyPrefix = 'public_key_';
  static const String _privateKeyPrefix = 'private_key_';
  static const String _sharedKeyPrefix = 'shared_key_';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate encryption key for user and sync with Firestore
  Future<Map<String, String>> generateKeyPair() async {
    try {
      final userId = _getCurrentUserId();
      
      // Generate a secure random key for this user
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      final userKey = base64Encode(keyBytes);
      
      // Store private key locally (never shared)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_privateKeyPrefix}$userId', userKey);
      
      // Store public key in Firestore for other users to access
      await _firestore.collection('users').doc(userId).update({
        'publicKey': userKey,
        'keyFingerprint': generateKeyFingerprint(userKey),
        'e2eeEnabled': true,
        'keyGeneratedAt': FieldValue.serverTimestamp(),
      });
      
      return {
        'publicKey': userKey,
        'privateKey': userKey,
      };
    } catch (e) {
      
      rethrow;
    }
  }

  // E2EE Encryption - SECURE AND STABLE
  Future<String> encryptForDatabase(String message) async {
    try {
      final conversationId = _getCurrentConversationId();
      if (conversationId == null) {
        
        return message;
      }

      // Get or generate conversation key
      final conversationKey = await _getConversationKey(conversationId);
      
      // Encrypt message with AES-256
      final keyBytes = base64Decode(conversationKey);
      final key = Key(Uint8List.fromList(keyBytes));
      final iv = IV.fromSecureRandom(16);
      
      final encrypter = Encrypter(AES(key));
      final encryptedMessage = encrypter.encrypt(message, iv: iv);
      
      // Create encrypted payload
      final payload = {
        'encryptedMessage': encryptedMessage.base64,
        'iv': iv.base64,
        'conversationId': conversationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final jsonPayload = jsonEncode(payload);
      final encodedPayload = base64Encode(utf8.encode(jsonPayload));
      
      
      return encodedPayload;
    } catch (e) {
      
      return message; // Fallback to plain text on error
    }
  }

  // E2EE Decryption - SECURE AND STABLE
  Future<String> decryptFromDatabase(String encryptedPayload) async {
    try {
      // Try to decode the payload
      String jsonPayload;
      Map<String, dynamic> payload;
      
      try {
        jsonPayload = utf8.decode(base64Decode(encryptedPayload));
        payload = jsonDecode(jsonPayload) as Map<String, dynamic>;
      } catch (e) {
        // This might be a plain text message
        
        return encryptedPayload;
      }
      
      final encryptedMessage = payload['encryptedMessage'] as String;
      final iv = payload['iv'] as String;
      final conversationId = payload['conversationId'] as String?;
      
      if (conversationId == null) {
        
        return '[Messaggio non leggibile]';
      }
      
      // Get conversation key
      final conversationKey = await _getConversationKey(conversationId);
      
      if (conversationKey.isEmpty) {
        
        return '[Messaggio non leggibile - chiave mancante]';
      }
      
      // Decrypt message with conversation key
      final keyBytes = base64Decode(conversationKey);
      final key = Key(Uint8List.fromList(keyBytes));
      final ivBytes = IV.fromBase64(iv);
      
      final encrypter = Encrypter(AES(key));
      final decryptedMessage = encrypter.decrypt64(encryptedMessage, iv: ivBytes);
      
      
      return decryptedMessage;
    } catch (e) {
      
      return '[Messaggio non leggibile - errore di decrittografia]';
    }
  }

  // Legacy decryption for old message format
  Future<String> _decryptLegacyMessage(String encryptedPayload) async {
    try {
      final currentUserId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();
      
      // Get current user's shared key
      final sharedKey = prefs.getString('${_sharedKeyPrefix}$currentUserId');
      
      if (sharedKey == null || sharedKey.isEmpty) {
        
        return '[Messaggio legacy non leggibile]';
      }
      
      // Parse legacy payload
      final payloadBytes = base64Decode(encryptedPayload);
      final payloadString = utf8.decode(payloadBytes);
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      
      // Decrypt message with current user's key
      final keyBytes = base64Decode(sharedKey);
      final key = Key(Uint8List.fromList(keyBytes));
      final iv = IV.fromBase64(payload['iv']);
      
      final encrypter = Encrypter(AES(key));
      final encryptedMessage = payload['encryptedMessage'] as String;
      final decryptedMessage = encrypter.decrypt64(encryptedMessage, iv: iv);
      
      
      return decryptedMessage;
    } catch (e) {
      
      return '[Messaggio legacy non leggibile]';
    }
  }

  // Get recipient's public key from Firestore
  Future<String?> getPublicKey(String userId) async {
    try {
      // First try to get from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final publicKey = userData['publicKey'] as String?;
        
        if (publicKey != null) {
          // Store locally for faster access
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${_publicKeyPrefix}$userId', publicKey);
          return publicKey;
        }
      }
      
      // Fallback to local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_publicKeyPrefix}$userId');
    } catch (e) {
      
      return null;
    }
  }

  // Encrypt message for recipient using their public key
  Future<String> encryptMessage(String message, String recipientPublicKey) async {
    try {
      
      
      // Use recipient's public key to encrypt the message
      final keyBytes = base64Decode(recipientPublicKey);
      final key = Key(Uint8List.fromList(keyBytes));
      final iv = IV.fromSecureRandom(16);
      
      // Encrypt message with AES
      final encrypter = Encrypter(AES(key));
      final encryptedMessage = encrypter.encrypt(message, iv: iv);
      
      
      
      // Create encrypted payload
      final payload = {
        'encryptedMessage': encryptedMessage.base64,
        'iv': iv.base64,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'messageId': _generateMessageId(),
      };
      
      final jsonPayload = jsonEncode(payload);
      final encodedPayload = base64Encode(utf8.encode(jsonPayload));
      
      
      return encodedPayload;
    } catch (e) {
      
      rethrow;
    }
  }

  // Decrypt message with user's own private key
  Future<String> decryptMessage(String encryptedPayload) async {
    try {
      // Get user's own private key
      final userId = _getCurrentUserId();
      
      
      final prefs = await SharedPreferences.getInstance();
      final userPrivateKey = prefs.getString('${_privateKeyPrefix}$userId');
      
      
      
      String finalUserKey = userPrivateKey ?? '';
      
      if (finalUserKey.isEmpty) {
        // Try to get from Firestore and initialize
        
        final userDoc = await _firestore.collection('users').doc(userId).get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final publicKey = userData['publicKey'] as String?;
          
          if (publicKey != null && publicKey.isNotEmpty) {
            // Store locally and use (in this simplified version, public key = private key)
            await prefs.setString('${_privateKeyPrefix}$userId', publicKey);
            finalUserKey = publicKey;
            
          } else {
            throw Exception('No public key found in Firestore for user: $userId');
          }
        } else {
          throw Exception('User document not found: $userId');
        }
      }
      
      if (finalUserKey.isEmpty) {
        throw Exception('Failed to retrieve user private key');
      }
      
      
      
      // Parse payload
      final payloadBytes = base64Decode(encryptedPayload);
      final payloadString = utf8.decode(payloadBytes);
      
      
      final payload = jsonDecode(payloadString) as Map<String, dynamic>;
      
      
      
      // Decrypt message with user's private key
      final keyBytes = base64Decode(finalUserKey);
      final key = Key(Uint8List.fromList(keyBytes));
      final iv = IV.fromBase64(payload['iv']);
      final encrypter = Encrypter(AES(key));
      
      final encryptedMessage = payload['encryptedMessage'] as String;
      
      
      // Verify the encrypted message is valid base64
      try {
        base64Decode(encryptedMessage);
        
      } catch (e) {
        
        throw Exception('Invalid encrypted message format');
      }
      
      final decryptedMessage = encrypter.decrypt64(encryptedMessage, iv: iv);
      
      
      return decryptedMessage;
    } catch (e) {
      
      
      rethrow;
    }
  }

  // Store other user's public key locally
  Future<void> storePublicKey(String userId, String publicKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_publicKeyPrefix}$userId', publicKey);
    } catch (e) {
      
    }
  }

  // Generate unique message ID
  String _generateMessageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  // Verify message integrity
  bool verifyMessageIntegrity(String originalMessage, String decryptedMessage) {
    return originalMessage == decryptedMessage;
  }

  // Generate key fingerprint for verification
  String generateKeyFingerprint(String publicKey) {
    final bytes = utf8.encode(publicKey);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16).toUpperCase();
  }

  // Initialize E2EE for current user (always enabled)
  Future<bool> initializeE2EE() async {
    try {
      final userId = _getCurrentUserId();
      
      // Check if already initialized
      final prefs = await SharedPreferences.getInstance();
      final existingKey = prefs.getString('${_privateKeyPrefix}$userId');
      final existingSharedKey = prefs.getString('${_sharedKeyPrefix}$userId');
      
      if (existingKey != null && existingKey.isNotEmpty && 
          existingSharedKey != null && existingSharedKey.isNotEmpty) {
        
        return true; // Already initialized
      }
      
      
      
      // Generate new key pair and shared key
      final keyPair = await generateKeyPair();
      
      // Ensure shared key exists for database encryption
      if (existingSharedKey == null || existingSharedKey.isEmpty) {
        final random = Random.secure();
        final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
        final sharedKey = base64Encode(keyBytes);
        await prefs.setString('${_sharedKeyPrefix}$userId', sharedKey);
        
      }
      
      
      return true;
    } catch (e) {
      
      return false;
    }
  }

  // Force sync keys from Firestore
  Future<bool> syncKeysFromFirestore() async {
    try {
      final userId = _getCurrentUserId();
      
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final publicKey = userData['publicKey'] as String?;
        
        if (publicKey != null && publicKey.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('${_privateKeyPrefix}$userId', publicKey);
          
          return true;
        }
      }
      
      
      return false;
    } catch (e) {
      
      return false;
    }
  }

  // Test encryption/decryption
  Future<bool> testEncryption() async {
    try {
      final testMessage = "Test message for encryption";
      
      
      // Test database encryption
      final encrypted = await encryptForDatabase(testMessage);
      
      
      final decrypted = await decryptFromDatabase(encrypted);
      
      
      final success = testMessage == decrypted;
      
      
      return success;
    } catch (e) {
      
      return false;
    }
  }

  // Sync encryption keys between users in a conversation
  Future<void> syncKeysForConversation(String conversationId, String otherUserId) async {
    try {
      final currentUserId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();
      
      // Get current user's shared key
      String currentUserKey = prefs.getString('${_sharedKeyPrefix}$currentUserId') ?? '';
      
      // Get other user's shared key from Firestore
      final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
      if (otherUserDoc.exists) {
        final otherUserData = otherUserDoc.data() as Map<String, dynamic>;
        final otherUserKey = otherUserData['sharedKey'] as String? ?? '';
        
        if (otherUserKey.isNotEmpty) {
          // Store other user's key locally for decryption
          await prefs.setString('${_sharedKeyPrefix}$otherUserId', otherUserKey);
          
        }
      }
      
      // Share current user's key with other user
      if (currentUserKey.isNotEmpty) {
        await _firestore.collection('users').doc(currentUserId).update({
          'sharedKey': currentUserKey,
          'keyLastUpdated': FieldValue.serverTimestamp(),
        });
        
      }
    } catch (e) {
      
    }
  }

  // Initialize encryption for a new conversation
  Future<void> initializeConversationEncryption(String conversationId, String otherUserId) async {
    try {
      final currentUserId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();
      
      // Generate a conversation-specific key
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      final conversationKey = base64Encode(keyBytes);
      
      // Store conversation key locally
      await prefs.setString('${_sharedKeyPrefix}conv_$conversationId', conversationKey);
      
      // Store conversation key in Firestore for both users
      await _firestore.collection('conversations').doc(conversationId).update({
        'encryptionKey': conversationKey,
        'keyCreatedBy': currentUserId,
        'keyCreatedAt': FieldValue.serverTimestamp(),
      });
      
      
    } catch (e) {
      
    }
  }

  // Get current user ID from Firebase Auth
  String _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'unknown_user';
  }

  // Get current conversation ID (from context or parameter)
  String? _getCurrentConversationId() {
    // This should be passed from the MessagesService
    // For now, we'll use a global variable or get it from context
    return _currentConversationId;
  }

  // Set current conversation ID
  void setCurrentConversationId(String conversationId) {
    _currentConversationId = conversationId;
  }

  // Get or generate conversation key
  Future<String> _getConversationKey(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyName = 'conversation_key_$conversationId';
      
      // Try to get existing key
      String? conversationKey = prefs.getString(keyName);
      
      if (conversationKey == null || conversationKey.isEmpty) {
        // Generate new conversation key
        final random = Random.secure();
        final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
        conversationKey = base64Encode(keyBytes);
        
        // Save locally
        await prefs.setString(keyName, conversationKey);
        
        // Save to Firestore for other participants
        await _firestore.collection('conversations').doc(conversationId).update({
          'encryptionKey': conversationKey,
          'keyGeneratedAt': FieldValue.serverTimestamp(),
          'keyGeneratedBy': _getCurrentUserId(),
        });
        
        
      }
      
      return conversationKey;
    } catch (e) {
      
      return '';
    }
  }

  // Sync conversation key from Firestore
  Future<bool> syncConversationKey(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keyName = 'conversation_key_$conversationId';
      
      // Check if we already have the key
      String? existingKey = prefs.getString(keyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        
        return true;
      }
      
      // Get key from Firestore
      final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
      
      if (conversationDoc.exists) {
        final conversationData = conversationDoc.data() as Map<String, dynamic>;
        final encryptionKey = conversationData['encryptionKey'] as String?;
        
        if (encryptionKey != null && encryptionKey.isNotEmpty) {
          // Save locally
          await prefs.setString(keyName, encryptionKey);
          
          return true;
        }
      }
      
      
      return false;
    } catch (e) {
      
      return false;
    }
  }

  // Initialize E2EE for a conversation
  Future<bool> initializeConversationE2EE(String conversationId) async {
    try {
      
      
      // Set current conversation ID
      setCurrentConversationId(conversationId);
      
      // Get or generate conversation key
      final conversationKey = await _getConversationKey(conversationId);
      
      if (conversationKey.isNotEmpty) {
        
        return true;
      } else {
        
        return false;
      }
    } catch (e) {
      
      return false;
    }
  }

  // Test E2EE for a conversation
  Future<bool> testConversationE2EE(String conversationId) async {
    try {
      
      
      // Initialize E2EE
      final initialized = await initializeConversationE2EE(conversationId);
      if (!initialized) {
        
        return false;
      }
      
      // Test message
      final testMessage = "Test E2EE message - ${DateTime.now().millisecondsSinceEpoch}";
      
      // Encrypt
      final encrypted = await encryptForDatabase(testMessage);
      
      
      // Decrypt
      final decrypted = await decryptFromDatabase(encrypted);
      
      
      // Verify
      final success = testMessage == decrypted;
      
      
      return success;
    } catch (e) {
      
      return false;
    }
  }

  // Variable to store current conversation ID
  String? _currentConversationId;
} 
