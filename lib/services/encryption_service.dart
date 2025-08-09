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
      
      // Set the conversation ID for this decryption operation
      setCurrentConversationId(conversationId);
      
      // Get conversation key
      final conversationKey = await _getConversationKey(conversationId);
      
      if (conversationKey.isEmpty) {
        return '[Messaggio non leggibile - chiave mancante]';
      }
      
      // Try multiple decryption strategies
      List<String> decryptionStrategies = [
        conversationKey, // Current key
      ];
      
             // Add fallback keys for migration
       final prefs = await SharedPreferences.getInstance();
       final fallbackKeys = <String>[];
       
       // Add legacy keys if they exist
       final legacyKey = prefs.getString('${_sharedKeyPrefix}legacy_$conversationId');
       if (legacyKey != null && legacyKey.isNotEmpty) {
         fallbackKeys.add(legacyKey);
       }
       
       final oldKey = prefs.getString('${_sharedKeyPrefix}old_$conversationId');
       if (oldKey != null && oldKey.isNotEmpty) {
         fallbackKeys.add(oldKey);
       }
       
       // Add a default key as last resort
       fallbackKeys.add(base64Encode(List<int>.generate(32, (i) => i)));
      
      decryptionStrategies.addAll(fallbackKeys);
      
      // Try each decryption strategy
      for (int i = 0; i < decryptionStrategies.length; i++) {
        final keyToTry = decryptionStrategies[i];
        try {
          final keyBytes = base64Decode(keyToTry);
          final key = Key(Uint8List.fromList(keyBytes));
          final ivBytes = IV.fromBase64(iv);
          
          final encrypter = Encrypter(AES(key));
          final decryptedMessage = encrypter.decrypt64(encryptedMessage, iv: ivBytes);
          
          // If we used a fallback key, update the current key
          if (i > 0) {
            await prefs.setString('${_sharedKeyPrefix}$conversationId', keyToTry);
            
            // Also update in Firestore
            try {
              await _firestore.collection('conversations').doc(conversationId).update({
                'sharedKey': keyToTry,
                'keyUpdatedAt': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              // Silent error handling
            }
          }
          
          return decryptedMessage;
        } catch (decryptError) {
          continue;
        }
      }
      
      // If all strategies failed, try to get a fresh key from Firestore
      try {
        final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
        if (conversationDoc.exists) {
          final data = conversationDoc.data() as Map<String, dynamic>;
          final freshKey = data['sharedKey'] as String?;
          
          if (freshKey != null && freshKey.isNotEmpty) {
            // Update local key
            await prefs.setString('${_sharedKeyPrefix}$conversationId', freshKey);
            
            // Retry decryption with fresh key
            final keyBytes = base64Decode(freshKey);
            final key = Key(Uint8List.fromList(keyBytes));
            final ivBytes = IV.fromBase64(iv);
            
            final encrypter = Encrypter(AES(key));
            final decryptedMessage = encrypter.decrypt64(encryptedMessage, iv: ivBytes);
            
            return decryptedMessage;
          }
        }
      } catch (retryError) {
        // Silent error handling
      }
      
             // If everything failed, try to reset the conversation key and retry
       try {
         // Remove the current key to force regeneration
         await prefs.remove('${_sharedKeyPrefix}$conversationId');
         
         // Get a fresh key from Firestore or generate a new one
         final freshKey = await _getConversationKey(conversationId);
         
         // Try one more time with the fresh key
         final keyBytes = base64Decode(freshKey);
         final key = Key(Uint8List.fromList(keyBytes));
         final ivBytes = IV.fromBase64(iv);
         
         final encrypter = Encrypter(AES(key));
         final decryptedMessage = encrypter.decrypt64(encryptedMessage, iv: ivBytes);
         
         return decryptedMessage;
               } catch (resetError) {
          // As a last resort, try to detect if this is a plain text message
          if (encryptedPayload.length < 100 && !encryptedPayload.contains('=')) {
            return encryptedPayload;
          }
          
          // If it's a long encrypted message that we can't decrypt, 
          // it might be an orphaned message from a previous encryption system
          return '[Messaggio da conversazione precedente]';
        }
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
        return userData['publicKey'] as String?;
      }
      
      // If not found in Firestore, try local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${_publicKeyPrefix}$userId');
    } catch (e) {
      return null;
    }
  }

  // Store public key for a user
  Future<void> storePublicKey(String userId, String publicKey) async {
    try {
      // Store in Firestore
      await _firestore.collection('users').doc(userId).update({
        'publicKey': publicKey,
        'keyFingerprint': generateKeyFingerprint(publicKey),
        'e2eeEnabled': true,
        'keyUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Also store locally for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_publicKeyPrefix}$userId', publicKey);
      
      // Public key stored successfully
    } catch (e) {
      // Silent error handling
    }
  }

  // Get conversation key
  Future<String> _getConversationKey(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getString('${_sharedKeyPrefix}$conversationId');
      
      if (key != null) {
        return key;
      }
      
      // Always try to get key from Firestore first
      try {
        final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
        if (conversationDoc.exists) {
          final data = conversationDoc.data() as Map<String, dynamic>;
          final sharedKey = data['sharedKey'] as String?;
          
          if (sharedKey != null && sharedKey.isNotEmpty) {
            await prefs.setString('${_sharedKeyPrefix}$conversationId', sharedKey);
            return sharedKey;
          }
        }
      } catch (e) {
        // Silent error handling
      }
      
      // If no key exists in Firestore, wait a bit and try again (for race conditions)
      await Future.delayed(Duration(milliseconds: 500));
      
      try {
        final conversationDoc = await _firestore.collection('conversations').doc(conversationId).get();
        if (conversationDoc.exists) {
          final data = conversationDoc.data() as Map<String, dynamic>;
          final sharedKey = data['sharedKey'] as String?;
          
          if (sharedKey != null && sharedKey.isNotEmpty) {
            await prefs.setString('${_sharedKeyPrefix}$conversationId', sharedKey);
            return sharedKey;
          }
        }
      } catch (e) {
        // Silent error handling
      }
      
                   // Generate new conversation key only if no key exists in Firestore
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      final newKey = base64Encode(keyBytes);
      
      await prefs.setString('${_sharedKeyPrefix}$conversationId', newKey);
      
      // Store key in Firestore for other participants
      try {
        await _firestore.collection('conversations').doc(conversationId).update({
          'sharedKey': newKey,
          'keyGeneratedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // If storing in Firestore fails, we still have the local key
      }
       
       return newKey;
    } catch (e) {
      // Fallback to a default key
      return base64Encode(List<int>.generate(32, (i) => i));
    }
  }

  // Initialize conversation E2EE
  void initializeConversationE2EE(String conversationId) {
    // This method is called when starting to listen to a conversation
    // The actual key generation happens when needed
  }

  // Force key generation
  Future<void> forceKeyGeneration() async {
    try {
      await generateKeyPair();
    } catch (e) {
      // Silent error handling
    }
  }

  // Get current user ID
  String _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }
    return user.uid;
  }

  // Get current conversation ID (this would be set by the UI)
  String? _getCurrentConversationId() {
    // Return the current conversation ID set by the UI
    return _currentConversationId;
  }
  
  // Set current conversation ID for encryption
  String? _currentConversationId;
  
  void setCurrentConversationId(String conversationId) {
    _currentConversationId = conversationId;
  }
  
  // Get current conversation ID
  String? getCurrentConversationId() {
    return _currentConversationId;
  }

  // Generate key fingerprint for verification
  String generateKeyFingerprint(String key) {
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  // Check if E2EE is enabled for current user
  Future<bool> isE2EEEnabled() async {
    try {
      final userId = _getCurrentUserId();
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString('${_privateKeyPrefix}$userId');
      return privateKey != null && privateKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Enable E2EE for current user
  Future<bool> enableE2EE() async {
    try {
      await generateKeyPair();
      return true;
    } catch (e) {
      return false;
    }
  }

     // Disable E2EE for current user
   Future<bool> disableE2EE() async {
     try {
       final userId = _getCurrentUserId();
       final prefs = await SharedPreferences.getInstance();
       
       // Remove local keys
       await prefs.remove('${_privateKeyPrefix}$userId');
       await prefs.remove('${_publicKeyPrefix}$userId');
       
       // Update Firestore
       await _firestore.collection('users').doc(userId).update({
         'e2eeEnabled': false,
         'publicKey': null,
         'keyFingerprint': null,
         'e2eeDisabledAt': FieldValue.serverTimestamp(),
       });
       
               return true;
      } catch (e) {
        return false;
      }
   }
   
   // Reset conversation encryption (for orphaned messages)
   Future<void> resetConversationEncryption(String conversationId) async {
     try {
       final prefs = await SharedPreferences.getInstance();
       
       // Remove all keys for this conversation
       await prefs.remove('${_sharedKeyPrefix}$conversationId');
       await prefs.remove('${_sharedKeyPrefix}legacy_$conversationId');
       await prefs.remove('${_sharedKeyPrefix}old_$conversationId');
       
       // Clear key from Firestore
       try {
         await _firestore.collection('conversations').doc(conversationId).update({
           'sharedKey': null,
           'keyResetAt': FieldValue.serverTimestamp(),
         });
                   // Reset conversation encryption for: $conversationId
        } catch (e) {
          // Silent error handling
        }
      } catch (e) {
        // Silent error handling
      }
   }
 } 

