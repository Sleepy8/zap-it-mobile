import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// Firebase implementation
class FirebaseAuthImpl {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  // SharedPreferences key for stay logged in
  static const String _stayLoggedInKey = 'stay_logged_in';
  static const String _lastLoginTimeKey = 'last_login_time';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Check if user should stay logged in
  Future<bool> shouldStayLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stayLoggedIn = prefs.getBool(_stayLoggedInKey) ?? false;
      
      if (stayLoggedIn) {
        final lastLoginTime = prefs.getInt(_lastLoginTimeKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        const maxSessionDuration = 30 * 24 * 60 * 60 * 1000; // 30 days in milliseconds
        
        // Check if session is still valid (within 30 days)
        if (now - lastLoginTime < maxSessionDuration) {
          
          return true;
        } else {
          
          await _clearStayLoggedIn();
          return false;
        }
      }
      
      return false;
    } catch (e) {
      
      return false;
    }
  }

  // Set stay logged in preference
  Future<void> setStayLoggedIn(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_stayLoggedInKey, value);
      
      if (value) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_lastLoginTimeKey, now);
        
      } else {
        await _clearStayLoggedIn();
        
      }
    } catch (e) {
      
    }
  }

  // Clear stay logged in preferences
  Future<void> _clearStayLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_stayLoggedInKey);
      await prefs.remove(_lastLoginTimeKey);
    } catch (e) {
      
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Initialize notification service after successful login
      if (result.user != null) {
        
        
        // Clean up old notifications first
        await _notificationService.cleanupAllOldNotifications();
        
        // Then initialize notification service
        await _notificationService.initialize();
      }
      
      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
    String name,
    String username,
    String email,
    String password,
  ) async {
    try {
      // Check if username already exists (case-insensitive) BEFORE creating Firebase account
      final usernameQuery = await _firestore
          .collection('users')
          .get();

      // Check case-insensitive manually
      bool usernameExists = false;
      for (var doc in usernameQuery.docs) {
        final data = doc.data();
        final existingUsername = data['username'] as String?;
        if (existingUsername != null) {
          if (existingUsername.toLowerCase().trim() == username.toLowerCase().trim()) {
            usernameExists = true;
            break;
          }
        }
      }
      
      if (usernameExists) {
        throw 'Username già in uso';
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'userId': result.user!.uid,
        'name': name,
        'email': email,
        'username': username,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Initialize notification service after successful registration
      if (result.user != null) {
        
        
        // Clean up old notifications first (in case there are any)
        await _notificationService.cleanupAllOldNotifications();
        
        // Then initialize notification service
        await _notificationService.initialize();
      }

      return result;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Stop notification service before logout
      _notificationService.stopListening();
      
      // Clear stay logged in preferences
      await _clearStayLoggedIn();
      
      await _auth.signOut();
      
    } catch (e) {
      
      throw e;
    }
  }

  // Check if username exists (case-insensitive)
  Future<bool> checkUsernameExists(String username) async {
    try {
      final usernameQuery = await _firestore
          .collection('users')
          .get();

      for (var doc in usernameQuery.docs) {
        final data = doc.data();
        final existingUsername = data['username'] as String?;
        if (existingUsername != null) {
          if (existingUsername.toLowerCase().trim() == username.toLowerCase().trim()) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Check if email exists (case-insensitive)
  Future<bool> checkEmailExists(String email) async {
    try {
      final emailQuery = await _firestore
          .collection('users')
          .get();

      for (var doc in emailQuery.docs) {
        final data = doc.data();
        final existingEmail = data['email'] as String?;
        if (existingEmail != null) {
          if (existingEmail.toLowerCase().trim() == email.toLowerCase().trim()) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw 'Errore nel recupero dei dati utente';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Nessun utente trovato con questa email';
      case 'wrong-password':
        return 'Password errata';
      case 'email-already-in-use':
        return 'Email già registrata';
      case 'weak-password':
        return 'La password deve essere di almeno 6 caratteri';
      case 'invalid-email':
        return 'Email non valida';
      case 'user-disabled':
        return 'Account disabilitato';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova più tardi';
      default:
        return 'Errore di autenticazione: ${e.message}';
    }
  }
}

// Global instance
final FirebaseAuthImpl firebaseAuthImpl = FirebaseAuthImpl(); 
