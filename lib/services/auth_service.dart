import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'online_status_service.dart';

abstract class AuthService {
  Future<bool> register(String email, String password, String username, String name);
  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
  User? getCurrentUser();
  Future<bool> forceRefreshSession();
  Stream<User?> authStateChanges();
}

class AuthServiceFirebaseImpl implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  AuthServiceFirebaseImpl() {
    // setPersistence() is only supported on web platforms
    // Firebase Auth on mobile automatically persists sessions
  }

  @override
  Future<bool> register(String email, String password, String username, String name) async {
    try {
      // Check if username already exists
      final usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw Exception('Username già in uso');
      }

      // Create user with Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return false;

      // Save user data to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'username': username,
        'name': name,
        'created_at': FieldValue.serverTimestamp(),
        'zapsSent': 0,
        'zapsReceived': 0,
        'profileImageUrl': null,
        'lastSeen': FieldValue.serverTimestamp(),
      });



      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Set user as online
        await OnlineStatusService().setOnline();

        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Set user as offline before logout
      await OnlineStatusService().setOffline();
      await _auth.signOut();

    } catch (e) {
      // Handle logout error silently
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Update last seen
      await _firestore.collection('users').doc(user.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return true;
    }
    return false;
  }

  @override
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  @override
  Future<bool> forceRefreshSession() async {
    try {
      // Wait for Firebase Auth to initialize
      await Future.delayed(Duration(milliseconds: 1500));
      
      final user = _auth.currentUser;
      if (user != null) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }


} 