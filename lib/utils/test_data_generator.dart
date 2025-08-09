import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TestDataGenerator {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const List<String> _italianNames = [
    'Marco', 'Giulia', 'Alessandro', 'Sofia', 'Luca', 'Chiara', 'Matteo', 'Valentina', 'Davide', 'Federica'
  ];
  
  static const List<String> _italianSurnames = [
    'Rossi', 'Ferrari', 'Russo', 'Bianchi', 'Romano', 'Colombo', 'Ricci', 'Marino', 'Greco', 'Bruno'
  ];

  static String _generateUsername(String name, String surname) {
    final baseUsername = '${name.toLowerCase()}_${surname.toLowerCase()}';
    final randomSuffix = (100 + DateTime.now().millisecondsSinceEpoch % 900).toString();
    return '$baseUsername$randomSuffix';
  }

  static String _generateEmail(String username) {
    return '$username@test.it';
  }

  static String _generatePassword() {
    return 'Test123!';
  }

  static Map<String, dynamic> _generateUserData(String name, String surname) {
    final username = _generateUsername(name, surname);
    final email = _generateEmail(username);
    
    return {
      'username': username,
      'name': '$name $surname',
      'email': email,
      'zapsSent': (10 + DateTime.now().millisecondsSinceEpoch % 50),
      'zapsReceived': (5 + DateTime.now().millisecondsSinceEpoch % 30),
      'profileImageUrl': 'https://picsum.photos/200/200?random=${DateTime.now().millisecondsSinceEpoch}',
      'created_at': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'isTestUser': true,
    };
  }

  static Future<bool> createTestUser(Map<String, dynamic> userData) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: userData['email'],
        password: _generatePassword(),
      );

      // Save user data to Firestore
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      print('✅ Utente creato: ${userData['username']} (${userData['email']})');
      return true;
    } catch (e) {
      print('❌ Errore nella creazione dell\'utente ${userData['username']}: $e');
      return false;
    }
  }

  static Future<void> createFriendship(String userId, String friendId) async {
    try {
      // Create friendship from user to friend
      await _firestore.collection('friendships').add({
        'userId': userId,
        'friendId': friendId,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Create reverse friendship from friend to user
      await _firestore.collection('friendships').add({
        'userId': friendId,
        'friendId': userId,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Amicizia creata tra $userId e $friendId');
    } catch (e) {
      print('❌ Errore nella creazione dell\'amicizia: $e');
    }
  }

  static Future<void> generateTestUsers({int count = 20}) async {
    print('🚀 Inizio generazione di $count utenti di test...');
    
    List<String> createdUserIds = [];
    int successCount = 0;
    int failureCount = 0;

    // Generate users
    for (int i = 0; i < count && i < _italianNames.length; i++) {
      final userData = _generateUserData(_italianNames[i], _italianSurnames[i]);
      final success = await createTestUser(userData);
      
      if (success) {
        // Get the user ID from the created user
        final userDoc = await _firestore
            .collection('users')
            .where('email', isEqualTo: userData['email'])
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          final userId = userDoc.docs.first.id;
          createdUserIds.add(userId);
          successCount++;
        }
      } else {
        failureCount++;
      }
    }

    // Create friendships between all users (everyone friends with everyone)
    if (createdUserIds.length > 1) {
      print('🔗 Creazione amicizie tra tutti gli utenti...');
      
      for (int i = 0; i < createdUserIds.length; i++) {
        for (int j = i + 1; j < createdUserIds.length; j++) {
          await createFriendship(createdUserIds[i], createdUserIds[j]);
        }
      }
      
      print('✅ Amicizie create tra tutti gli utenti');
    }

    print('📊 Riepilogo generazione utenti di test:');
    print('✅ Utenti creati con successo: $successCount');
    print('❌ Utenti falliti: $failureCount');
    print('📱 Ora puoi accedere con uno di questi account per vedere la home popolata!');
    
    if (successCount > 0) {
      print('🔑 Credenziali di accesso (primi 5 utenti):');
      for (int i = 0; i < 5 && i < successCount; i++) {
        final userData = _generateUserData(_italianNames[i], _italianSurnames[i]);
        print('   ${i + 1}. ${userData['email']} / ${_generatePassword()}');
      }
    }
  }

  static Future<void> cleanupTestUsers() async {
    try {
      print('🧹 Inizio pulizia utenti di test...');
      
      // Get all test users
      final testUsersQuery = await _firestore
          .collection('users')
          .where('isTestUser', isEqualTo: true)
          .get();

      int deletedCount = 0;
      
      for (var doc in testUsersQuery.docs) {
        final userData = doc.data();
        final email = userData['email'];
        
        try {
          // Delete from Firestore
          await doc.reference.delete();
          
          // Delete from Firebase Auth (if possible)
          try {
            final user = await _auth.fetchSignInMethodsForEmail(email);
            if (user.isNotEmpty) {
              // Note: We can't delete users from Auth without being signed in as them
              print('⚠️  Impossibile eliminare da Auth: $email (richiede login)');
            }
          } catch (e) {
            // Ignore Auth deletion errors
          }
          
          deletedCount++;
        } catch (e) {
          print('❌ Errore nell\'eliminazione di $email: $e');
        }
      }

      // Clean up friendships
      final friendshipsQuery = await _firestore
          .collection('friendships')
          .where('userId', whereIn: testUsersQuery.docs.map((doc) => doc.id).toList())
          .get();

      for (var doc in friendshipsQuery.docs) {
        await doc.reference.delete();
      }

      print('✅ Pulizia completata: $deletedCount utenti eliminati');
    } catch (e) {
      print('❌ Errore durante la pulizia: $e');
    }
  }
}
